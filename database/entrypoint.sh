#!/bin/sh
set -e

DATADIR="/var/lib/mysql"
SOCKET="/run/mysqld/mysqld.sock"

MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-rootpass}"
MYSQL_DATABASE="${MYSQL_DATABASE:-cruise}"
MYSQL_USER="${MYSQL_USER:-cruise}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-cruisepass}"

mkdir -p "$DATADIR" /run/mysqld
chown -R mysql:mysql "$DATADIR" /run/mysqld

if [ ! -d "$DATADIR/mysql" ]; then
  mariadb-install-db --user=mysql --datadir="$DATADIR"

  mariadbd --user=mysql --datadir="$DATADIR" --socket="$SOCKET" --skip-networking &
  pid="$!"

  for _ in $(seq 1 30); do
    if mariadb-admin --socket="$SOCKET" ping >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  mariadb --socket="$SOCKET" <<-EOSQL
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
    CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
    FLUSH PRIVILEGES;
EOSQL

  kill "$pid"
  wait "$pid" || true
fi

exec mariadbd --user=mysql --datadir="$DATADIR" --bind-address=0.0.0.0
