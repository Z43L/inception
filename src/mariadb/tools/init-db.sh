#!/bin/sh
set -eu

DATADIR="/var/lib/mysql"
SOCK="/run/mysqld/mysqld.sock"

DB_ROOT_PW="$(cat /run/secrets/db_root_password)"
DB_PW="$(cat /run/secrets/db_password)"

: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
: "${MYSQL_USER:?MYSQL_USER is required}"

# Limitar los identificadores a caracteres seguros.
case "$MYSQL_DATABASE" in
    ''|*[!a-zA-Z0-9_]*)
        echo "[mariadb] Invalid database name" >&2
        exit 1
        ;;
esac

case "$MYSQL_USER" in
    ''|*[!a-zA-Z0-9_]*)
        echo "[mariadb] Invalid database username" >&2
        exit 1
        ;;
esac

# Escapar contraseñas para literales SQL de MariaDB.
sql_escape() {
    printf '%s' "$1" |
        sed -e 's/\\/\\\\/g' -e "s/'/''/g"
}

ROOT_SQL_PW="$(sql_escape "$DB_ROOT_PW")"
USER_SQL_PW="$(sql_escape "$DB_PW")"

mkdir -p /run/mysqld "$DATADIR"
chown mysql:mysql /run/mysqld "$DATADIR"

FIRST_RUN=0

# Inicializar las tablas del sistema una sola vez.
if [ ! -d "$DATADIR/mysql" ]; then
    echo "[mariadb] Initializing database..."

    mariadb-install-db \
        --user=mysql \
        --datadir="$DATADIR" \
        --auth-root-authentication-method=normal

    FIRST_RUN=1
fi

# Arrancar temporalmente sin conexiones de red.
echo "[mariadb] Starting temporary server..."

mysqld \
    --user=mysql \
    --datadir="$DATADIR" \
    --socket="$SOCK" \
    --skip-networking &

TEMP_PID=$!

cleanup() {
    if kill -0 "$TEMP_PID" 2>/dev/null; then
        kill "$TEMP_PID" 2>/dev/null || true
        wait "$TEMP_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT

READY=0

for i in $(seq 1 30); do
    if [ "$FIRST_RUN" -eq 1 ]; then
        if mariadb -u root --socket="$SOCK" \
            -e "SELECT 1" >/dev/null 2>&1; then
            READY=1
            break
        fi
    else
        if MYSQL_PWD="$DB_ROOT_PW" mariadb \
            -u root --socket="$SOCK" \
            -e "SELECT 1" >/dev/null 2>&1; then
            READY=1
            break
        fi
    fi
    sleep 1
done

if [ "$READY" -ne 1 ]; then
    echo "[mariadb] ERROR: authentication or startup failed" >&2
    exit 1
fi

# Configurar root únicamente en la primera inicialización.
if [ "$FIRST_RUN" -eq 1 ]; then
    echo "[mariadb] Setting root password..."

    mariadb -u root --socket="$SOCK" <<SQL
ALTER USER 'root'@'localhost'
    IDENTIFIED BY '${ROOT_SQL_PW}';
SQL
fi

# Reparar configuración sin borrar datos existentes.
echo "[mariadb] Ensuring WordPress database and user..."

MYSQL_PWD="$DB_ROOT_PW" mariadb \
    -u root --socket="$SOCK" <<SQL
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%'
    IDENTIFIED BY '${USER_SQL_PW}';

ALTER USER '${MYSQL_USER}'@'%'
    IDENTIFIED BY '${USER_SQL_PW}';

GRANT ALL PRIVILEGES
    ON \`${MYSQL_DATABASE}\`.*
    TO '${MYSQL_USER}'@'%';
SQL

echo "[mariadb] WordPress database configured."

# Apagar el servidor temporal correctamente.
MYSQL_PWD="$DB_ROOT_PW" mariadb-admin \
    -u root --socket="$SOCK" shutdown

wait "$TEMP_PID"
trap - EXIT

# Iniciar el servidor definitivo como PID 1.
echo "[mariadb] Starting production server..."

exec mysqld \
    --user=mysql \
    --datadir="$DATADIR"

