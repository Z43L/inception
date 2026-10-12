# NGINX — TLS terminator and ONLY entrypoint (port 443) into the stack.
# Built from the penultimate Debian stable (bookworm). No :latest.
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        nginx \
        openssl \
        gettext-base \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /etc/nginx/ssl /var/www/html

COPY conf/nginx.conf.template /etc/nginx/nginx.conf.template
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 443

# Generates a self-signed cert for $DOMAIN_NAME on first run, renders the
# config from the template, then execs nginx in the foreground as PID 1.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
