#!/bin/sh
set -e

# Variables d'environnement (avec valeurs par défaut)
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-rootpassword}

echo ">>> Initialisation de MariaDB..."

# Initialiser la base de données si elle n'existe pas encore
if [ ! -d "/var/lib/mysql/mysql" ]; then
  echo ">>> Première initialisation du datadir..."
  mysql_install_db --user=mysql --datadir=/var/lib/mysql --skip-test-db > /dev/null
fi

# Démarrer MariaDB en arrière-plan pour l'initialisation
mysqld --user=mysql --skip-networking &
MYSQL_PID=$!

# Attendre que MariaDB soit prêt
echo ">>> Attente de MariaDB..."
for i in $(seq 1 30); do
  if mysqladmin ping --silent 2>/dev/null; then
    break
  fi
  sleep 1
done

# Définir le mot de passe root
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'; FLUSH PRIVILEGES;"

# Exécuter le script d'initialisation
echo ">>> Exécution du script init.sql..."
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" < /docker-entrypoint-initdb.d/init.sql

echo ">>> Initialisation terminée. Redémarrage en mode normal..."

# Arrêter le MariaDB de bootstrap
kill $MYSQL_PID
wait $MYSQL_PID 2>/dev/null || true

# Démarrer MariaDB en mode normal (TCP activé, port 3306)
exec mysqld --user=mysql --bind-address=0.0.0.0 --port=3306 --skip-networking=OFF
