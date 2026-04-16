const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Servir les fichiers statiques depuis le dossier public
app.use(express.static(path.join(__dirname, 'public')));

// Route principale
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Health check pour les sondes Kubernetes (liveness/readiness)
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', service: 'frontend' });
});

app.listen(PORT, () => {
  console.log(`Frontend démarré sur le port ${PORT}`);
});
