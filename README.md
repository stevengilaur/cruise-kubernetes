# ISR-ORC4 - Projet Cruise

POC Kubernetes avec 1 master + 2 workers, application web front/back + base de donnees, et registry privee.

## Arborescence

- `frontend/` : code et image du frontend (base Alpine)
- `backend/` : code et image du backend Node.js (base Alpine)
- `database/` : image MariaDB custom (base Alpine)
- `k8s/` : manifests Kubernetes
- `registry/` : manifests de la registry privee
- `Vagrantfile` : provisionnement des 3 VMs

## Conformite images (sujet)

Les images applicatives sont construites a partir de `alpine` puis poussees dans la registry privee.

- `192.168.56.25:30500/frontend:v2`
- `192.168.56.25:30500/backend:v1`
- `192.168.56.25:30500/mariadb:v1`

## Build et push des images

Depuis la machine qui peut joindre la registry:

```bash
docker build -t 192.168.56.25:30500/frontend:v2 ./frontend
docker build -t 192.168.56.25:30500/backend:v1 ./backend
docker build -t 192.168.56.25:30500/mariadb:v1 ./database

docker push 192.168.56.25:30500/frontend:v2
docker push 192.168.56.25:30500/backend:v1
docker push 192.168.56.25:30500/mariadb:v1
```

## Deploiement Kubernetes

```bash
kubectl apply -f k8s/namespaces/dev-namespace.yaml
kubectl apply -f k8s/namespaces/prod-namespace.yaml

kubectl apply -f k8s/database/mariadb-secret.yaml
kubectl apply -f k8s/database/mariadb-deployment.yaml
kubectl apply -f k8s/database/mariadb-service.yaml

kubectl apply -f k8s/backend/backend-configmap.yaml
kubectl apply -f k8s/backend/backend-deployment.yaml
kubectl apply -f k8s/backend/backend-service.yaml

kubectl apply -f k8s/frontend/frontend-deployment.yaml
kubectl apply -f k8s/frontend/frontend-service.yaml
```

## Verifications rapides

```bash
kubectl get ns
kubectl get pods -n dev -o wide
kubectl get svc -n dev
curl http://192.168.56.25:30009
curl http://192.168.56.25:30008
```

## Registry privee securisee (auth + TLS + imagePullSecret)

```bash
chmod +x registry/setup-security.sh
REGISTRY_USER=cruise REGISTRY_PASSWORD='ChangeMeNow!' ./registry/setup-security.sh

kubectl apply -f registry/registry-pv.yaml
kubectl apply -f registry/registry-pvc.yaml
kubectl apply -f registry/registry.yaml
kubectl apply -f registry/registry-service.yaml
```

Verifier:

```bash
kubectl get pods -n registry
kubectl get svc -n registry
```

Notes:
- Le secret `registry-pull-secret` est cree dans le namespace `dev`.
- Les Deployments app utilisent `imagePullSecrets` pour tirer depuis la registry privee.
- Sur chaque noeud Docker/containerd, ajouter le certificat TLS dans le trust store pour eviter les erreurs de certificat.
