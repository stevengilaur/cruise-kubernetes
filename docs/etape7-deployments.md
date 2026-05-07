# Étape 7 — Deployments Kubernetes

## Objectif
Remplacer les pods créés manuellement par des Deployments qui gèrent automatiquement
le cycle de vie des pods : redémarrage en cas de crash, scalabilité, mises à jour progressives.

---

## Différence entre Pod et Deployment

| Pod manuel | Deployment |
|---|---|
| Si le pod crash, il disparaît | Kubernetes recrée le pod automatiquement |
| 1 seul pod | Nombre de réplicas configurable |
| Mise à jour = suppression + recréation | Mise à jour progressive sans coupure |

---

## Prérequis
- Services créés (Étape 6)
- Se connecter au master : `vagrant ssh k8s-master`

---

## 1. Supprimer les pods manuels

```bash
kubectl delete pod todo-frontend todo-backend todo-database -n prod
```

---

## 2. Appliquer les Deployments

```bash
kubectl apply -f /vagrant/k8s/database/deployment.yaml
kubectl apply -f /vagrant/k8s/backend/deployment.yaml
kubectl apply -f /vagrant/k8s/frontend/deployment.yaml
```

---

## 3. Vérifier

```bash
kubectl get deployments -n prod
kubectl get pods -n prod
```

Résultat attendu :
```
NAME            READY   UP-TO-DATE   AVAILABLE
todo-backend    2/2     2            2
todo-database   1/1     1            1
todo-frontend   2/2     2            2
```

- **frontend** et **backend** : 2 réplicas (haute disponibilité)
- **database** : 1 réplica (plusieurs instances MySQL en parallèle causerait des conflits — voir Étape IX)

---

## Résumé des choix

| Deployment | Réplicas | Stratégie | Raison |
|---|---|---|---|
| todo-frontend | 2 | RollingUpdate | Sans état, scalable |
| todo-backend | 2 | RollingUpdate | Sans état, scalable |
| todo-database | 1 | Recreate | Base de données, pas de multi-écriture |

La stratégie `Recreate` pour la database signifie que Kubernetes arrête l'ancien pod
avant d'en démarrer un nouveau — évite deux instances MySQL en écriture simultanée.
