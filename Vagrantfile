Vagrant.configure("2") do |config|

  config.vm.box = "ubuntu/jammy64"
  config.vm.box_check_update = false

  config.ssh.insert_key = true

  network_prefix = "192.168.56"

  nodes = {
    "master"  => "#{network_prefix}.25",
    "worker1" => "#{network_prefix}.26",
    "worker2" => "#{network_prefix}.27"
  }

  nodes.each do |name, ip|

    config.vm.define name do |node|

      node.vm.hostname = name
      node.vm.network "private_network", ip: ip

      # SSH instant & stable
      node.ssh.username = "vagrant"
      node.ssh.insert_key = true
      node.ssh.keep_alive = true

      node.vm.provider "virtualbox" do |vb|
        vb.name = "k8s-#{name}"

        vb.memory = (name == "master") ? 3072 : 2048
        vb.cpus = 2

        vb.customize ["modifyvm", :id,
          "--natdnshostresolver1", "on",
          "--natdnsproxy1", "on"
        ]
      end

      # Préparation SSH + outils de base
      node.vm.provision "shell", inline: <<-SHELL
        apt-get update -y
        apt-get install -y openssh-server curl
        systemctl enable ssh
        systemctl start ssh
      SHELL

    end
  end
end