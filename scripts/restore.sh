#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

: "${PGHOST:?Falta PGHOST}"
: "${PGUSER:?Falta PGUSER}"
: "${PGPASSWORD:?Falta PGPASSWORD}"
: "${AGE_IDENTITY_FILE:?Indica la ruta de la clave privada age}"

if [[ $# -ne 2 ]]; then
    echo "Uso: restore.sh archivo.dump.age nueva_base"
    exit 1
fi

BACKUP="$1"
TARGET_DB="$2"

[[ -f "$BACKUP" ]] || {
    echo "No existe el archivo."
    exit 1
}

[[ "$TARGET_DB" =~ ^[A-Za-z][A-Za-z0-9_]{0,62}$ ]] || {
    echo "Nombre de base inválido."
    exit 1
}

[[ -r "$AGE_IDENTITY_FILE" ]] || {
    echo "No se puede leer la clave privada."
    exit 1
}

TMP="$(mktemp)"
chmod 600 "$TMP"
trap 'rm -f "$TMP"' EXIT

age -d -i "$AGE_IDENTITY_FILE" "$BACKUP" > "$TMP"

pg_restore --list "$TMP" >/dev/null

EXISTS="$(psql -X -h "$PGHOST" -p "${PGPORT:-5432}" \
    -U "$PGUSER" -d postgres -At \
    -v db="$TARGET_DB" \
    -c "SELECT 1 FROM pg_database WHERE datname = :'db';")"

if [[ "$EXISTS" == "1" ]]; then
    echo "La base ya existe. No se sobrescribirá."
    exit 1
fi

read -r -p "Escribe RESTAURAR para crear $TARGET_DB: " ANSWER
[[ "$ANSWER" == "RESTAURAR" ]] || exit 1

createdb -h "$PGHOST" -p "${PGPORT:-5432}" \
    -U "$PGUSER" "$TARGET_DB"

pg_restore \
    -h "$PGHOST" \
    -p "${PGPORT:-5432}" \
    -U "$PGUSER" \
    -d "$TARGET_DB" \
    --no-owner \
    --no-acl \
    "$TMP"

echo "Restauración terminada: $TARGET_DB"
