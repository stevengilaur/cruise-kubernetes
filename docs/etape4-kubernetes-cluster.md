# Étape 4 — Mise en place du cluster Kubernetes

## Objectif
Initialiser un cluster Kubernetes avec 1 master et 2 workers en utilisant `kubeadm`.
Installer le plugin réseau Calico (CNI) pour la communication entre pods.

---

## Prérequis
- Les 3 VMs démarrées : `k8s-master` (10), `k8s-worker1` (11), `k8s-worker2` (12)
- Vagrant installé sur le PC

---

## 1. Démarrer les VMs

Depuis le dossier du projet sur le PC Windows (Git Bash) :

```bash
vagrant up
```

Vérifier que les 3 VMs sont bien démarrées :
```bash
vagrant status
# k8s-master   running
# k8s-worker1  running
# k8s-worker2  running
```

---

## 2. Installation des outils Kubernetes (sur les 3 nœuds)

Ouvrir **3 terminaux** et se connecter à chaque VM :

```bash
# Terminal 1
vagrant ssh k8s-master

# Terminal 2
vagrant ssh k8s-worker1

# Terminal 3
vagrant ssh k8s-worker2
```

Sur **chaque nœud** (master + worker1 + worker2), exécuter :

> **Note :** Le Vagrantfile provisionne déjà `containerd` automatiquement au démarrage des VMs.
> Le swap, les modules kernel et la configuration containerd sont gérés par Ubuntu 22.04 + le provisioning.
> Il suffit donc d'installer `kubeadm`, `kubelet` et `kubectl`.

### 2.1 Installer kubeadm, kubelet, kubectl

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable kubelet
```

Vérifier que kubelet est actif :
```bash
sudo systemctl status kubelet
```

---

## 3. Initialisation du cluster (sur le master uniquement)

Se connecter au master :
```bash
vagrant ssh k8s-master
```

Initialiser le cluster :
```bash
sudo kubeadm init \
  --apiserver-advertise-address=192.168.56.10 \
  --pod-network-cidr=10.244.0.0/16
```

> **Important :** noter la commande `kubeadm join` affichée à la fin du résultat — elle sera utilisée pour connecter les workers.

Configurer kubectl pour l'utilisateur vagrant :
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Vérifier que le master est bien initialisé :
```bash
kubectl get nodes
# NAME         STATUS     ROLES           AGE
# k8s-master   NotReady   control-plane   1m
```

Le statut `NotReady` est normal — le réseau CNI n'est pas encore installé.

---

## 4. Installation du réseau Calico (sur le master)

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
```

Attendre que Calico soit prêt (environ 1-2 minutes) :
```bash
kubectl get pods -n kube-system
# Tous les pods calico doivent être Running
```

Vérifier que le master passe en Ready :
```bash
kubectl get nodes
# NAME         STATUS   ROLES           AGE
# k8s-master   Ready    control-plane   3m
```

---

## 5. Joindre les workers au cluster

### Récupérer la commande join (si perdue)

Si la commande `kubeadm join` a été perdue, la régénérer depuis le master :

```bash
kubeadm token create --print-join-command
```

### Sur worker1 et worker2

Se connecter à chaque worker et exécuter la commande join (adapter avec les valeurs réelles) :

```bash
sudo kubeadm join 192.168.56.10:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

> Le token et le hash sont affichés par `kubeadm init` ou `kubeadm token create --print-join-command`.

### Vérifier depuis le master

```bash
kubectl get nodes
# NAME          STATUS   ROLES           AGE
# k8s-master    Ready    control-plane   5m
# k8s-worker1   Ready    <none>          2m
# k8s-worker2   Ready    <none>          1m
```

Les 3 nœuds doivent être `Ready`.

---

## 6. Problèmes courants

### Worker qui refuse de joindre (fichiers déjà existants)

Si un worker affiche une erreur du type `[ERROR FileAvailable]` :

```bash
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d
sudo systemctl restart kubelet
# Puis relancer la commande kubeadm join
```

### kubelet mort après reset

```bash
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d
sudo systemctl restart containerd
sudo systemctl restart kubelet
# Puis relancer la commande kubeadm join
```

### VM qui ne démarre pas / SSH timeout

Si une VM ne répond pas après un `vagrant up` :

```bash
vagrant reload k8s-worker2   # Redémarrer une VM spécifique
```

Si elle reste bloquée, la recréer :
```bash
vagrant destroy k8s-worker2 -f
vagrant up k8s-worker2
# Puis refaire les étapes 2 et 5 pour ce nœud
```

---

## Résumé de l'architecture

```
PC Windows (192.168.56.1)
│
├── k8s-master  (192.168.56.10) — control-plane, registry privée
├── k8s-worker1 (192.168.56.11) — worker node
└── k8s-worker2 (192.168.56.12) — worker node

Réseau pods    : 10.244.0.0/16 (Calico CNI)
Réseau services: 10.96.0.0/12
Réseau VMs     : 192.168.56.0/28
```
