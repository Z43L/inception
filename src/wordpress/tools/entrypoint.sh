#!/bin/sh
# WordPress entrypoint.
# - Waits (bounded) for MariaDB to accept connections.
# - On first run: populates /var/www/html, creates wp-config.php from
#   Docker secrets, installs WordPress and creates TWO users
#   (administrator + a second user), wires the Redis object cache.
# - Then execs php-fpm in the foreground as PID 1.
set -eu

DB_PW="$(cat /run/secrets/db_password)"

# secrets/credentials.txt format (see secrets/README.md):
#   line 1 -> "<admin_user>:<admin_password>"   (no "admin" in the name!)
#   line 2 -> "<second_user>:<second_password>"
ADMIN_USER="$(sed -n '1p' /run/secrets/credentials.txt | cut -d: -f1)"
ADMIN_PW="$(sed -n '1p' /run/secrets/credentials.txt | cut -d: -f2-)"
EXTRA_USER="$(sed -n '2p' /run/secrets/credentials.txt | cut -d: -f1)"
EXTRA_PW="$(sed -n '2p' /run/secrets/credentials.txt | cut -d: -f2-)"

echo "[wordpress] waiting for MariaDB..."
for _ in $(seq 1 60); do
    if mysqladmin ping -h mariadb -u "${MYSQL_USER}" -p"${DB_PW}" --silent 2> /dev/null; then
        break
    fi
    sleep 2
done

if [ ! -f /var/www/html/wp-config.php ]; then
    echo "[wordpress] first run: installing WordPress..."
    cp -a /usr/src/wordpress/. /var/www/html/
    cd /var/www/html

    wp config create \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${DB_PW}" \
        --dbhost="mariadb" \
        --allow-root

    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${ADMIN_USER}" \
        --admin_password="${ADMIN_PW}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --allow-root

    wp user create "${EXTRA_USER}" "${WP_USER_EMAIL}" \
        --role="${WP_USER_ROLE}" \
        --user_pass="${EXTRA_PW}" \
        --allow-root

    # Bonus: Redis object cache (best effort — skipped if offline).
    wp config set WP_REDIS_HOST "${REDIS_HOST}" --allow-root || true
    wp plugin install redis-cache --activate --allow-root \
        || echo "[wordpress] redis-cache plugin install skipped"

    chown -R www-data:www-data /var/www/html
    echo "[wordpress] installed: admin='${ADMIN_USER}', extra='${EXTRA_USER}'."
else
    echo "[wordpress] already installed, skipping setup."
fi

echo "[wordpress] starting php-fpm on :9000..."
exec php-fpm8.2 -F
