# shared-postgres

Shared PostgreSQL StatefulSet for homelab k3s — used by chores, reminders, and emailmatrix.

Each app gets its own database and user inside a single Postgres instance. No cross-app data leakage.

NOT the same as Immich's `immich-postgres`, which uses pgvector/vectorchord for AI vector search. This is vanilla Postgres.

## Depends on

- **cluster-setup** — `homelab` namespace, Tailscale ingress controller, `local-path` StorageClass: [`github.com/seenimurugan/homelab-cluster-setup`](https://github.com/seenimurugan/homelab-cluster-setup)

## Quick start

```bash
git clone https://github.com/seenimurugan/shared-postgres
cd shared-postgres

# 1. Set up your env
cp .env.example .env
$EDITOR .env   # fill in all *_PASSWORD values

# 2. Deploy
./deploy.sh
```

`deploy.sh` is idempotent — safe to re-run. It creates/updates the secret, applies manifests via `envsubst`, and waits for the StatefulSet rollout.

## Access

| Where | Address |
|---|---|
| **From an app pod (cluster DNS)** | `shared-postgres.homelab.svc.cluster.local:5432` |
| **From this Mac (port-forward)** | `kubectl port-forward svc/shared-postgres 5432:5432 -n homelab` → `localhost:5432` |
| **From Tailnet** | Not exposed — apps mediate all DB access |

## Databases

| Database | User | App |
|---|---|---|
| `kidstasks` | `kidstasks` | [chores](https://github.com/seenimurugan/chores) |
| `emailmatrix` | `emailmatrix` | emailmatrix |
| `reminders` | `reminders` | [reminders](https://github.com/seenimurugan/reminders) |

## Tear down

```bash
./undeploy.sh   # removes StatefulSet + Service; preserves PVC and secret
```

The PVC (data) is intentionally preserved. See the printed instructions in `undeploy.sh` for the full wipe command.

## Docs

- [docs/README.md](docs/README.md) — overview, access URLs, databases on this instance
- [docs/USAGE.md](docs/USAGE.md) — wiring apps, running queries, adding new DBs, GUI tool setup
- [docs/MAINTENANCE.md](docs/MAINTENANCE.md) — credentials, backup/restore, upgrade, troubleshooting
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — design decisions, data layout, why separate from immich-postgres

Also rendered live at https://docs.stoat-perch.ts.net (sidebar → Homelab K8s Setup → Apps → Shared Postgres).
