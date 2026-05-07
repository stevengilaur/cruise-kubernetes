# Étape 6 — Services Kubernetes & Fix Frontend

## Objectif
Exposer les pods via des Services Kubernetes pour qu'ils puissent communiquer entre eux
et être accessibles depuis l'extérieur du cluster.

---

## Prérequis
- Les 3 pods Running (Étape 5)
- Se connecter au master : `vagrant ssh k8s-master`

---

## 1. Appliquer les Services

```bash
kubectl apply -f /vagrant/k8s/database/service.yaml
kubectl apply -f /vagrant/k8s/backend/service.yaml
kubectl apply -f /vagrant/k8s/frontend/service.yaml
```

Vérifier :
```bash
kubectl get services -n prod
```

Résultat attendu :
```
NAME                TYPE        CLUSTER-IP       PORT(S)
todo-backend-svc    ClusterIP   10.100.26.81     3001/TCP
todo-database-svc   ClusterIP   10.103.101.223   3306/TCP
todo-frontend-svc   NodePort    10.109.194.88    3000:30000/TCP
```

---

## 2. Types de Services utilisés

| Service | Type | Rôle |
|---|---|---|
| `todo-database-svc` | ClusterIP | Accessible uniquement en interne (backend → DB) |
| `todo-backend-svc` | ClusterIP | Accessible uniquement en interne (frontend → backend) |
| `todo-frontend-svc` | NodePort (30000) | Accessible depuis l'extérieur via le PC |

---

## 3. Problème : backend CrashLoopBackOff après création des Services

Après création des Services, le pod `todo-backend` peut être en `CrashLoopBackOff`
parce qu'il a épuisé ses tentatives de connexion MySQL **avant** que le Service existe.

**Solution** — supprimer et recréer le pod :
```bash
kubectl delete pod todo-backend -n prod
kubectl apply -f /vagrant/k8s/backend/pod.yaml
```

Vérifier les logs :
```bash
kubectl logs todo-backend -n prod
# Connecté à MySQL avec succès
# Backend démarré sur le port 3001
# Connecté à MySQL : todo-database-svc:3306/tododb
```

---

## 4. Problème : "Impossible de contacter le backend" dans le navigateur

### Explication

Le JavaScript du navigateur utilisait `http://localhost:3001` comme URL du backend.
`localhost` dans le navigateur pointe vers le PC Windows, pas vers le pod backend dans le cluster.
Les adresses ClusterIP (`10.x.x.x`) sont internes au cluster et inaccessibles depuis le navigateur.

### Solution : proxy server-side dans le frontend

Le frontend Node.js intercepte les requêtes `/api/*` et les transmet au backend
via le DNS interne Kubernetes (`todo-backend-svc:3001`). Le navigateur ne parle qu'au
frontend — il n'a jamais besoin d'accéder directement au backend.

```
Navigateur → /api/todos → Frontend (port 3000) → todo-backend-svc:3001/todos → Backend → MySQL
```

### Modifications apportées

**`frontend/server.js`** — ajout d'un proxy `/api` :

```javascript
const http = require('http');
const BACKEND_URL = process.env.BACKEND_URL || 'http://todo-backend-svc:3001';

app.use('/api', (req, res) => {
  const backendHost = BACKEND_URL.replace('http://', '').split(':')[0];
  const backendPort = BACKEND_URL.split(':')[2] || 3001;

  const options = {
    hostname: backendHost,
    port: backendPort,
    path: req.url,
    method: req.method,
    headers: { 'Content-Type': 'application/json' },
  };

  const proxy = http.request(options, (proxyRes) => {
    res.writeHead(proxyRes.statusCode, { 'Content-Type': 'application/json' });
    proxyRes.pipe(res);
  });

  proxy.on('error', (err) => {
    res.status(502).json({ error: 'Backend inaccessible' });
  });

  if (req.body && Object.keys(req.body).length > 0) {
    proxy.write(JSON.stringify(req.body));
  }

  proxy.end();
});
```

**`frontend/public/index.html`** — changer l'URL de l'API :

```javascript
// Avant
const API_URL = window.BACKEND_URL || 'http://localhost:3001';

// Après
const API_URL = '/api';
```

---

## 5. Rebuild et push de l'image frontend

Depuis le dossier du projet sur le PC Windows (Git Bash) :

```bash
docker build -t 192.168.56.10:5000/todo-frontend:v2 ./frontend
docker push 192.168.56.10:5000/todo-frontend:v2
```

---

## 6. Redéployer le frontend avec la nouvelle image

Sur le master :

```bash
kubectl delete pod todo-frontend -n prod
kubectl apply -f /vagrant/k8s/frontend/pod.yaml
kubectl get pods -n prod
```

> Le fichier `k8s/frontend/pod.yaml` a été mis à jour pour utiliser le tag `:v2`.

---

## 7. Vérification finale

Accéder à l'application depuis le navigateur du PC Windows :

```
http://192.168.56.11:30000
```
ou
```
http://192.168.56.12:30000
```

L'application doit charger, afficher les tâches existantes, et permettre d'en ajouter/supprimer.

---

## Résumé de l'architecture finale

```
Navigateur (PC Windows)
    │
    │ HTTP :30000
    ▼
todo-frontend-svc (NodePort)
    │
    ▼
Pod frontend (port 3000)
    │ proxy /api/*
    │ DNS interne Kubernetes
    ▼
todo-backend-svc (ClusterIP :3001)
    │
    ▼
Pod backend (port 3001)
    │
    │ DNS interne Kubernetes
    ▼
todo-database-svc (ClusterIP :3306)
    │
    ▼
Pod database MariaDB (port 3306)
```
