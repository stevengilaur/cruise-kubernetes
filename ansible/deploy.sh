#!/bin/bash

# Ansible Deployment Helper Script for Cruise Kubernetes Project

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ANSIBLE_DIR="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Ansible
    if ! command -v ansible &> /dev/null; then
        print_error "Ansible is not installed"
        echo "Install with: pip install ansible"
        exit 1
    fi
    print_success "Ansible installed: $(ansible --version | head -1)"
    
    # Check SSH key
    if [ ! -f ~/.ssh/vagrant_key ]; then
        print_warning "SSH key not found at ~/.ssh/vagrant_key"
        print_warning "Copying from Vagrant..."
        cp ~/.vagrant.d/insecure_private_key ~/.ssh/vagrant_key
        chmod 600 ~/.ssh/vagrant_key
        print_success "SSH key copied"
    else
        print_success "SSH key found"
    fi
    
    # Test connectivity
    print_warning "Testing SSH connectivity..."
    cd "$ANSIBLE_DIR"
    
    if ansible all -i inventory.ini -m ping -q 2>/dev/null; then
        print_success "All hosts are reachable"
    else
        print_error "Cannot reach all hosts. Check your network and VMs."
        exit 1
    fi
}

deploy_full() {
    print_header "Full Kubernetes Cluster Deployment"
    echo "This will deploy the entire cluster including:"
    echo "  - Docker on all nodes"
    echo "  - Kubernetes control plane on master"
    echo "  - Kubernetes workers"
    echo "  - All applications (frontend, backend, database)"
    echo "  - Monitoring (Prometheus + Grafana)"
    echo ""
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd "$ANSIBLE_DIR"
        ansible-playbook -i inventory.ini site.yml -v
        print_success "Deployment complete!"
        print_header "Services Available"
        echo "Frontend:   http://192.168.56.25:30009"
        echo "Backend:    http://192.168.56.25:30008"
        echo "Grafana:    http://192.168.56.25:30300 (admin/admin123)"
        echo "Prometheus: http://192.168.56.25:30090"
    else
        print_warning "Deployment cancelled"
    fi
}

deploy_prepare() {
    print_header "Prepare Nodes for Kubernetes"
    cd "$ANSIBLE_DIR"
    ansible-playbook -i inventory.ini site.yml -v -l all_nodes --tags "prepare"
    print_success "Preparation complete!"
}

deploy_master() {
    print_header "Initialize Kubernetes Master"
    cd "$ANSIBLE_DIR"
    ansible-playbook -i inventory.ini site.yml -v -l masters --tags "master"
    print_success "Master initialization complete!"
}

deploy_workers() {
    print_header "Join Workers to Cluster"
    cd "$ANSIBLE_DIR"
    ansible-playbook -i inventory.ini site.yml -v -l workers --tags "workers"
    print_success "Workers joined!"
}

deploy_apps() {
    print_header "Deploy Applications"
    cd "$ANSIBLE_DIR"
    ansible-playbook -i inventory.ini site.yml -v -l masters --tags "deploy"
    print_success "Applications deployed!"
}

check_status() {
    print_header "Cluster Status"
    cd "$ANSIBLE_DIR"
    
    echo "Getting cluster info..."
    ansible masters -i inventory.ini -m shell -a "kubectl get nodes" 2>/dev/null | grep -A 100 "NAME"
    
    echo ""
    echo "Getting pods..."
    ansible masters -i inventory.ini -m shell -a "kubectl get pods -A" 2>/dev/null | grep -A 100 "NAMESPACE"
}

verify_deployment() {
    print_header "Verifying Deployment"
    
    MASTER_IP="192.168.56.25"
    
    echo "Testing service connectivity..."
    
    echo -n "Frontend (http://$MASTER_IP:30009): "
    if curl -s -o /dev/null -w "%{http_code}" "http://$MASTER_IP:30009" 2>/dev/null | grep -q "200"; then
        print_success "Online"
    else
        print_warning "Not responding"
    fi
    
    echo -n "Backend (http://$MASTER_IP:30008): "
    if curl -s -o /dev/null -w "%{http_code}" "http://$MASTER_IP:30008" 2>/dev/null | grep -q "200\|404"; then
        print_success "Online"
    else
        print_warning "Not responding"
    fi
    
    echo -n "Prometheus (http://$MASTER_IP:30090): "
    if curl -s -o /dev/null -w "%{http_code}" "http://$MASTER_IP:30090" 2>/dev/null | grep -q "200"; then
        print_success "Online"
    else
        print_warning "Not responding"
    fi
    
    echo -n "Grafana (http://$MASTER_IP:30300): "
    if curl -s -o /dev/null -w "%{http_code}" "http://$MASTER_IP:30300" 2>/dev/null | grep -q "200\|302"; then
        print_success "Online"
    else
        print_warning "Not responding"
    fi
}

show_menu() {
    print_header "Cruise Kubernetes - Ansible Deployment Tool"
    echo ""
    echo "1) Full deployment (all steps)"
    echo "2) Prepare nodes only"
    echo "3) Initialize master only"
    echo "4) Join workers only"
    echo "5) Deploy applications only"
    echo "6) Check cluster status"
    echo "7) Verify services"
    echo "8) Exit"
    echo ""
    read -p "Select option (1-8): " choice
}

# Main script
main() {
    if [ $# -eq 0 ]; then
        # Interactive mode
        check_prerequisites
        
        while true; do
            show_menu
            
            case $choice in
                1) deploy_full ;;
                2) deploy_prepare ;;
                3) deploy_master ;;
                4) deploy_workers ;;
                5) deploy_apps ;;
                6) check_status ;;
                7) verify_deployment ;;
                8) print_warning "Exiting"; exit 0 ;;
                *) print_error "Invalid option" ;;
            esac
            
            echo ""
            read -p "Press Enter to continue..."
        done
    else
        # Command mode
        check_prerequisites
        
        case "$1" in
            full) deploy_full ;;
            prepare) deploy_prepare ;;
            master) deploy_master ;;
            workers) deploy_workers ;;
            apps) deploy_apps ;;
            status) check_status ;;
            verify) verify_deployment ;;
            help) 
                echo "Usage: $0 [command]"
                echo ""
                echo "Commands:"
                echo "  full      - Deploy entire cluster"
                echo "  prepare   - Prepare nodes for Kubernetes"
                echo "  master    - Initialize master"
                echo "  workers   - Join workers"
                echo "  apps      - Deploy applications"
                echo "  status    - Check cluster status"
                echo "  verify    - Verify services"
                echo "  help      - Show this help"
                ;;
            *)
                print_error "Unknown command: $1"
                echo "Run: $0 help"
                exit 1
                ;;
        esac
    fi
}

# Run main
main "$@"
