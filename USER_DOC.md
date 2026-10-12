# USER_DOC — User documentation

How to use the Inception stack as an end user / administrator. For building
and hacking on the project, see `DEV_DOC.md`.

## What the stack provides

| Service   | What it is                                  | How to reach it                |
|-----------|---------------------------------------------|--------------------------------|
| Website   | WordPress blog, served over TLS 1.2/1.3     | `https://<login>.42.fr`        |
| wp-admin  | WordPress administration panel              | `https://<login>.42.fr/wp-admin` |
| Static    | Bonus showcase site (HTML/CSS/JS)           | `http://<vm-ip>:8080`          |
| Adminer   | Bonus database admin UI                     | `http://<vm-ip>:8081`          |
| Monitor   | Bonus health dashboard (JSON)               | `http://<vm-ip>:8090`          |
| FTP       | Bonus file access to the WordPress volume   | `ftp://<vm-ip>:21` (user `ftpuser`) |
| Redis     | Bonus WordPress object cache                | internal only (no port)        |

Replace `<login>` with your 42 username and `<vm-ip>` with the VM's address.
The browser will warn about the **self-signed certificate** on
`https://<login>.42.fr` — that is expected; accept the exception (or install a
real certificate, see `DEV_DOC.md`).

## Start and stop

```bash
make           # build (first time) + start everything, detached
make stop      # stop all containers (data is kept)
make start     # start them again
make down      # stop and remove containers (data is kept)
make restart   # restart all services
make fclean    # ⚠️ full reset: containers + volumes + images (DELETES DATA)
```

## First visit checklist

1. Open `https://<login>.42.fr` → the WordPress site should load.
2. Open `https://<login>.42.fr/wp-admin` → log in as the administrator user
   (see "Credentials" below) → publish a test post.
3. Open `http://<vm-ip>:8090` → every service should report `"up"`.

## Credentials

All passwords live **only** in `secrets/*.txt` on the VM (mode 600, never in
git). They were generated with `make secrets`.

| Credential | Where it is |
|---|---|
| WordPress administrator (`user:password`, line 1) | `secrets/credentials.txt` |
| WordPress second user (`user:password`, line 2) | `secrets/credentials.txt` |
| MariaDB `root` password | `secrets/db_root_password.txt` |
| MariaDB WordPress user password | `secrets/db_password.txt` |
| FTP user `ftpuser` password | `secrets/ftp_password.txt` |

Non-secret settings (domain, DB name, usernames) are in
`srcs/requirements/.env`.

## Check that services are running correctly

```bash
make ps                          # container states (should be "running")
make logs                        # live logs of everything
curl -sk https://<login>.42.fr -o /dev/null -w "%{http_code}\n"   # expect 200
curl -s http://localhost:8090    # {"status": {"nginx":"up", ...}}
```

Database sanity via Adminer (`http://<vm-ip>:8081`):
server `mariadb`, user `wpuser`, password from `secrets/db_password.txt`,
database `wordpress` — you should see the `wp_*` tables.

## Where the data lives

- Database files: `/home/<login>/data/mariadb` on the VM host.
- WordPress files: `/home/<login>/data/wordpress` on the VM host.
- Both are Docker **named volumes** (`db_data`, `wp_data`); they survive
  container restarts, rebuilds and `make down`. Only `make fclean`
  (`docker compose down -v`) deletes them.
