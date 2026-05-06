# Checklist soutenance - Projet Cruise

## 1) Introduction (2 min)

- Objectif: cluster Kubernetes non-manage avec 1 master + 2 workers.
- Contraintes respectees: images custom, registry privee, separation des namespaces.
- Architecture: front, back, DB, registry, monitoring.

## 2) Demonstration technique (12 min)

- Montrer les namespaces:
  - `kubectl get ns`
- Montrer les workloads:
  - `kubectl get deploy,sts,pods -A`
- Montrer les services et la decouverte DNS:
  - `kubectl get svc -A`
- Montrer la registry privee:
  - pod + service + secret TLS/auth
- Montrer ConfigMap et Secrets:
  - `kubectl get configmap,secret -n dev`
- Montrer la persistance:
  - `kubectl get pvc,pv -A`
- Montrer le cluster DB StatefulSet:
  - `kubectl get sts -n dev`
- Montrer le monitoring:
  - Prometheus: `http://<MASTER_IP>:30090`
  - Grafana: `http://<MASTER_IP>:30300`

## 3) Scenario de resilience (4 min)

- Couper un worker (ou stopper kubelet/VM worker).
- Verifier que les services restent accessibles.
- Verifier que les pods se recreent sur un autre noeud.
- Verifier que les donnees DB persistent.

## 4) Questions / justification (2 min)

- Justifier le choix CNI, type de Service, et strategy de deploiement.
- Expliquer pourquoi registry privee + imagePullSecret.
- Expliquer les limites actuelles et ameliorations futures (HPA, Ingress, backup DB).
