FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    cron \
    postgresql-client \
    age \
    rclone \
    ca-certificates \
    tzdata \
    coreutils \
    findutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY scripts/ /scripts/
COPY cron/backup-cron /etc/cron.d/backup-cron

RUN chmod 700 /scripts/*.sh \
    && chmod 0644 /etc/cron.d/backup-cron \
    && mkdir -p /data/logs

ENTRYPOINT ["/scripts/entrypoint.sh"]
