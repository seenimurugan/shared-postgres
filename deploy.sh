#!/usr/bin/env bash
# deploy.sh — idempotent deploy for shared-postgres
# Usage: ./deploy.sh
# Safe to re-run; existing resources are patched, not replaced.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. Load .env ─────────────────────────────────────────────────────────────
ENV_FILE="$SCRIPT_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env not found."
  echo "       Copy .env.example to .env and fill in real values, then re-run."
  echo "         cp .env.example .env && \$EDITOR .env"
  exit 1
fi
# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

# ── 2. Prereq checks ─────────────────────────────────────────────────────────
if ! command -v kubectl &>/dev/null; then
  echo "ERROR: kubectl not found in PATH."
  exit 1
fi
if ! command -v envsubst &>/dev/null; then
  echo "ERROR: envsubst not found. Install via: brew install gettext"
  exit 1
fi
if ! kubectl cluster-info &>/dev/null; then
  echo "ERROR: Cannot reach the Kubernetes cluster. Is OrbStack running?"
  exit 1
fi

# ── 3. Ensure namespace exists ───────────────────────────────────────────────
HOMELAB_NAMESPACE="${HOMELAB_NAMESPACE:-homelab}"
if ! kubectl get namespace "$HOMELAB_NAMESPACE" &>/dev/null; then
  echo "Namespace '$HOMELAB_NAMESPACE' not found — creating it."
  kubectl create namespace "$HOMELAB_NAMESPACE"
else
  echo "Namespace '$HOMELAB_NAMESPACE' already exists."
fi

# ── 4. Create / update shared-postgres-secret ────────────────────────────────
# Owns ONLY the postgres master credentials (POSTGRES_DB / _USER / _PASSWORD)
# consumed by the shared-postgres StatefulSet itself. Per 2026-06-01 split,
# every app now owns its own <app>-postgres-secret and provisions it from its
# own deploy.sh — this script no longer writes app-specific keys.
# Passwords come from .env — never stored in the YAML.
echo "Ensuring shared-postgres-secret (master creds only)..."
kubectl -n "$HOMELAB_NAMESPACE" create secret generic shared-postgres-secret \
  --from-literal=POSTGRES_DB=postgres \
  --from-literal=POSTGRES_USER=postgres \
  --from-literal=POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

# ── 5. Apply manifests via envsubst ──────────────────────────────────────────
K8S_DIR="$SCRIPT_DIR/k8s"
echo "Applying k8s manifests (envsubst → kubectl apply)..."
envsubst < "$K8S_DIR/shared-postgres.yaml" | kubectl apply -f -

# ── 6. Wait for rollout ───────────────────────────────────────────────────────
echo "Waiting for shared-postgres StatefulSet rollout..."
kubectl -n "$HOMELAB_NAMESPACE" rollout status statefulset/shared-postgres --timeout=5m

# ── 7. Done ───────────────────────────────────────────────────────────────────
echo ""
echo "Postgres ready."
echo "Each app (chores/reminders/emailmatrix) creates its own DB + user via its own deploy.sh."
echo ""
echo "  Port-forward to psql from this Mac:"
echo "    kubectl port-forward svc/shared-postgres 5432:5432 -n $HOMELAB_NAMESPACE"
echo ""
echo "  Cluster DNS (from app pods):"
echo "    shared-postgres.${HOMELAB_NAMESPACE}.svc.cluster.local:5432"
