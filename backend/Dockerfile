# Image de base : Alpine uniquement (règle du projet)
FROM alpine:3.19

# Installer Node.js et npm
RUN apk add --no-cache nodejs npm

# Créer le répertoire de travail
WORKDIR /app

# Copier les fichiers de dépendances en premier (optimise le cache Docker)
COPY package.json .

# Installer les dépendances Node.js
RUN npm install --production

# Copier le reste des fichiers
COPY . .

# Exposer le port de l'API
EXPOSE 3001

# Commande de démarrage
CMD ["node", "server.js"]
