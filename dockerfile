# Base image
FROM debian:bookworm-slim

# Install basic tools and dependencies for Sury PHP repo
RUN apt -y update \
  && apt -y install \
    apt-utils \
    wget \
    apache2 \
    apt-transport-https \
    lsb-release \
    ca-certificates \
    curl \
    git \
    vim \
    bind9 \
    bind9utils \
    software-properties-common \
    default-jdk \
    openjdk-17-jdk \
    unzip \
    rng-tools \
    certbot \
    python3-certbot-apache \
    mariadb-client \
    expect \
    sudo \
    cron \
    locales \
    gnupg2 \
    lsof \
  && rm -rf /var/cache/apt/archives/* \
  && rm -rf /var/lib/apt/lists/*

# Configure locale
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && update-locale LANG=en_US.UTF-8

# Add Sury PHP repository for Bookworm (PHP 8.4)
RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
    && sh -c 'echo "deb https://packages.sury.org/php/ bookworm main" > /etc/apt/sources.list.d/php.list' \
    && apt -y update

# Install PHP 8.4 + dev + Xdebug + extensions
RUN apt -y install \
    php8.4 \
    php8.4-dev \
    php-pear \
    php8.4-fpm \
    php8.4-xdebug \
    php8.4-gd \
    php8.4-curl \
    php8.4-mysql \
    php8.4-zip \
    php8.4-xml \
    php8.4-intl \
    php8.4-mbstring \
  && rm -rf /var/lib/apt/lists/*

# Enable Apache rewrite module
RUN a2enmod rewrite

# Ensure Xdebug is enabled in both CLI and Apache
RUN mkdir -p /etc/php/8.4/cli/conf.d /etc/php/8.4/apache2/conf.d \
    && echo "zend_extension=xdebug.so" > /etc/php/8.4/cli/conf.d/20-xdebug.ini \
    && echo "zend_extension=xdebug.so" > /etc/php/8.4/apache2/conf.d/20-xdebug.ini

# Prepare templates folder
RUN mkdir /templates
COPY php.ini_template /templates/php.ini

# Aspen-Discovery setup
RUN cd /usr/local \
  && git clone --depth=1 https://github.com/mdnoble73/aspen-discovery.git \
  && rm -rf ./aspen-discovery/.git

RUN cd /usr/local/aspen-discovery \
  && mkdir tmp \
  && chown -R www-data:www-data tmp \
  && chmod -R 755 tmp

# Create users and setup directories
RUN cd /usr/local/aspen-discovery/install \
  && sed -i 's/adduser/useradd/g' setup_aspen_user_debian.sh \
  && mkdir -p /var/log/aspen-discovery \
  && bash /usr/local/aspen-discovery/install/setup_aspen_user_debian.sh \
  && mkdir -p /data/aspen-discovery/test.localhostaspen/solr7 \
  && cp -r /usr/local/aspen-discovery/data_dir_setup/solr7 /data/aspen-discovery/test.localhostaspen \
  && rm -R /usr/local/aspen-discovery/

COPY dockerrun.sh /
RUN chmod +x /dockerrun.sh

ENTRYPOINT [ "/dockerrun.sh" ]
CMD [ "sleep", "infinity" ]
# Increase entropy
#RUN cp /usr/local/aspen-discovery/install/limits.conf /etc/security/limits.conf \
#    && cp /usr/local/aspen-discovery/install/rngd.service /etc/systemd/system/rngd.service \
#    && systemctl daemon-reload \
#    && systemctl start rngd