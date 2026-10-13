LOGIN    ?= $(shell grep '^LOGIN=' src/.env 2>/dev/null | cut -d= -f2)
DOMAIN   ?= $(shell grep '^DOMAIN_NAME=' src/.env 2>/dev/null | cut -d= -f2)
DATA_DIR := /home/davmoren/data
COMPOSE  := docker compose -f src/docker-compose.yml --env-file src/.env

.PHONY: all build up down start stop restart logs ps status clean fclean re secrets domain help

all: build up

# Build images (creates host data dirs + secrets first if missing).
build: secrets $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress
	$(COMPOSE) build

# Start the whole stack detached.
up:
	$(COMPOSE) up 
	@echo ""
	@echo "  WordPress : https://$(DOMAIN)"

down:
	$(COMPOSE) down

start:
	$(COMPOSE) start

stop:
	$(COMPOSE) stop

restart:
	$(COMPOSE) restart

logs:
	$(COMPOSE) logs -f

ps status:
	$(COMPOSE) ps

# Stop and remove containers + networks (keeps volumes and images).
clean:
	$(COMPOSE) down

# Full reset: containers, named volumes (DATABASE + WP FILES DELETED),
# and project images.
fclean:
	$(COMPOSE) down -v
	docker rmi -f mariadb wordpress nginx  2>/dev/null || true

re: fclean all

# Host data directories backing the named volumes (/home/<login>/data).
$(DATA_DIR)/mariadb $(DATA_DIR)/wordpress:
	mkdir -p $@

# Generate the Docker secrets (passwords) once; never overwrites existing.
secrets:
	@mkdir -p secrets
	@for f in db_root_password db_password; do \
		if [ ! -f secrets/$$f.txt ]; then \
			openssl rand -hex 16 > secrets/$$f.txt; \
			echo "generated secrets/$$f.txt"; \
		fi; \
	done
	@if [ ! -f secrets/credentials.txt ]; then \
		ADMIN_USER=$$(grep '^WP_ADMIN_USER=' src/.env | cut -d= -f2); \
		printf "%s:%s\n%s:%s\n" \
			"$$ADMIN_USER" "$$(openssl rand -hex 12)" \
			"$$(grep '^WP_USER=' src/.env | cut -d= -f2)" "$$(openssl rand -hex 12)" \
			> secrets/credentials.txt; \
		echo "generated secrets/credentials.txt"; \
	fi
	@chmod 600 secrets/*.txt
	@echo "(passwords stored only in secrets/*.txt — never committed)"

# Point <login>.42.fr to this VM (needs sudo).
domain:
	@if grep -q "$(DOMAIN)" /etc/hosts 2>/dev/null; then \
		echo "$(DOMAIN) already in /etc/hosts"; \
	else \
		echo "127.0.0.1 $(DOMAIN)" | sudo tee -a /etc/hosts > /dev/null; \
		echo "added $(DOMAIN) to /etc/hosts"; \
	fi

help:
	@echo "  make            build + start everything"
	@echo "  make build      build images (creates data dirs + secrets)"
	@echo "  make up         start stack detached"
	@echo "  make down       stop and remove containers"
	@echo "  make start/stop/restart/logs/ps"
	@echo "  make clean      down (keeps volumes)"
	@echo "  make fclean     down -v + remove images (DELETES DATA)"
	@echo "  make re         fclean + all"
	@echo "  make secrets    generate passwords in secrets/"
	@echo "  make domain     add login.42.fr to /etc/hosts"
