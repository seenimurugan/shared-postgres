#!/usr/bin/env bash
# undeploy.sh — tear down shared-postgres StatefulSet + Service
#
# DATA IS PRESERVED: the PVC (shared-postgres-pvc) is NOT deleted.
# The secret (shared-postgres-secret) is NOT deleted — chores/reminders/emailmatrix
# pods will keep referencing it until their own deploy.sh recreates it.
#
# To fully wipe all data, see instructions printed at the end.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Load .env for HOMELAB_NAMESPACE ──────────────────────────────────────────
ENV_FILE="$SCRIPT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
fi
HOMELAB_NAMESPACE="${HOMELAB_NAMESPACE:-homelab}"

echo "Undeploying shared-postgres from namespace '$HOMELAB_NAMESPACE'..."
echo ""
echo "  PVC (data) is NOT deleted."
echo "  Secret (shared-postgres-secret) is NOT deleted."
echo ""

# ── StatefulSet ───────────────────────────────────────────────────────────────
kubectl -n "$HOMELAB_NAMESPACE" delete statefulset shared-postgres --ignore-not-found

# ── Service ───────────────────────────────────────────────────────────────────
kubectl -n "$HOMELAB_NAMESPACE" delete service shared-postgres --ignore-not-found

# ── ConfigMap ─────────────────────────────────────────────────────────────────
kubectl -n "$HOMELAB_NAMESPACE" delete configmap shared-postgres-init --ignore-not-found

echo ""
echo "Shared-postgres torn down."
echo ""
echo "  Kept (data):"
echo "    - PVC:    shared-postgres-pvc  (all database files intact)"
echo "    - Secret: shared-postgres-secret  (app credentials intact)"
echo ""
echo "  ─────────────────────────────────────────────────────────────────"
echo "  WARNING: To truly wipe ALL data (irreversible):"
echo ""
echo "    kubectl -n $HOMELAB_NAMESPACE delete pvc shared-postgres-pvc"
echo "    kubectl -n $HOMELAB_NAMESPACE delete secret shared-postgres-secret"
echo ""
echo "  This will destroy all databases (chores, reminders, emailmatrix)."
echo "  Back up first:  see docs/MAINTENANCE.md#backup"
echo "  ─────────────────────────────────────────────────────────────────"
echo ""
echo "  To redeploy:  ./deploy.sh"
