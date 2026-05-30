# Shared Postgres — Maintenance

## Credentials

All in Secret `shared-postgres-secret` (namespace `homelab`).

| Key | Initial value | Purpose |
|---|---|---|
| `POSTGRES_USER` | `postgres` | Superuser |
| `POSTGRES_PASSWORD` | `changeMe-shared-pg-pwd` ⚠️ | Superuser password |
| `KIDSTASKS_USER` | `kidstasks` | Kids task app DB user |
| `KIDSTASKS_PASSWORD` | `changeMe-kidstasks-pwd` ⚠️ | Kids task app DB password |
| `EMAILMATRIX_USER` | `emailmatrix` | Email matrix DB user |
| `EMAILMATRIX_PASSWORD` | `emailmatrix-changeMe` ⚠️ | Email matrix DB password |

### Reveal live values
```bash
kubectl get secret shared-postgres-secret -n homelab -o json \
  | python3 -c "import sys,json,base64; d=json.load(sys.stdin); [print(f'{k}={base64.b64decode(v).decode()}') for k,v in d['data'].items()]"
```

### Change a password
```bash
NEW_PWD="strong-new-password"
kubectl patch secret shared-postgres-secret -n homelab --type=json -p="[
  {\"op\":\"replace\",\"path\":\"/data/EMAILMATRIX_PASSWORD\",\"value\":\"$(echo -n "$NEW_PWD" | base64)\"}
]"

# Also update in Postgres
kubectl exec -n homelab shared-postgres-0 -- psql -U postgres -c \
  "ALTER USER emailmatrix WITH PASSWORD '$NEW_PWD';"

# Restart app pods that use the secret as env
kubectl rollout restart deployment/emailmatrix -n homelab
```

## Common operations

### Restart Postgres
```bash
kubectl rollout restart statefulset/shared-postgres -n homelab
```
~10 seconds downtime. App pods auto-reconnect.

### Logs
```bash
kubectl logs -n homelab shared-postgres-0 --tail=50
```

### Pod status
```bash
kubectl get pod shared-postgres-0 -n homelab
```

### Storage usage
```bash
kubectl exec -n homelab shared-postgres-0 -- df -h /var/lib/postgresql/data
```

## Backup

Manual full backup:
```bash
BACKUP="/Volumes/Seeni's HDD/shared-postgres-$(date +%Y%m%d-%H%M%S).sql.gz"
kubectl exec -n homelab shared-postgres-0 -- pg_dumpall -U postgres | gzip > "$BACKUP"
ls -lh "$BACKUP"
```

Per-database backup:
```bash
BACKUP="/Volumes/Seeni's HDD/emailmatrix-$(date +%Y%m%d-%H%M%S).sql.gz"
kubectl exec -n homelab shared-postgres-0 -- pg_dump -U emailmatrix -d emailmatrix | gzip > "$BACKUP"
```

TODO: integrate into `~/homelab/backup-immich.sh`.

## Restore

```bash
# Restore everything (after a disaster):
gunzip -c shared-postgres-YYYYMMDD-HHMMSS.sql.gz \
  | kubectl exec -i -n homelab shared-postgres-0 -- psql -U postgres

# Or just one DB:
gunzip -c emailmatrix-YYYYMMDD-HHMMSS.sql.gz \
  | kubectl exec -i -n homelab shared-postgres-0 -- psql -U emailmatrix -d emailmatrix
```

## Upgrade Postgres major version

⚠️ Postgres major upgrades require `pg_upgrade` or dump+restore. Don't just bump the image tag.

Procedure:
1. Backup (pg_dumpall above)
2. Scale all app pods to 0
3. Delete the StatefulSet (`kubectl delete sts shared-postgres -n homelab`)
4. Delete the PVC (`kubectl delete pvc shared-postgres-pvc -n homelab`) — DESTROYS DATA, only do this after confirmed backup
5. Update `~/homelab/shared-postgres.yaml` with new image tag
6. Apply
7. Restore from dump
8. Scale apps back up

This is the same pattern as [Immich UPGRADE](../immich/UPGRADE.md) for the Postgres side.

## Troubleshooting

### App can't connect
```bash
# Confirm DB + user exist
kubectl exec -n homelab shared-postgres-0 -- psql -U postgres -c '\du'
kubectl exec -n homelab shared-postgres-0 -- psql -U postgres -c '\l'

# Confirm secret values match what the app expects
kubectl get secret shared-postgres-secret -n homelab -o yaml
```

### Postgres pod won't start
```bash
kubectl logs -n homelab shared-postgres-0 --tail=30
```

Common causes:
- PVC not bound → check `kubectl get pvc -n homelab`
- Disk full → check `df -h` on the underlying VM (OrbStack's storage)
- Corrupt data dir (rare) → restore from backup

### Pod restarts
The Postgres pod is configured to restart cleanly. If it's CrashLoopBackOff, check logs and consider restoring from backup.

### DNS resolution from app fails
```bash
# From inside an app pod
nslookup shared-postgres.homelab.svc.cluster.local
```
If this fails, the cluster DNS (coredns) is broken — separate issue from Postgres itself.
