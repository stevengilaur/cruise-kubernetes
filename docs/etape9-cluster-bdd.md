# Étape 9 — Cluster de Base de Données (StatefulSet + Réplication)

## Objectif
Remplacer le Deployment MySQL par un StatefulSet avec 2 pods en réplication
primary/replica. Les données sont persistées sur des volumes dédiés par pod.

---

## Différence Deployment vs StatefulSet

| Deployment | StatefulSet |
|---|---|
| Noms de pods aléatoires | Noms stables : `db-0`, `db-1`, `db-2`... |
| Un seul PVC partagé | Un PVC par pod (volumeClaimTemplates) |
| Tous les pods identiques | Chaque pod a une identité unique |
| Démarrage simultané | Démarrage en ordre (0 → 1 → 2) |
| Adapté aux apps sans état | Adapté aux bases de données |

---

## Architecture mise en place

```
todo-database-0 (primary)        todo-database-1 (replica)
  server-id=1                       server-id=2
  log-bin=mysql-bin (ON)            relay-log=relay-bin
  écritures + lectures              lecture seule (read-only)
  PVC → /data/mysql-0 (worker1)     PVC → /data/mysql-1 (worker2)
        ↓ réplication binaire ↑
```

---

## Prérequis

Créer les dossiers sur les nœuds workers :

```bash
vagrant ssh k8s-worker1
sudo mkdir -p /data/mysql-0
exit

vagrant ssh k8s-worker2
sudo mkdir -p /data/mysql-1
exit
```

---

## 1. Supprimer l'ancien Deployment et ses volumes

```bash
kubectl delete deployment todo-database -n prod
kubectl delete pvc mysql-pvc -n prod
kubectl delete pv mysql-pv
```

---

## 2. Créer les PersistentVolumes (un par worker)

```bash
kubectl apply -f /vagrant/k8s/database/pv-statefulset.yaml
```

Vérifier :
```bash
kubectl get pv
# mysql-pv-0 et mysql-pv-1 doivent être Available
```

---

## 3. Créer le Service Headless

Le Service Headless donne un nom DNS stable à chaque pod :
- `todo-database-0.todo-database-headless.prod.svc.cluster.local`
- `todo-database-1.todo-database-headless.prod.svc.cluster.local`

```bash
kubectl apply -f /vagrant/k8s/database/service-headless.yaml
```

---

## 4. Déployer le StatefulSet

```bash
kubectl apply -f /vagrant/k8s/database/statefulset.yaml
kubectl get pods -n prod -w
```

Les pods démarrent dans l'ordre — `todo-database-0` démarre et passe `1/1`
**avant** que `todo-database-1` commence à démarrer.

---

## 5. Configurer la réplication

### Vérifier que le binary logging est actif sur le primary

```bash
kubectl exec -it todo-database-0 -n prod -- mysql -u root -prootpassword -e "SHOW VARIABLES LIKE 'log_bin'; SHOW MASTER STATUS;"
```

Résultat attendu :
```
log_bin = ON
File: mysql-bin.000001 | Position: 328
```

### Configurer le replica

Adapter `MASTER_LOG_FILE` et `MASTER_LOG_POS` avec les valeurs de `SHOW MASTER STATUS` :

```bash
kubectl exec -it todo-database-1 -n prod -- mysql -u root -prootpassword -e "CHANGE MASTER TO MASTER_HOST='todo-database-0.todo-database-headless.prod.svc.cluster.local', MASTER_USER='replicator', MASTER_PASSWORD='replicatorpassword', MASTER_LOG_FILE='mysql-bin.000001', MASTER_LOG_POS=328; START SLAVE;"
```

### Vérifier la réplication

```bash
kubectl exec -it todo-database-1 -n prod -- mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master"
```

Résultat attendu :
```
Slave_IO_Running: Yes
Slave_SQL_Running: Yes
Seconds_Behind_Master: 0
```

---

## 6. Test de la réplication

Écrire sur le primary et vérifier que le replica reçoit la donnée :

```bash
# Insérer sur le primary
kubectl exec -it todo-database-0 -n prod -- mysql -u root -prootpassword -e "USE tododb; INSERT INTO todos (title) VALUES ('Test replication');"

# Vérifier sur le replica
kubectl exec -it todo-database-1 -n prod -- mysql -u root -prootpassword -e "USE tododb; SELECT * FROM todos;"
```

La ligne insérée sur `todo-database-0` doit apparaître sur `todo-database-1`.

---

## Explication de l'entrypoint

Le script `database/entrypoint.sh` détecte automatiquement le rôle du pod
grâce à la variable `$HOSTNAME` (ex: `todo-database-0`) :

```bash
POD_INDEX=${HOSTNAME##*-}  # extrait "0" ou "1"

if [ "$POD_INDEX" = "0" ]; then
  # Primary : active le binary logging
  EXTRA_FLAGS="--log-bin=mysql-bin --binlog-format=ROW --server-id=1"
else
  # Replica : server-id différent, read-only
  EXTRA_FLAGS="--server-id=2 --relay-log=relay-bin --read-only=1"
fi
```

---

## Résumé des fichiers créés

| Fichier | Rôle |
|---|---|
| `k8s/database/pv-statefulset.yaml` | 2 PVs (un par worker) |
| `k8s/database/service-headless.yaml` | DNS stable pour les pods |
| `k8s/database/statefulset.yaml` | StatefulSet avec 2 réplicas et volumeClaimTemplates |
| `database/entrypoint.sh` | Détection primary/replica + binary logging |
