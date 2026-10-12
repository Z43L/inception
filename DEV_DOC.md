# DEV_DOC — Developer documentation

How to set up, build, and modify the Inception project.

## Prerequisites

On the VM: `docker` (engine), the `docker compose` plugin, `make`,
`openssl`, and `sudo` (for the `/etc/hosts` entry). No Docker Hub account
needed — every image is built locally from `debian:bookworm-slim`.

## Repository layout

```
Makefile                        # single entry point: build + orchestrate
README.md / USER_DOC.md / DEV_DOC.md / DEFENSE.md
secrets/                        # *.txt = Docker secrets (git-ignored, mode 600)
srcs/requirements/
  docker-compose.yml            # services, network, volumes, secrets
  .env                          # NON-SECRET config (domain, users, db name)
  mariadb/   {Dockerfile, conf/, tools/}
  nginx/     {Dockerfile, conf/, tools/}      # TLS terminator, :443 only
  wordpress/ {Dockerfile, conf/, tools/}      # WP + php-fpm, no nginx
  bonus/
    redis/       # object cache (internal :6379)
    ftp/         # vsftpd over the WP volume (:21 + passive 21100-21110)
    static-site/ # nginx serving HTML/CSS/JS (:8080)
    adminer/     # DB admin UI (:8081)
    monitor/     # health JSON dashboard (:8090) — the "service of choice"
```

## Set up from scratch

```bash
# 0. Clone and enter the repo
cd inception

# 1. Personalize: replace every "login" placeholder
vim srcs/requirements/.env
#   LOGIN=<your 42 login>
#   DOMAIN_NAME=<login>.42.fr
#   WP_ADMIN_USER=<login>        # must NOT contain "admin"
#   ...emails...

# 2. Update the README byline (required first line by the subject)
vim README.md                    # *... by <login>.*

# 3. Generate secrets (passwords) — once per machine
make secrets

# 4. Resolve <login>.42.fr to the VM
make domain

# 5. Build images + create data dirs + start
make
```

## Build and launch with Makefile + Compose

| Command | Effect |
|---|---|
| `make` / `make all` | `build` + `up` |
| `make build` | ensures `secrets/` + `/home/<login>/data/*`, then `docker compose build` |
| `make up` | `docker compose up -d` + prints URLs |
| `make logs` / `make ps` | follow logs / list containers |
| `make stop` / `make start` / `make restart` / `make down` | lifecycle |
| `make clean` | `down` (containers+network removed, volumes kept) |
| `make fclean` | `down -v` + `docker rmi` (⚠️ deletes DB + WP files) |
| `make re` | `fclean` + `all` — clean-room rebuild |

Raw compose (from repo root) also works:

```bash
docker compose -f srcs/requirements/docker-compose.yml --env-file srcs/requirements/.env <cmd>
docker compose -f srcs/requirements/docker-compose.yml config   # validate YAML
```

## Managing containers and volumes

```bash
docker exec -it mariadb mysql -u root -p"$(cat secrets/db_root_password.txt)"
docker exec -it wordpress wp --allow-root --path=/var/www/html <wp-cli args>
docker volume ls | grep -E 'db_data|wp_data'
docker volume inspect <project>_db_data          # see the /home/<login>/data mount
docker network inspect inception                 # containers, IPs, DNS names
```

## Data persistence

- `db_data` → `/var/lib/mysql` in the mariadb container, stored at
  `/home/<login>/data/mariadb` on the host.
- `wp_data` → `/var/www/html` in the wordpress container (also mounted
  read into the ftp container), stored at `/home/<login>/data/wordpress`.
- Entrypoints are **idempotent**: MariaDB bootstraps users only on an empty
  datadir; WordPress installs only when `wp-config.php` is missing. Restarting
  never wipes data.

## Secrets rotation / config changes

- Passwords: edit `secrets/*.txt`, then `make re` (or
  `docker compose up -d --force-recreate <service>`).
- Non-secret config: edit `srcs/requirements/.env`, then
  `docker compose up -d` (recreates affected containers).
- TLS: the nginx entrypoint mints a self-signed cert on first boot into
  `/etc/nginx/ssl/`. To use a real certificate, place `inception.crt` /
  `inception.key` there (e.g. via a volume) — no code change needed.

## Modifying / extending

- New service: copy `bonus/monitor/` as a template (Dockerfile + code),
  add it to `docker-compose.yml` on the `inception` network with
  `restart: unless-stopped`, and document it in `USER_DOC.md`.
- Defense-style tweaks to practice: change the nginx `server_name`, add a
  `location /health` block, or expose Redis on a published port — then
  `docker compose up -d --build nginx`.
