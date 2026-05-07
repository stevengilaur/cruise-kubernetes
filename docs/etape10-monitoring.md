# Étape 10 — Monitoring (Prometheus + Grafana + Node Exporter)

## Objectif
Surveiller l'état du cluster Kubernetes et des applications en temps réel.
Toute la stack de monitoring est conteneurisée et déployée dans le namespace `monitoring`.

---

## Architecture

```
Navigateur (PC Windows)
    │
    ├── :30090 → Prometheus (collecte et stocke les métriques)
    └── :30030 → Grafana (visualisation des métriques)
                    │
                    └── interroge Prometheus via DNS interne
                            │
                            ├── node-exporter (worker1) :9100 — métriques système
                            ├── node-exporter (worker2) :9100 — métriques système
                            └── cAdvisor (kubelet) — métriques conteneurs
```

---

## Outils utilisés

| Outil | Rôle | Type de déploiement |
|---|---|---|
| **Prometheus** | Collecte et stocke les métriques (TSDB) | Deployment |
| **Node Exporter** | Expose les métriques système de chaque nœud (CPU, RAM, disque, réseau) | DaemonSet |
| **Grafana** | Visualisation des métriques via dashboards | Deployment |

Le **DaemonSet** est utilisé pour Node Exporter car il faut exactement **un pod par nœud**
pour collecter les métriques système. Kubernetes garantit cela automatiquement avec un DaemonSet.

---

## Prérequis
- Namespace `monitoring` créé (Étape 5)
- Se connecter au master : `vagrant ssh k8s-master`

---

## 1. Créer les permissions RBAC pour Prometheus

Prometheus a besoin de lire les métriques de l'API Kubernetes :

```bash
kubectl apply -f /vagrant/k8s/monitoring/prometheus-rbac.yaml
```

---

## 2. Appliquer la configuration Prometheus

```bash
kubectl apply -f /vagrant/k8s/monitoring/prometheus-configmap.yaml
```

La configuration (`prometheus.yml`) définit ce que Prometheus surveille :
- Lui-même (`localhost:9090`)
- Les 3 nœuds via Node Exporter (port 9100)
- Les conteneurs via cAdvisor (intégré dans kubelet)
- Les pods du namespace `prod`

---

## 3. Déployer Node Exporter (DaemonSet)

```bash
kubectl apply -f /vagrant/k8s/monitoring/node-exporter-daemonset.yaml
```

Kubernetes crée automatiquement **un pod Node Exporter par nœud worker**.
Il expose les métriques système sur le port `9100` de chaque nœud.

---

## 4. Déployer Prometheus

```bash
kubectl apply -f /vagrant/k8s/monitoring/prometheus-deployment.yaml
kubectl apply -f /vagrant/k8s/monitoring/prometheus-service.yaml
```

---

## 5. Déployer Grafana

```bash
kubectl apply -f /vagrant/k8s/monitoring/grafana-deployment.yaml
kubectl apply -f /vagrant/k8s/monitoring/grafana-service.yaml
```

---

## 6. Vérifier que tout tourne

```bash
kubectl get pods -n monitoring
```

Résultat attendu :
```
NAME                          READY   STATUS
grafana-xxx                   1/1     Running
node-exporter-xxx             1/1     Running   ← worker1
node-exporter-xxx             1/1     Running   ← worker2
prometheus-xxx                1/1     Running
```

---

## 7. Accéder aux interfaces

**Prometheus :**
```
http://192.168.56.11:30090
```

**Grafana :**
```
http://192.168.56.11:30030
```
Login : `admin` / `adminpassword`

---

## 8. Configurer Grafana

### Ajouter Prometheus comme source de données

1. Menu gauche → **Connections** → **Data sources**
2. **Add data source** → choisir **Prometheus**
3. URL : `http://prometheus-svc.monitoring.svc.cluster.local:9090`
4. **Save & test** → doit afficher "Successfully queried the Prometheus API"

### Importer le dashboard Node Exporter Full

1. Menu gauche → **Dashboards** → **Import**
2. Champ **Import via grafana.com** : `1860`
3. **Load** → sélectionner la source Prometheus → **Import**

Le dashboard affiche en temps réel :
- Utilisation CPU par nœud
- Utilisation RAM par nœud
- Utilisation disque
- Trafic réseau
- Charge système

---

## Résumé des fichiers créés

| Fichier | Rôle |
|---|---|
| `k8s/monitoring/prometheus-rbac.yaml` | ServiceAccount + ClusterRole + ClusterRoleBinding |
| `k8s/monitoring/prometheus-configmap.yaml` | Configuration des cibles à surveiller |
| `k8s/monitoring/prometheus-deployment.yaml` | Pod Prometheus |
| `k8s/monitoring/prometheus-service.yaml` | NodePort :30090 |
| `k8s/monitoring/node-exporter-daemonset.yaml` | Un pod par nœud pour les métriques système |
| `k8s/monitoring/grafana-deployment.yaml` | Pod Grafana |
| `k8s/monitoring/grafana-service.yaml` | NodePort :30030 |
