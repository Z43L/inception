# Secrets — NEVER committed (see .gitignore).
# Generate them on the VM with:  make secrets

# Files (all mounted as Docker secrets, readable at /run/secrets/<name>):
#
#   db_root_password.txt   MariaDB root password.
#   db_password.txt        Password of $MYSQL_USER (WordPress DB user).
#   ftp_password.txt       Password of the FTP user (bonus).
#   credentials.txt        WordPress users, two lines "user:password":
#                            line 1 -> administrator (name MUST NOT contain
#                                      "admin"/"administrator")
#                            line 2 -> second user (role from .env: WP_USER_ROLE)
#
# `make secrets` creates random values for all four files (600 perms).
# To rotate a password: edit the file, then `make re` (full rebuild).
# The WordPress admin password can also be changed from wp-admin afterwards.
