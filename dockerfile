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

# Add sury's repo
RUN wget -O- -q https://packages.sury.org/php/apt.gpg \
      | gpg --dearmor \
      | tee /usr/share/keyrings/sury.gpg >/dev/null \
   && echo "deb [signed-by=/usr/share/keyrings/sury.gpg] https://packages.sury.org/php/ bookworm main" > /etc/apt/sources.list.d/sury.list

# Install php deps
# --- your stack ---
RUN apt -y update \
	&& apt install -y \
	  php8.4 \
	  php8.4-fpm \
	  php8.4-mcrypt \
	  php8.4-gd \
	  php8.4-imagick \
	  php8.4-curl \
	  php8.4-zip \
	  php8.4-xml \
	  php8.4-intl \
	  php8.4-mbstring \
	  php8.4-soap \
	  php8.4-pgsql \
	  php8.4-ssh2 \
	  php8.4-ldap \
	  php8.4-mysql \
    cron \
    openjdk-17-jdk \
    apache2 \
	&& rm -rf /var/cache/apt/archives/* \
	&& rm -rf /var/lib/apt/lists/*

# --- systemd service ---
COPY koha_indexer.service /etc/systemd/system/koha_indexer.service

# IMPORTANT: enable service correctly (NOT systemctl)
RUN ln -s /etc/systemd/system/koha_indexer.service \
    /etc/systemd/system/multi-user.target.wants/koha_indexer.service

RUN systemctl mask getty.target

# --- systemd init ---
CMD ["/lib/systemd/systemd"]