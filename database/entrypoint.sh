#!/bin/sh
set -e

MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-rootpassword}

# Détecter si ce pod est primary (index 0) ou replica (index 1+)
# $HOSTNAME = todo-database-0, todo-database-1, etc.
POD_INDEX=${HOSTNAME##*-}
echo ">>> Pod index: $POD_INDEX"

if [ "$POD_INDEX" = "0" ]; then
  ROLE="primary"
  SERVER_ID=1
  EXTRA_FLAGS="--log-bin=mysql-bin --binlog-format=ROW --server-id=1"
else
  ROLE="replica"
  SERVER_ID=$((POD_INDEX + 1))
  EXTRA_FLAGS="--server-id=${SERVER_ID} --relay-log=relay-bin --read-only=1"
fi

echo ">>> Rôle : $ROLE (server-id=$SERVER_ID)"

FIRST_RUN=false
if [ ! -d "/var/lib/mysql/mysql" ]; then
  echo ">>> Première initialisation du datadir..."
  mysql_install_db --user=mysql --datadir=/var/lib/mysql --skip-test-db > /dev/null
  FIRST_RUN=true
fi

# Bootstrap sans réseau ni vérification des droits
mysqld --user=mysql --skip-networking --skip-grant-tables &
MYSQL_PID=$!

echo ">>> Attente de MariaDB..."
for i in $(seq 1 30); do
  if mysqladmin ping --silent 2>/dev/null; then
    break
  fi
  sleep 1
done

# Configurer root
mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

# Initialisation uniquement sur le primary à la première création
if [ "$FIRST_RUN" = "true" ] && [ "$ROLE" = "primary" ]; then
  echo ">>> Exécution du script init.sql..."
  mysql -u root -p"${MYSQL_ROOT_PASSWORD}" < /docker-entrypoint-initdb.d/init.sql

  echo ">>> Création de l'utilisateur de réplication..."
  mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<EOF
CREATE USER IF NOT EXISTS 'replicator'@'%' IDENTIFIED BY 'replicatorpassword';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';
FLUSH PRIVILEGES;
EOF
fi

echo ">>> Arrêt du bootstrap..."
kill $MYSQL_PID
wait $MYSQL_PID 2>/dev/null || true

echo ">>> Démarrage en mode normal (rôle: $ROLE)..."
exec mysqld --user=mysql \
  --bind-address=0.0.0.0 \
  --port=3306 \
  --skip-networking=OFF \
  $EXTRA_FLAGS
