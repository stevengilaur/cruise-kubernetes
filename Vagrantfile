Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_check_update = false
  config.vm.boot_timeout = 600

  config.ssh.insert_key = false

  machines = [
    { name: "k8s-master",  ip: "192.168.56.10", memory: 2048, cpus: 2 },
    { name: "k8s-worker1", ip: "192.168.56.11", memory: 2048, cpus: 2 },
    { name: "k8s-worker2", ip: "192.168.56.12", memory: 2048, cpus: 2 },
  ]

  machines.each do |machine|
    config.vm.define machine[:name] do |node|
      node.vm.hostname = machine[:name]
      node.vm.network "private_network",
        ip: machine[:ip],
        netmask: "255.255.255.240"

      node.vm.provider "virtualbox" do |vb|
        vb.name   = machine[:name]
        vb.memory = machine[:memory]
        vb.cpus   = machine[:cpus]
      end

      node.vm.provision "shell", inline: <<-SHELL
        # Désactiver le service qui ralentit le boot SSH
        systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
        systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true

        # Désactiver le swap
        swapoff -a
        sed -i '/ swap / s/^/#/' /etc/fstab

        # Modules kernel requis par Kubernetes
        modprobe overlay
        modprobe br_netfilter
        cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
        cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
        sysctl --system

        # Installer containerd
        apt-get update -y
        apt-get install -y containerd curl apt-transport-https ca-certificates
        mkdir -p /etc/containerd
        containerd config default | tee /etc/containerd/config.toml
        sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
        systemctl restart containerd
        systemctl enable containerd
      SHELL
    end
  end
end
