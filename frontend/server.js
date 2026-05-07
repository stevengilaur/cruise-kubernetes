const express = require('express');
const http = require('http');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const BACKEND_URL = process.env.BACKEND_URL || 'http://todo-backend-svc:3001';

// Parser JSON pour les requêtes POST
app.use(express.json());

// Proxy vers le backend — /api/* → todo-backend-svc:3001/*
app.use('/api', (req, res) => {
  const backendHost = BACKEND_URL.replace('http://', '').split(':')[0];
  const backendPort = BACKEND_URL.split(':')[2] || 3001;
  const apiPath = req.url;

  const options = {
    hostname: backendHost,
    port: backendPort,
    path: apiPath,
    method: req.method,
    headers: {
      'Content-Type': 'application/json',
    },
  };

  const proxy = http.request(options, (proxyRes) => {
    res.writeHead(proxyRes.statusCode, { 'Content-Type': 'application/json' });
    proxyRes.pipe(res);
  });

  proxy.on('error', (err) => {
    console.error('Erreur proxy backend:', err.message);
    res.status(502).json({ error: 'Backend inaccessible' });
  });

  if (req.body && Object.keys(req.body).length > 0) {
    proxy.write(JSON.stringify(req.body));
  }

  proxy.end();
});

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
