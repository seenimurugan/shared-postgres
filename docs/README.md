# Shared Postgres

PostgreSQL 17 StatefulSet shared by the homelab's custom apps (chores, email matrix, storage-console, moviesda, and any future apps). Each app gets its own database and user inside this single instance. Not the same as Immich's `immich-postgres`, which has pgvector/vectorchord extensions and is intentionally separate.

Source: `/Users/nila/Developer/apps/shared-postgres/`

---

## Access

| Where | URL |
|---|---|
| **From an app pod (cluster DNS)** | `shared-postgres.homelab.svc.cluster.local:5432` |
| **This Mac (psql / GUI tool via port-forward)** | `kubectl -n homelab port-forward svc/shared-postgres 5432:5432` → `localhost:5432` |
| **From any tailnet device** | not exposed — databases shouldn't be publicly reachable; apps mediate all access |

---

## What it does

- Hosts one independent database per app — schema isolation means chores cannot read emailmatrix data.
- New app DB created with a single `psql` command; wired to the app via Secret keys.
- Single `pg_dumpall` in a CronJob covers all app databases in one backup.

---

## Databases on this instance

| Database | User | App |
|---|---|---|
| `kidstasks` | `kidstasks` | [Chores](../chores/README.md) |
| `emailmatrix` | `emailmatrix` | [Email Matrix](../emailmatrix/README.md) |
| `storage_console` | `storage_console` | [Storage Console](../storage-console/README.md) |
| `moviesda` | `moviesda` | [Moviesda](../moviesda/README.md) |
| `reminders` | `reminders` | [Reminders](../reminders/README.md) |

---

## Stack & framework

| Layer | Tech |
|---|---|
| Database | PostgreSQL 17 (Alpine variant) |
| Resource | k8s StatefulSet (1 replica, RWO PVC) |
| Storage | PVC on `local-path` (VM ext4) — 20 Gi |
| Service | Headless ClusterIP (`shared-postgres.homelab.svc.cluster.local:5432`) |
| Auth | Per-DB user + password, stored in `shared-postgres-secret` |

---

## Storage

Single PVC `shared-postgres-pvc` on `local-path` (VM ext4, 20 Gi). Lives inside the OrbStack VM — persists across pod/Mac reboots but is lost on `orbctl reset`. Back up regularly via `pg_dumpall`.

---

## See also

- [Usage guide](USAGE.md) — wiring a new app, running queries, adding new DBs, GUI tool setup
- [Maintenance](MAINTENANCE.md) — credentials, backup/restore, upgrade, troubleshooting
- [Architecture](ARCHITECTURE.md) — design decisions, why separate from immich-postgres, data layout

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

## File reference

| File | Purpose |
|---|---|
| `/Users/nila/Developer/apps/shared-postgres/k8s/shared-postgres.yaml` | StatefulSet + Service + Secret + PVC + Init ConfigMap |
