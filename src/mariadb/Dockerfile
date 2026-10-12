# MariaDB — built from the penultimate Debian stable (bookworm).
# No pulled database image, no :latest tag.
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        mariadb-server \
        mariadb-client \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/mysqld /var/lib/mysql \
    && chown -R mysql:mysql /var/run/mysqld /var/lib/mysql

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/init-db.sh /usr/local/bin/init-db.sh
RUN chmod +x /usr/local/bin/init-db.sh

EXPOSE 3306

# The entrypoint bootstraps the database on first run, then execs mysqld
# as PID 1 (no tail -f / sleep infinity hacks).
ENTRYPOINT ["/usr/local/bin/init-db.sh"]
