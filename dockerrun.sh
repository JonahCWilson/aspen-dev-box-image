#!/usr/bin/env bash
#

set -e

SITENAME="${SITE_NAME:-test.localhostaspen}"
LOCAL_USER_ID="${LOCAL_USER_ID:-501}"
LOCAL_GROUP_ID="${LOCAL_GROUP_ID:-20}"

echo "Configuring container users to match host (UID=${LOCAL_USER_ID}, GID=${LOCAL_GROUP_ID})..."

# Remap www-data group GID — PHP-FPM (group=www-data) and Apache (APACHE_RUN_GROUP)
# resolve this group name at runtime, so it must carry the host GID.
groupmod -o -g "${LOCAL_GROUP_ID}" www-data
getent group aspen_apache > /dev/null 2>&1 || groupadd -o -g "${LOCAL_GROUP_ID}" aspen_apache
usermod -o -u "${LOCAL_USER_ID}" www-data
usermod -a -G aspen_apache www-data

if ! id aspen > /dev/null 2>&1; then
    useradd -r -o -u "${LOCAL_USER_ID}" -g www-data -G aspen_apache -m -s /bin/bash aspen
else
    usermod -o -u "${LOCAL_USER_ID}" -g www-data aspen
fi

if ! id solr > /dev/null 2>&1; then
    useradd -r -o -u "${LOCAL_USER_ID}" -g www-data -M -s /bin/bash solr
else
    usermod -o -u "${LOCAL_USER_ID}" -g www-data solr
fi

export CONFIG_DIRECTORY="/usr/local/aspen-discovery/sites/${SITENAME}"

cd /usr/local/aspen-discovery/docker/files/scripts

if [ ! -f "${CONFIG_DIRECTORY}/conf/config.ini" ]; then
    echo "Creating site configuration for ${SITENAME}..."
    php createConfig.php "${CONFIG_DIRECTORY}"
else
    echo "Site configuration exists, syncing env vars..."
fi
php syncEnvToConfig.php || true

echo "Initializing database..."
php initDatabase.php

echo "Setting up directories and permissions..."
php createDirs.php

echo "Running pending database updates..."
php updateDatabase.php "${SITENAME}"

crontab "${CONFIG_DIRECTORY}/conf/crontab"
service cron start

echo "Starting PHP-FPM..."
php-fpm8.4 &

echo "Waiting for PHP-FPM to be ready on port 9000..."
for i in {1..10}; do
    if nc -z 127.0.0.1 9000 2>/dev/null; then
        echo "PHP-FPM is ready"
        break
    fi
    sleep 1
done

echo "Starting Apache..."
service apache2 start

sudo -u www-data php /usr/local/aspen-discovery/docker/files/cron/checkBackgroundProcessesDocker.php "${SITENAME}" || true

/bin/bash -c "trap : TERM INT; sleep infinity & wait"
