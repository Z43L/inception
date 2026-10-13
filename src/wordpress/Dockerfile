# WordPress + php-fpm ONLY (no nginx in this container).
# Built from the penultimate Debian stable (bookworm). No :latest.
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        php8.2-fpm \
        php8.2-mysql \
        php8.2-redis \
        php8.2-curl \
        php8.2-gd \
        php8.2-mbstring \
        php8.2-xml \
        php8.2-zip \
        mariadb-client \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# wp-cli (official phar).
RUN curl -fsSL -o /usr/local/bin/wp \
        https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

# Download WordPress core
RUN mkdir -p /usr/src/wordpress \
    && curl -fsSL -o /tmp/wp.tar.gz https://wordpress.org/latest.tar.gz \
    && tar -xzf /tmp/wp.tar.gz -C /usr/src/wordpress --strip-components=1 \
    && rm /tmp/wp.tar.gz \
    && chown -R www-data:www-data /usr/src/wordpress

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 9000

# Waits for MariaDB, installs/configures WordPress on first run
# (2 users: administrator + editor), then execs php-fpm as PID 1.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
