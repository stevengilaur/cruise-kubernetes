# Image de base : Alpine uniquement (règle du projet)
FROM alpine:3.19

# Installer MariaDB (compatible MySQL, disponible sur Alpine)
RUN apk add --no-cache mariadb mariadb-client

# Créer les répertoires nécessaires
RUN mkdir -p /run/mysqld /var/lib/mysql && \
    chown -R mysql:mysql /run/mysqld /var/lib/mysql

# Copier le script d'initialisation de la base de données
COPY init.sql /docker-entrypoint-initdb.d/init.sql

# Copier le script de démarrage
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Exposer le port MySQL/MariaDB
EXPOSE 3306

# Démarrage via le script custom
ENTRYPOINT ["/entrypoint.sh"]
