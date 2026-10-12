#!/bin/sh
# MariaDB entrypoint.
# - On first run (empty datadir) it initializes the system tables, boots a
#   temporary server WITHOUT networking, creates the database + users from
#   Docker secrets, then shuts it down.
# - Afterwards it execs mysqld as PID 1 (proper daemon behavior, no
#   `tail -f` / `sleep infinity` hacks).
set -eu

DB_ROOT_PW="$(cat /run/secrets/db_root_password)"
DB_PW="$(cat /run/secrets/db_password)"
SOCK=/run/mysqld/mysqld.sock

if [ ! -d /var/lib/mysql/mysql ]; then
    echo "[mariadb] first run: initializing data directory..."
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql \
        --auth-root-authentication-method=normal > /dev/null

    echo "[mariadb] bootstrapping users..."
    mysqld_safe --skip-networking --socket="$SOCK" > /tmp/bootstrap.log 2>&1 &
    for _ in $(seq 1 30); do
        if mysqladmin --socket="$SOCK" ping --silent 2> /dev/null; then
            break
        fi
        sleep 1
    done

    mysql --socket="$SOCK" <<EOSQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PW}';
DELETE FROM mysql.user WHERE user = '';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PW}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOSQL

    mysqladmin --socket="$SOCK" -u root -p"${DB_ROOT_PW}" shutdown
    wait 2> /dev/null || true
    echo "[mariadb] bootstrap complete."
fi

echo "[mariadb] starting mysqld..."
exec mysqld --user=mysql
