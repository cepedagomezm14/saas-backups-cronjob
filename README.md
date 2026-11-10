# SaaS Backups

Sistema independiente de backups PostgreSQL a Google Drive.

## Requisitos

- Docker y Docker Compose.
- Una red Docker compartida con el proyecto SaaS.
- Usuario PostgreSQL con permisos de backup.
- Remote de Google Drive configurado con rclone.
- Clave pública age.

## Configuración

1. Editar .env.
2. Configurar config/rclone.conf.
3. Ajustar PGHOST y DOCKER_NETWORK.
4. Configurar DB_INCLUDE_REGEX.
5. Configurar AGE_RECIPIENT.

La clave privada age NO debe instalarse en el VPS de producción.

## Crear red compartida

Si la red aún no existe:

    docker network create saas-network

Usa el nombre real de la red de Nivel Pro.

## Construir e iniciar

    docker compose build
    docker compose up -d

## Ver logs

    docker compose logs -f

    docker compose exec backup-service \
      tail -f /data/logs/backup.log

## Ejecutar backup manual

    docker compose exec backup-service \
      bash -lc 'source /run/backup-env.sh && /scripts/backup.sh'

## Restauración

Ejecutar restore.sh desde un entorno seguro que tenga la clave
privada age y acceso a PostgreSQL.

La restauración siempre debe realizarse primero en una base nueva.
Nunca sobrescribir la base original sin validar la recuperación.

## Seguridad

- No subir .env ni rclone.conf a Git.
- No guardar la clave privada age en el VPS de producción.
- Mantener una copia externa de la clave privada.
- Probar restauraciones periódicamente.
- Respaldar también roles globales de PostgreSQL.
- Configurar una segunda ubicación de almacenamiento.
