#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

: "${PGHOST:?Falta PGHOST}"
: "${PGUSER:?Falta PGUSER}"
: "${PGPASSWORD:?Falta PGPASSWORD}"
: "${DB_INCLUDE_REGEX:?Falta DB_INCLUDE_REGEX}"
: "${AGE_RECIPIENT:?Falta AGE_RECIPIENT}"
: "${RCLONE_REMOTE:?Falta RCLONE_REMOTE}"

export RCLONE_CONFIG=/config/rclone.conf

DATE="$(date +%F)"
YEAR="$(date +%Y)"
MONTH="$(date +%m)"

BACKUP_DIR="/data/backups/$DATE"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

exec 9>/data/backup.lock
flock -n 9 || {
    echo "Ya existe un backup en ejecución."
    exit 0
}

echo "Iniciando backup: $DATE"

mapfile -t DATABASES < <(
    psql -X -h "$PGHOST" -p "${PGPORT:-5432}" \
      -U "$PGUSER" -d postgres -At \
      -v ON_ERROR_STOP=1 \
      -v regex="$DB_INCLUDE_REGEX" \
      -c "SELECT datname FROM pg_database
          WHERE datistemplate = false
          AND datallowconn = true
          AND datname <> 'postgres'
          AND datname ~ :'regex'
          ORDER BY datname;"
)

if ((${#DATABASES[@]} == 0)); then
    echo "ERROR: No se encontraron bases de clientes."
    exit 1
fi

printf "Fecha: %s\nCantidad de bases: %s\n" \
    "$DATE" "${#DATABASES[@]}" > "$BACKUP_DIR/manifest.txt"

for DB in "${DATABASES[@]}"; do

    [[ "$DB" =~ ^[A-Za-z0-9_]+$ ]] || {
        echo "Nombre de base no permitido: $DB"
        exit 1
    }

    echo "Respaldando: $DB"

    OUTPUT="$BACKUP_DIR/${DB}.dump.age"
    TEMP="${OUTPUT}.partial"

    pg_dump \
      -h "$PGHOST" \
      -p "${PGPORT:-5432}" \
      -U "$PGUSER" \
      -d "$DB" \
      -Fc \
      --no-owner \
      --no-acl \
      | age -r "$AGE_RECIPIENT" -o "$TEMP"

    [[ -s "$TEMP" ]] || {
        echo "ERROR: backup vacío de $DB"
        exit 1
    }

    mv "$TEMP" "$OUTPUT"

    sha256sum "$OUTPUT" >> "$BACKUP_DIR/SHA256SUMS"

    echo "Correcto: $DB"
done

REMOTE="${RCLONE_REMOTE%/}/${REMOTE_BASE}/Daily/${YEAR}/${MONTH}/${DATE}"

rclone copy "$BACKUP_DIR" "$REMOTE" \
    --checksum --transfers 4 --checkers 8

# Copia mensual independiente el primer día del mes.
if [[ "$(date +%d)" == "01" ]]; then
    rclone copy "$BACKUP_DIR" \
      "${RCLONE_REMOTE%/}/${REMOTE_BASE}/Monthly/${YEAR}-${MONTH}" \
      --checksum
fi

# Limpieza local.
find /data/backups -mindepth 1 -maxdepth 1 \
    -type d -name '20??-??-??' \
    -mtime "+${LOCAL_RETENTION_DAYS:-7}" \
    -exec rm -rf -- {} +

# Retención remota.
rclone delete \
  "${RCLONE_REMOTE%/}/${REMOTE_BASE}/Daily" \
  --min-age "${DAILY_RETENTION_DAYS:-35}d"

rclone rmdirs \
  "${RCLONE_REMOTE%/}/${REMOTE_BASE}/Daily" \
  --leave-root

rclone delete \
  "${RCLONE_REMOTE%/}/${REMOTE_BASE}/Monthly" \
  --min-age "${MONTHLY_RETENTION_DAYS:-365}d"

rclone rmdirs \
  "${RCLONE_REMOTE%/}/${REMOTE_BASE}/Monthly" \
  --leave-root

echo "Backup finalizado correctamente: $DATE"
