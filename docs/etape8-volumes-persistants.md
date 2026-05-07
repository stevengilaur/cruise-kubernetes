# Étape 8 — Volumes Persistants

## Objectif
Persister les données de la base de données indépendamment du cycle de vie des pods.
Sans volume, toutes les données sont perdues à chaque redémarrage du pod MySQL.

---

## Concepts

- **PersistentVolume (PV)** : l'espace disque réservé sur un nœud (ex: 1Gi sur `/data/mysql` du worker)
- **PersistentVolumeClaim (PVC)** : la demande d'un pod pour utiliser cet espace
- **hostPath** : type de volume qui utilise un dossier du nœud hôte (adapté pour un cluster local)

```
Pod MySQL → PVC (mysql-pvc) → PV (mysql-pv) → /data/mysql sur k8s-worker2
```

---

## Prérequis
- Identifier sur quel nœud tourne le pod database :

```bash
kubectl get pods -n prod -o wide | grep database
# Colonne NODE indique le nœud (ex: k8s-worker2)
```

---

## 1. Créer le dossier sur le nœud hôte

Se connecter au nœud qui héberge la database (ex: worker2) et créer le dossier :

```bash
vagrant ssh k8s-worker2
sudo mkdir -p /data/mysql
exit
```

---

## 2. Appliquer le PV et le PVC

```bash
kubectl apply -f /vagrant/k8s/database/pv.yaml
kubectl apply -f /vagrant/k8s/database/pvc.yaml
```

Vérifier :
```bash
kubectl get pv
kubectl get pvc -n prod
```

Résultat attendu :
```
NAME       CAPACITY   STATUS   CLAIM
mysql-pv   1Gi        Bound    prod/mysql-pvc

NAME        STATUS   VOLUME     CAPACITY
mysql-pvc   Bound    mysql-pv   1Gi
```

Les deux doivent être en **Bound** — ils sont liés l'un à l'autre.

---

## 3. Mettre à jour le Deployment de la database

Le fichier `k8s/database/deployment.yaml` a été mis à jour pour monter le volume :

```yaml
volumeMounts:
  - name: mysql-storage
    mountPath: /var/lib/mysql

volumes:
  - name: mysql-storage
    persistentVolumeClaim:
      claimName: mysql-pvc
```

Appliquer :
```bash
kubectl apply -f /vagrant/k8s/database/deployment.yaml
kubectl get pods -n prod
```

---

## 4. Problème rencontré : CrashLoopBackOff après montage du volume

### Erreur
```
Access denied for user 'root'@'localhost' (using password: NO)
```

### Explication
MariaDB 10.11 sur Alpine utilise **unix_socket** par défaut pour l'authentification root.
Cela signifie que `mysql -u root` ne fonctionne que si le processus qui se connecte
tourne en tant que l'utilisateur Linux `root`. La phase de bootstrap du script
échouait à configurer le mot de passe root.

### Fix — `database/entrypoint.sh`
Ajout de `--skip-grant-tables` au démarrage bootstrap pour contourner l'authentification,
puis `FLUSH PRIVILEGES` avant l'`ALTER USER` :

```bash
# Bootstrap sans vérification des droits
mysqld --user=mysql --skip-networking --skip-grant-tables &

# Configurer root
mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF
```

Ajout d'un flag `FIRST_RUN` pour n'exécuter `init.sql` qu'à la première initialisation
(évite de réinsérer les données de test à chaque redémarrage du pod).

### Rebuild de l'image après le fix

Sur le PC Windows (Git Bash) :
```bash
# Vider le volume corrompu sur le nœud hôte
vagrant ssh k8s-worker2
sudo rm -rf /data/mysql/*
exit

# Rebuild et push
docker build -t 192.168.56.10:5000/todo-database:v2 ./database
docker push 192.168.56.10:5000/todo-database:v2
```

Le fichier `k8s/database/deployment.yaml` a été mis à jour pour utiliser le tag `:v2`.

---

## 5. Vérification — test de persistance

```bash
# Supprimer le pod pour simuler un crash
kubectl delete pod -l app=mysql -n prod

# Surveiller le redémarrage
kubectl get pods -n prod -w
```

Une fois le nouveau pod `1/1 Running`, rafraîchir l'application dans le navigateur :
les tâches ajoutées avant le crash doivent toujours être présentes.

---

## Résumé des fichiers créés

| Fichier | Rôle |
|---|---|
| `k8s/database/pv.yaml` | Réserve 1Gi sur `/data/mysql` du nœud worker |
| `k8s/database/pvc.yaml` | Demande d'utilisation du PV par le pod MySQL |
| `k8s/database/deployment.yaml` | Mis à jour avec volumeMount + image v2 |
| `database/entrypoint.sh` | Corrigé avec --skip-grant-tables + FIRST_RUN |
