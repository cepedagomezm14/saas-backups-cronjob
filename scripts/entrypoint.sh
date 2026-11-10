#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p /data/logs
chmod 700 /data/logs

# Exportar las variables del contenedor al entorno de Cron.
# %q escapa correctamente contraseñas y caracteres especiales.
ENV_FILE=/run/backup-env.sh
: > "$ENV_FILE"
chmod 600 "$ENV_FILE"

VARS=(
  TZ PGHOST PGPORT PGUSER PGPASSWORD
  DB_INCLUDE_REGEX AGE_RECIPIENT
  RCLONE_REMOTE REMOTE_BASE
  LOCAL_RETENTION_DAYS DAILY_RETENTION_DAYS
  MONTHLY_RETENTION_DAYS
)

for var in "${VARS[@]}"; do
    if [[ -v "$var" ]]; then
        printf 'export %s=%q\n' "$var" "${!var}" >> "$ENV_FILE"
    fi
done

echo "SaaS Backup Service iniciado"
echo "Programación: todos los días a las 03:00"
echo "PostgreSQL: $PGHOST:$PGPORT"

exec cron -f
