# Ansible Automation for Kubernetes Cluster Deployment

This directory contains Ansible playbooks to fully automate the deployment of the Cruise Kubernetes project.

## Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── inventory.ini            # Hosts inventory
├── site.yml                 # Main playbook
└── roles/
    ├── kubernetes-prepare   # Install Docker, kubeadm, kubectl
    ├── kubernetes-master    # Initialize Kubernetes master
    ├── kubernetes-worker    # Join workers to cluster
    └── deploy-kubernetes    # Deploy applications and services
```

## Prerequisites

1. **On your local machine (control node):**
   - Ansible >= 2.9
   - SSH access to all VMs
   - `ansible-inventory` tool available

2. **Vagrant VMs must be running:**
   ```bash
   vagrant up
   ```

3. **SSH key configuration:**
   ```bash
   # Copy your Vagrant SSH key
   cp ~/.vagrant.d/insecure_private_key ~/.ssh/vagrant_key
   chmod 600 ~/.ssh/vagrant_key
   ```

## Pre-flight Checks

1. **Test SSH connectivity:**
   ```bash
   cd ansible/
   ansible all -i inventory.ini -m ping
   ```

2. **List inventory:**
   ```bash
   ansible-inventory -i inventory.ini --list
   ```

3. **Verify Python availability:**
   ```bash
   ansible all -i inventory.ini -m setup -a "filter=ansible_python_version"
   ```

## Deployment Steps

### Full Cluster Deployment (Recommended)

Deploy the entire cluster in one command:

```bash
cd ansible/
ansible-playbook -i inventory.ini site.yml -v
```

**Duration:** ~15-20 minutes for complete deployment

### Step-by-Step Deployment

If you prefer more control, deploy in phases:

```bash
cd ansible/

# 1. Prepare all nodes (install Docker, Kubernetes tools)
ansible-playbook -i inventory.ini site.yml -v --tags "kubernetes-prepare" -e "ansible_user=vagrant"

# 2. Initialize master
ansible-playbook -i inventory.ini site.yml -v --tags "kubernetes-master" -e "ansible_user=vagrant"

# 3. Join workers
ansible-playbook -i inventory.ini site.yml -v --tags "kubernetes-worker" -e "ansible_user=vagrant"

# 4. Deploy applications
ansible-playbook -i inventory.ini site.yml -v --tags "deploy-kubernetes" -e "ansible_user=vagrant"
```

## Playbook Roles

### 1. kubernetes-prepare
- Updates system packages
- Installs Docker Engine
- Installs Kubernetes components (kubeadm, kubectl, kubelet)
- Configures kernel modules and sysctl parameters
- Disables swap
- Sets up prerequisites for clustering

### 2. kubernetes-master
- Initializes Kubernetes control plane with kubeadm
- Copies kubeconfig for root and vagrant users
- Deploys Flannel CNI plugin for pod networking
- Generates worker join token
- Waits for cluster to be operational

### 3. kubernetes-worker
- Retrieves join token and certificate from master
- Joins worker nodes to cluster
- Verifies node is ready and communicating with master

### 4. deploy-kubernetes
- Creates namespaces (dev, prod, monitoring, registry)
- Deploys Docker Registry (private)
- Configures registry secrets for image pull
- Deploys MariaDB database
- Deploys backend service
- Deploys frontend service
- Sets up database cluster (StatefulSet)
- Deploys Prometheus monitoring
- Deploys Grafana visualization
- Verifies all components are ready

## Verification

### Check Cluster Health

```bash
# From any master node:
export KUBECONFIG=/root/.kube/config

# Get all nodes
kubectl get nodes

# Get all pods in dev namespace
kubectl get pods -n dev -o wide

# Check services
kubectl get svc -n dev

# Monitor services deployment
kubectl get deploy -n dev
```

### Test Application Access

```bash
# Test frontend
curl http://192.168.56.25:30009

# Test backend
curl http://192.168.56.25:30008

# Test monitoring
curl http://192.168.56.25:30090  # Prometheus
curl http://192.168.56.25:30300  # Grafana
```

### View Deployment Logs

```bash
# Check deployment status
kubectl describe deployment frontend -n dev

# View pod logs
kubectl logs -n dev deployment/frontend --tail=100

# Watch pod status
kubectl get pods -n dev -w
```

## Troubleshooting

### If kubeadm join fails on workers:

```bash
# SSH into master and generate a new token
ssh -i ~/.ssh/vagrant_key vagrant@192.168.56.25

# Create new join token
sudo kubeadm token create --print-join-command

# Then rerun worker playbook
ansible-playbook -i inventory.ini site.yml -v -l workers
```

### If pods are stuck in pending state:

```bash
# Check node status
kubectl describe nodes

# Check CNI plugin status
kubectl get daemonset -n kube-system

# Check Flannel pods
kubectl get pods -n kube-flannel
```

### If image pull fails:

```bash
# Verify secret exists
kubectl get secrets -n dev

# Check secret contents
kubectl describe secret regcred -n dev

# Retry deployment
kubectl rollout restart deployment frontend -n dev
```

### Check Ansible connectivity issues:

```bash
# Test ping
ansible all -i inventory.ini -m ping

# Run setup module to debug
ansible all -i inventory.ini -m setup -vvv

# Test SSH directly
ssh -i ~/.ssh/vagrant_key vagrant@192.168.56.25
```

## Advanced Usage

### Rerun specific role on specific hosts:

```bash
# Deploy on worker1 only
ansible-playbook -i inventory.ini site.yml -l worker1 -v

# Only prepare master for Kubernetes
ansible-playbook -i inventory.ini -i inventory.ini site.yml -l master -v
```

### Using dynamic inventory:

For production environments, you can use dynamic inventory:

```bash
ansible-playbook -i inventory/dynamic_inventory.py site.yml -v
```

### Idempotent deployments:

Most tasks are idempotent and can be safely re-run:

```bash
# Safe to rerun multiple times
ansible-playbook -i inventory.ini site.yml
```

## Security Considerations

1. **SSH Keys:** Ensure proper permissions on private keys
   ```bash
   chmod 600 ~/.ssh/vagrant_key
   ```

2. **Registry Credentials:** Current credentials in playbooks are defaults
   - **Change before production!**
   - Update in deploy-kubernetes role
   - Update in k8s/database/mariadb-secret.yaml

3. **Kubernetes RBAC:** Add role-based access controls for production

4. **Network policies:** Implement NetworkPolicies for security

## Performance Tips

- Run on local network (VMs on same host)
- Ensure sufficient VM resources (2 CPUs, 2GB RAM minimum per worker)
- Use SSD storage for better I/O performance

## Support and Maintenance

### Check Ansible version:
```bash
ansible --version
```

### Update inventory if IPs change:
Edit `inventory.ini` with new IP addresses

### Monitor cluster health:
```bash
# Watch nodes
watch kubectl get nodes

# Watch pods
watch kubectl get pods -n dev

# Monitor resource usage
kubectl top nodes
kubectl top pods -n dev
```

## Next Steps

1. Verify all applications are running
2. Test high availability by shutting down a worker
3. Test data persistence by deleting database pods
4. Implement additional monitoring dashboards in Grafana
5. Set up alerting rules in Prometheus

---

**Project:** ISR-ORC4 - Cruise Kubernetes Cluster
**Bonus:** Ansible Automation for Full Stack Deployment
