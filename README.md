*This project has been created as part of the 42 curriculum by davmoren.*

# Inception

## Description

Inception is a **system administration** project: build a small, production-like
web infrastructure from scratch with **Docker**, running on a personal virtual
machine. Three mandatory services — **NGINX** (TLS terminator), **WordPress +
php-fpm**, and **MariaDB** — each run in their own container, built from their
own hand-written `Dockerfile` on top of **Debian bookworm-slim** (the
penultimate Debian stable release). No pre-built application images are pulled,
no `:latest` tags are used, and no passwords appear anywhere in the Dockerfiles.

Persistent data lives in two **named volumes** (database + WordPress files)
whose storage is rooted at `/home/<login>/data` on the host. All containers
share a dedicated Docker network, restart automatically on crash, and the only
way into the stack is **NGINX on port 443 with TLS 1.2/1.3**.

The bonus adds five services: a **Redis** object cache for WordPress, an **FTP**
server over the WordPress files, a **static showcase site** (HTML/CSS/JS, no
PHP), **Adminer** for database administration, and a tiny **health monitor**
(JSON dashboard, the "service of choice").

## Instructions

Prerequisites on the VM: `docker`, `docker compose` plugin, `make`, `openssl`.

```bash
# 1. Personalize (do this FIRST — replaces every "login" placeholder)
vim srcs/requirements/.env        # set LOGIN, DOMAIN_NAME, WP_ADMIN_USER, emails

# 2. Generate passwords (Docker secrets, never committed)
make secrets

# 3. Point login.42.fr at this machine (needs sudo)
make domain

# 4. Build everything and start the stack
make

# Open https://login.42.fr  (accept the self-signed certificate warning)
```

Useful commands:

```bash
make logs      # follow logs of all services
make ps        # container status
make stop      # stop containers (data kept)
make start     # start again
make down      # stop + remove containers (data kept)
make fclean    # full reset: containers + volumes + images (DELETES DATA)
make re        # fclean + rebuild from scratch
```

See `USER_DOC.md` (how to use the stack) and `DEV_DOC.md` (how to rebuild and
hack on it). `DEFENSE.md` is a cheat sheet for the peer evaluation.

## Resources

- Docker docs — [Dockerfile reference](https://docs.docker.com/reference/dockerfile/),
  [Compose specification](https://docs.docker.com/reference/compose-file/),
  [Use secrets](https://docs.docker.com/engine/swarm/secrets/),
  [Networking overview](https://docs.docker.com/engine/network/)
- [NGINX — ngx_http_ssl_module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
  (TLS protocol/cipher configuration)
- [WordPress + wp-cli handbook](https://developer.wordpress.org/cli/commands/)
- [MariaDB — mariadb-install-db](https://mariadb.com/kb/en/mariadb-install-db/)
- [Docker — "PID 1 problem" and init processes](https://docs.docker.com/engine/containers/multi-service_container/)
  (why `tail -f` / `sleep infinity` are banned and daemons must run in the foreground)

### How AI was used

AI (Muse, by Meta) assisted as a **pair-programmer and reviewer** while the
project author kept full ownership of every line:

- **Scaffolding drafts**: first versions of the Dockerfiles, the
  `docker-compose.yml`, the entrypoint scripts and the Makefile were drafted
  with AI, then read line by line, corrected and adapted by the author.
- **Checklist auditing**: AI was asked to verify the draft against the subject
  (no `:latest`, no passwords in Dockerfiles, TLS 1.2/1.3 only, named volumes
  under `/home/<login>/data`, two WP users without "admin" in the name, network
  line present, `restart` policies, no infinite-loop hacks).
- **Documentation**: structure and wording of `README.md`, `USER_DOC.md` and
  `DEV_DOC.md` were refined with AI suggestions.
- **Not delegated**: the architecture decisions (Debian vs Alpine, self-signed
  cert strategy, secret file layout, bonus service choices), the final review
  of every script, and the live testing on the VM were done by the author, who
  can explain and defend each choice during the evaluation.

## Project description

### What Docker is used for

Docker packages each service (NGINX, WordPress+php-fpm, MariaDB, …) with its
exact dependencies into an **immutable image** built from a `Dockerfile`.
`docker-compose.yml` then declares how those images become **containers** —
their networks, volumes, secrets, restart policies and dependencies — so the
whole infrastructure is reproducible with a single `make`. The `Makefile` is
the project's single entry point: it prepares host directories, generates
secrets, builds images and orchestrates the stack.

### Main design choices

- **Debian bookworm-slim** everywhere (penultimate stable): one base to learn
  deeply instead of mixing Alpine/Debian quirks; `apt` packages
  (nginx, mariadb-server, php8.2-fpm, redis-server, vsftpd) keep Dockerfiles
  short and auditable.
- **One process per container, PID 1 in the foreground**: each entrypoint ends
  with `exec <daemon>`, so signals (SIGTERM on `docker stop`) reach the real
  process and the container stops cleanly — no `tail -f`, no `sleep infinity`.
- **Secrets, not env vars, for passwords**: MariaDB/WordPress/FTP passwords are
  mounted from `secrets/*.txt` into `/run/secrets/` (tmpfs, never in the
  image layers, never in git). `.env` holds only non-sensitive configuration.
- **Self-signed TLS generated at container start**: the NGINX entrypoint mints
  a certificate for `$DOMAIN_NAME` if none exists, so a fresh `make` works
  with zero manual steps; dropping a real CA cert into `/etc/nginx/ssl/`
  upgrades it without code changes.
- **WordPress installed idempotently**: `wp-cli` installs core + the two users
  only when `wp-config.php` is absent, so restarts and rebuilds never wipe the
  site — data survives in the named volumes.

### Virtual Machines vs Docker

| | Virtual Machine | Docker container |
|---|---|---|
| Isolation | Full guest OS + hypervisor | Kernel namespaces/cgroups on the host kernel |
| Size / boot | GBs, tens of seconds | MBs, milliseconds–seconds |
| Density | A few per host | Dozens per host |
| Use here | The 42 VM hosting everything | Each service isolated, reproducible, disposable |

Containers are not mini-VMs: they share the host kernel, which is why one
service = one container and why daemons must run as PID 1 in the foreground.

### Secrets vs Environment Variables

Environment variables are convenient but **leak easily**: they appear in
`docker inspect`, in process listings, and — the classic failure — committed
in `.env` files or Dockerfiles. Docker **secrets** are mounted as files under
`/run/secrets/` (an in-memory tmpfs), never baked into image layers, and the
source files (`secrets/*.txt`) are git-ignored. Rule of thumb used here:
*configuration* (domain, usernames, DB name) → `.env`; *credentials*
(passwords, keys) → secrets.

### Docker Network vs Host Network

`network_mode: host` (forbidden by the subject) removes isolation: containers
share the host's network stack and ports, defeating portability and the
"only entrypoint is NGINX:443" guarantee. A dedicated **bridge network**
(`inception`) gives each container its own IP and **DNS name = service name**,
so `wordpress` reaches the database simply as `mariadb:3306` — no hardcoded
IPs, no `--link` hacks — while only explicitly published ports are reachable
from outside.

### Docker Volumes vs Bind Mounts

Bind mounts (`./data:/var/lib/mysql`) tie the container to an arbitrary host
path, with host-dependent permissions and no lifecycle management. **Named
volumes** are first-class Docker objects: Docker owns their lifecycle
(`docker volume ls/prune`), they work identically on any host, and here they
are rooted at `/home/<login>/data` via `driver_opts` so the data also satisfies
the subject's location requirement. Either way, the database and the website
survive `docker compose down` and container rebuilds.
