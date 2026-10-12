#!/bin/sh
# NGINX entrypoint.
# - Creates a self-signed TLS certificate for $DOMAIN_NAME on first run
#   (a real CA cert can be dropped in /etc/nginx/ssl/ instead).
# - Renders nginx.conf from the template, validates it, then execs nginx
#   in the foreground as PID 1 (no infinite-loop hacks).
set -eu

: "${DOMAIN_NAME:?DOMAIN_NAME must be set (see srcs/requirements/.env)}"

mkdir -p /etc/nginx/ssl
if [ ! -f /etc/nginx/ssl/inception.crt ]; then
    echo "[nginx] generating self-signed certificate for ${DOMAIN_NAME}..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/inception.key \
        -out    /etc/nginx/ssl/inception.crt \
        -subj "/CN=${DOMAIN_NAME}/O=Inception/C=ES"
fi

envsubst '${DOMAIN_NAME}' \
    < /etc/nginx/nginx.conf.template \
    > /etc/nginx/nginx.conf

nginx -t
echo "[nginx] listening on 443 for ${DOMAIN_NAME}..."
exec nginx -g 'daemon off;'
