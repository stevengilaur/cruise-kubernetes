# Étape 5 — Déploiement des Pods Kubernetes

## Objectif
Déployer les 3 pods de l'application (frontend, backend, database) dans le namespace `prod`
et configurer containerd sur tous les nœuds pour accéder à la registry privée.

---

## Prérequis
- Cluster Kubernetes opérationnel (Étape 4)
- Registry privée avec les 3 images (Étape 3)
- Se connecter au master : `vagrant ssh k8s-master`

---

## 1. Créer les namespaces

```bash
kubectl apply -f /vagrant/k8s/namespaces/namespaces.yaml
```

Vérifier :
```bash
kubectl get namespaces
# prod, dev, monitoring doivent apparaître
```

---

## 2. Créer le secret d'accès à la registry (regcred)

Ce secret permet aux workers de s'authentifier à la registry privée pour télécharger les images.

```bash
kubectl create secret docker-registry regcred \
  --docker-server=192.168.56.10:5000 \
  --docker-username=admin \
  --docker-password=adminpassword \
  --namespace=prod
```

Vérifier :
```bash
kubectl get secret regcred -n prod
```

---

## 3. Appliquer le ConfigMap et le Secret de la base de données

```bash
kubectl apply -f /vagrant/k8s/database/configmap.yaml
kubectl apply -f /vagrant/k8s/database/secret.yaml
```

Vérifier :
```bash
kubectl get configmap -n prod
kubectl get secret -n prod
```

---

## 4. Déployer les 3 pods

```bash
kubectl apply -f /vagrant/k8s/database/pod.yaml
kubectl apply -f /vagrant/k8s/backend/pod.yaml
kubectl apply -f /vagrant/k8s/frontend/pod.yaml
```

Vérifier le statut :
```bash
kubectl get pods -n prod
```

---

## 5. Problème : ImagePullBackOff (x509)

Les pods affichent `ImagePullBackOff`. La commande suivante révèle l'erreur exacte :

```bash
kubectl describe pod todo-database -n prod | tail -20
```

Erreur obtenue :
```
tls: failed to verify certificate: x509: certificate signed by unknown authority
```

### Explication

Notre registry privée utilise un certificat TLS auto-signé. `containerd` essaie de contacter
la registry en HTTPS et refuse le certificat non reconnu. Il faut configurer containerd sur
**chaque nœud du cluster** pour qu'il accepte cette registry en HTTP.

### Identifier sur quels nœuds tournent les pods

```bash
kubectl get pods -n prod -o wide
# Colonne NODE indique le nœud de chaque pod
```

---

## 6. Fix containerd — à faire sur les 3 nœuds (master, worker1, worker2)

Ouvrir **3 terminaux** depuis le PC Windows :

```bash
# Terminal 1
vagrant ssh k8s-master

# Terminal 2
vagrant ssh k8s-worker1

# Terminal 3
vagrant ssh k8s-worker2
```

Sur **chaque nœud**, exécuter dans l'ordre :

### 6.1 Créer le fichier hosts.toml

Ce fichier dit à containerd d'utiliser HTTP pour notre registry :

```bash
sudo mkdir -p /etc/containerd/certs.d/192.168.56.10:5000

sudo tee /etc/containerd/certs.d/192.168.56.10:5000/hosts.toml <<EOF
server = "http://192.168.56.10:5000"

[host."http://192.168.56.10:5000"]
  capabilities = ["pull", "resolve"]
  skip_verify = true
EOF
```

### 6.2 Activer la lecture du dossier certs.d

Par défaut, containerd ne lit pas le dossier `certs.d`. La ligne `config_path` dans
`/etc/containerd/config.toml` est vide — il faut la remplir :

```bash
sudo sed -i "s|config_path = ''|config_path = '/etc/containerd/certs.d'|g" /etc/containerd/config.toml
```

Vérifier que la modification est appliquée :
```bash
sudo grep "config_path" /etc/containerd/config.toml
# Doit afficher : config_path = '/etc/containerd/certs.d'
```

### 6.3 Redémarrer containerd

```bash
sudo systemctl restart containerd
```

> Répéter les étapes 6.1, 6.2 et 6.3 sur les 3 nœuds avant de continuer.

---

## 7. Recréer les pods après le fix

Revenir sur le master et supprimer les pods en erreur :

```bash
kubectl delete pod todo-database todo-backend todo-frontend -n prod
```

Les recréer :
```bash
kubectl apply -f /vagrant/k8s/database/pod.yaml
kubectl apply -f /vagrant/k8s/backend/pod.yaml
kubectl apply -f /vagrant/k8s/frontend/pod.yaml
```

Surveiller le démarrage :
```bash
kubectl get pods -n prod
```

Résultat attendu (au bout de 1-2 minutes) :
```
NAME            READY   STATUS    RESTARTS
todo-backend    1/1     Running   0
todo-database   1/1     Running   0
todo-frontend   1/1     Running   0
```

---

## 8. Vérification des logs

```bash
# Database — doit afficher "ready for connections"
kubectl logs todo-database -n prod

# Frontend — doit afficher "Frontend démarré sur le port 3000"
kubectl logs todo-frontend -n prod

# Backend — affiche des tentatives de connexion MySQL (normal sans Service)
kubectl logs todo-backend -n prod
```

---

## 9. Pourquoi le backend reste 0/1

Le pod `todo-backend` peut afficher `0/1 Running` même après le fix. C'est normal :
le backend essaie de se connecter à MySQL via le nom DNS `todo-database-svc` qui n'existe
pas encore. Ce nom sera résolu quand le **Service Kubernetes** sera créé à l'Étape 6.

Les logs confirment :
```
Tentative 1/10 — MySQL pas encore prêt, retry dans 3s...
```

Le backend est codé avec une logique de retry — il se reconnectera automatiquement
dès que le Service sera en place.

---

## Résumé des fichiers manifests

| Fichier | Rôle |
|---|---|
| `k8s/namespaces/namespaces.yaml` | Crée les namespaces prod, dev, monitoring |
| `k8s/database/configmap.yaml` | Variables non-sensibles (DB_NAME, DB_PORT) |
| `k8s/database/secret.yaml` | Variables sensibles encodées en base64 (passwords) |
| `k8s/database/pod.yaml` | Pod MariaDB avec probes liveness/readiness |
| `k8s/backend/pod.yaml` | Pod API Node.js avec probes liveness/readiness |
| `k8s/frontend/pod.yaml` | Pod Frontend Node.js avec probes liveness/readiness |
