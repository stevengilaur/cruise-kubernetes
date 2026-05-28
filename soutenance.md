# Commandes de Soutenance - Projet Cruise Kubernetes

## 1. Vérifier le cluster et les nœuds
```bash
kubectl get nodes
kubectl get pods -A -o wide
kubectl get ns
```

## 2. Tester la registry privée
```bash
kubectl get pods -n registry
kubectl get svc -n registry
# Tester l’accès à la registry (depuis une VM) :
curl -k https://192.168.56.25:30500/v2/_catalog
```

## 3. Vérifier les namespaces
```bash
kubectl get ns
kubectl get all -n dev
kubectl get all -n prod
```

## 4. Tester la base de données (MariaDB)
```bash
kubectl get pods -n dev -l app=mariadb
kubectl get pvc -n dev
kubectl exec -n dev -it <mariadb-pod-name> -- mysql -u root -p
```

## 5. Tester le backend
```bash
kubectl get pods -n dev -l app=backend
kubectl get svc -n dev | grep backend
curl http://192.168.56.25:30008
```

## 6. Tester le frontend
```bash
kubectl get pods -n dev -l app=frontend
kubectl get svc -n dev | grep frontend
curl http://192.168.56.25:30009
```

## 7. Tester la persistance (PVC/PV)
```bash
kubectl get pvc -n dev
kubectl get pv
```

## 8. Tester le cluster BDD (StatefulSet)
```bash
kubectl get statefulset -n dev
kubectl get pods -n dev -l app=mariadb
```

## 9. Vérifier le monitoring (Prometheus & Grafana)
```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
# Accès web :
# Prometheus : http://192.168.56.25:30090
# Grafana    : http://192.168.56.25:30300 (admin/admin123)
```

## 10. Tester l’automatisation Ansible (bonus)
```bash
cd ansible
./deploy.sh
# ou
ansible-playbook -i inventory.ini site.yml -v
```
