# Shared Postgres — Usage

How to use the shared Postgres from app pods and the Mac.

**On this page:** [Wire an app pod to this Postgres](#wire-an-app-pod-to-this-postgres) · [Access from the Mac](#access-from-the-mac) · [Add a new database for a new app](#add-a-new-database-for-a-new-app) · [Disk usage per DB](#disk-usage-per-db) · [Common SQL recipes](#common-sql-recipes)

## Wire an app pod to this Postgres

In your app's Deployment YAML:

```yaml
env:
  - name: DB_HOST
    value: "shared-postgres.homelab.svc.cluster.local"
  - name: DB_PORT
    value: "5432"
  - name: DB_NAME
    valueFrom:
      secretKeyRef: { name: shared-postgres-secret, key: KIDSTASKS_DB }
  - name: DB_USER
    valueFrom:
      secretKeyRef: { name: shared-postgres-secret, key: KIDSTASKS_USER }
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef: { name: shared-postgres-secret, key: KIDSTASKS_PASSWORD }
```

Spring Boot `application.properties`:
```
spring.datasource.url=jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}
spring.datasource.username=${DB_USER}
spring.datasource.password=${DB_PASSWORD}
```

## Access from the Mac

### Run a query
```bash
kubectl exec -n homelab shared-postgres-0 -- psql -U postgres -c '\l'
```

### Interactive shell
```bash
kubectl exec -it -n homelab shared-postgres-0 -- psql -U postgres
```

### From a GUI tool (TablePlus, DBeaver, pgAdmin)
Open a port-forward:
```bash
kubectl port-forward svc/shared-postgres 5432:5432 -n homelab
# Connect to localhost:5432, user postgres, password (see MAINTENANCE.md)
```

## Add a new database for a new app

```bash
NEW_APP=mytool
NEW_PWD="strong-pwd"

# Create user + DB
kubectl exec -n homelab shared-postgres-0 -- psql -U postgres -c "
  CREATE USER $NEW_APP WITH PASSWORD '$NEW_PWD';
  CREATE DATABASE $NEW_APP OWNER $NEW_APP;
  GRANT ALL PRIVILEGES ON DATABASE $NEW_APP TO $NEW_APP;
"

# Store creds in the existing secret for future apps to reference
kubectl patch secret shared-postgres-secret -n homelab --type=json -p="[
  {\"op\":\"add\",\"path\":\"/data/${NEW_APP^^}_DB\",\"value\":\"$(echo -n "$NEW_APP" | base64)\"},
  {\"op\":\"add\",\"path\":\"/data/${NEW_APP^^}_USER\",\"value\":\"$(echo -n "$NEW_APP" | base64)\"},
  {\"op\":\"add\",\"path\":\"/data/${NEW_APP^^}_PASSWORD\",\"value\":\"$(echo -n "$NEW_PWD" | base64)\"}
]"
```

Then update [MAINTENANCE.md](MAINTENANCE.md#credentials) credentials table with the new app's entries.

## Disk usage per DB

```bash
kubectl exec -n homelab shared-postgres-0 -- psql -U postgres -c "
  SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
  FROM pg_database ORDER BY pg_database_size(datname) DESC;
"
```

## Common SQL recipes

```bash
# List users
kubectl exec -n homelab shared-postgres-0 -- psql -U postgres -c '\du'

# List databases
kubectl exec -n homelab shared-postgres-0 -- psql -U postgres -c '\l'

# Drop a database (destructive!)
kubectl exec -n homelab shared-postgres-0 -- psql -U postgres -c "DROP DATABASE $name;"

# Connect as a specific app user
kubectl exec -it -n homelab shared-postgres-0 -- psql -U emailmatrix -d emailmatrix
```
