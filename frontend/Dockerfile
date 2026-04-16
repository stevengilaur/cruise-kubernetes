# Image de base : Alpine uniquement (règle du projet)
FROM alpine:3.19

# Installer Node.js et npm depuis les dépôts Alpine
RUN apk add --no-cache nodejs npm

# Créer le répertoire de travail
WORKDIR /app

# Copier les fichiers de dépendances en premier (optimise le cache Docker)
COPY package.json .

# Installer les dépendances Node.js
RUN npm install --production

# Copier le reste des fichiers de l'application
COPY . .

# Exposer le port du frontend
EXPOSE 3000

# Commande de démarrage
CMD ["node", "server.js"]
