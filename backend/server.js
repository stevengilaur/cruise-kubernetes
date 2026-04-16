const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());

// Configuration MySQL — les valeurs viennent des variables d'environnement
// (injectées via ConfigMap/Secret Kubernetes)
const dbConfig = {
  host:     process.env.DB_HOST     || 'localhost',
  port:     parseInt(process.env.DB_PORT) || 3306,
  user:     process.env.DB_USER     || 'todouser',
  password: process.env.DB_PASSWORD || 'todopassword',
  database: process.env.DB_NAME     || 'tododb',
  waitForConnections: true,
  connectionLimit: 10,
};

let pool;

// Connexion à la BDD avec retry (utile au démarrage du pod Kubernetes)
async function connectWithRetry(retries = 10, delay = 3000) {
  for (let i = 0; i < retries; i++) {
    try {
      pool = mysql.createPool(dbConfig);
      await pool.query('SELECT 1');
      console.log('Connecté à MySQL avec succès');
      return;
    } catch (err) {
      console.log(`Tentative ${i + 1}/${retries} — MySQL pas encore prêt, retry dans ${delay / 1000}s...`);
      await new Promise(res => setTimeout(res, delay));
    }
  }
  console.error('Impossible de se connecter à MySQL après plusieurs tentatives');
  process.exit(1);
}

// ─── ROUTES ───────────────────────────────────────────────────────────────────

// Health check pour les sondes Kubernetes
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', service: 'backend' });
});

// GET /todos — Récupérer toutes les tâches
app.get('/todos', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM todos ORDER BY created_at DESC');
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Erreur lors de la récupération des tâches' });
  }
});

// POST /todos — Créer une nouvelle tâche
app.post('/todos', async (req, res) => {
  const { title } = req.body;
  if (!title || !title.trim()) {
    return res.status(400).json({ error: 'Le titre est requis' });
  }
  try {
    const [result] = await pool.query(
      'INSERT INTO todos (title) VALUES (?)',
      [title.trim()]
    );
    res.status(201).json({ id: result.insertId, title: title.trim() });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Erreur lors de la création de la tâche' });
  }
});

// DELETE /todos/:id — Supprimer une tâche
app.delete('/todos/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await pool.query('DELETE FROM todos WHERE id = ?', [id]);
    res.status(204).send();
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Erreur lors de la suppression de la tâche' });
  }
});

// ─── DÉMARRAGE ────────────────────────────────────────────────────────────────

connectWithRetry().then(() => {
  app.listen(PORT, () => {
    console.log(`Backend démarré sur le port ${PORT}`);
    console.log(`Connecté à MySQL : ${dbConfig.host}:${dbConfig.port}/${dbConfig.database}`);
  });
});
