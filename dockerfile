FROM debian:bookworm

ENV container docker
STOPSIGNAL SIGRTMIN+3

# --- systemd base ---
RUN apt-get update && apt-get install -y \
    systemd \
    systemd-sysv \
    dbus \
    dbus-user-session \
    ca-certificates \
    curl \
    wget \
    gnupg2 \
    lsb-release \
    apt-transport-https \
    locales \
    && rm -rf /var/lib/apt/lists/*

# --- required for systemd in containers ---
RUN mkdir -p /run/systemd \
    && echo "docker" > /run/systemd/container \
    && systemctl set-default multi-user.target

# --- Sury PHP repo (needed for php8.4) ---
RUN curl -fsSL https://packages.sury.org/php/apt.gpg \
    | gpg --dearmor -o /etc/apt/trusted.gpg.d/php.gpg \
    && echo "deb https://packages.sury.org/php/ bookworm main" \
    > /etc/apt/sources.list.d/php.list

RUN apt-get update

# --- your stack ---
RUN apt-get install -y \
    apache2 \
    php8.4 \
    php8.4-fpm \
    openjdk-17-jdk \
    cron \
    && rm -rf /var/lib/apt/lists/*

# --- systemd service ---
COPY koha_indexer.service /etc/systemd/system/koha_indexer.service

# IMPORTANT: enable service correctly (NOT systemctl)
RUN ln -s /etc/systemd/system/koha_indexer.service \
    /etc/systemd/system/multi-user.target.wants/koha_indexer.service

RUN systemctl mask getty.target

# --- systemd init ---
CMD ["/lib/systemd/systemd"]