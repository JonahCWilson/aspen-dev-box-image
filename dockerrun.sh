#!/usr/bin/env bash
#

set -e

SITENAME="${SITENAME:-test.localhostaspen}"
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

mkdir -p /data/aspen-discovery/${SITENAME}/covers/{small,large,medium,original}
mkdir -p /data/aspen-discovery/${SITENAME}/solr7
mkdir -p /data/aspen-discovery/${SITENAME}/ils/{marc,marc_delta,marc_recs,supplemental}
mkdir -p /var/log/aspen-discovery/${SITENAME}
mkdir -p /var/run/aspen/

echo "Setting ownership on container-local directories..."
chown -R www-data:www-data /var/log/aspen-discovery/
chown -R aspen:www-data /data/aspen-discovery/${SITENAME}/
chown -R aspen:www-data /var/run/aspen/

mkdir -p /usr/local/aspen-discovery/tmp/smarty/compile/
chown -R www-data:www-data /usr/local/aspen-discovery/tmp/

service cron start

echo "Generating Apache configuration from template..."
bash /generate-apache-config.sh

echo "Configuring PHP-FPM to listen on TCP port 9000..."
cat > /etc/php/8.4/fpm/pool.d/www.conf <<'EOF'
[www]
user = www-data
group = www-data
listen = 127.0.0.1:9000
pm = dynamic
pm.max_children = 6
pm.start_servers = 2
pm.min_spare_servers = 2
pm.max_spare_servers = 5
chdir = /usr/local/aspen-discovery/code/web
request_terminate_timeout = 300
catch_workers_output = yes
php_admin_value[memory_limit] = 512M
php_admin_value[max_execution_time] = 300
EOF

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

curl -k http://localhost/API/SystemAPI?method=runPendingDatabaseUpdates

crontab /etc/cron.d/cron

/bin/bash -c "trap : TERM INT; sleep infinity & wait"
