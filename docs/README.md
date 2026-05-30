# Shared Postgres

PostgreSQL 17 instance shared by custom homelab apps (kids tasks, email matrix, future apps). Vanilla Postgres — not the same as Immich's specialized `immich-postgres` (which has pgvector extensions).

## Access

| Where | URL |
|---|---|
| **From an app pod (cluster DNS)** | `shared-postgres.homelab.svc.cluster.local:5432` |
| **From this Mac (psql / GUI tool via port-forward)** | `kubectl port-forward svc/shared-postgres 5432:5432 -n homelab` → `localhost:5432` |
| **From any tailnet device** | not exposed (databases shouldn't be public — apps mediate access) |

## Databases on this instance

| Database | User | App |
|---|---|---|
| `kidstasks` | `kidstasks` | [Chores](../chores/) |
| `emailmatrix` | `emailmatrix` | [Email Matrix](../emailmatrix/) |

## Detailed docs

- [📋 USAGE](USAGE.md) — wiring apps, running queries, adding new DBs, GUI tool setup
- [🛠 MAINTENANCE](MAINTENANCE.md) — credentials, backup/restore, upgrade, troubleshooting
- [🏛 ARCHITECTURE](ARCHITECTURE.md) — design decisions, why separate from immich-postgres, data layout

## Quick start: a new app needs a DB

```bash
NEW_APP=mytool
NEW_PWD="strong-pwd"

kubectl exec -n homelab shared-postgres-0 -- psql -U postgres -c "
  CREATE USER $NEW_APP WITH PASSWORD '$NEW_PWD';
  CREATE DATABASE $NEW_APP OWNER $NEW_APP;
"
```

See [USAGE](USAGE.md#add-a-new-database-for-a-new-app) for the full version (with secret update).
