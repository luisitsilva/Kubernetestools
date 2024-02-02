#!/usr/bin/env bash

# execPaths and configPaths
containerdpath="/etc/containerd"
containerdconf="/etc/containerd/config.toml"
usrlocalfolder="/usr/local"
kubeconf="/etc/kubernetes/admin.conf"
runcpath="/usr/local/sbin/runc"


# Check if containerd is installed
if [ -d $containerdpath ]; then
        echo "The containerd folder have been found on this system."
        echo "Containerd is installed at $containerdconf"
else
        echo "Containerd is not installed on this system. In order to join this server as a worker node to a k8s cluster, a CRI must be installed."
        echo "Shall we proceed with installed the latest version of containerd?"
        read contdinstall
        case $contdinstall in
          "Yes" | "YEs" | "YES" | "yES" | "yEs" | "yes" | "Y" | "y")
             echo "Starting containerd deployment process"
             echo "Updating required OS utils"
             yum install -y yum-utils
             echo "Registering source repo for containerd binaries retrieval"
             yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
             echo "Installing containerd"
             yum install containerd.io
             echo "Enabling containerd"
             systemctl enable containerd
             echo "Startingcontainerd"
             systemctl start containerd
             echo "Containerd new status:"
             systemctl status containerd
             ;;
          "No" | "NO" | "nO" | "no" | "n" | "N" )
             echo "Skipping containerd installation"
             ;;
        esac
fi

# Resetting containerd configuration
if [ -d $containerdconf ]; then
        echo "A containerd configuration file have been found on this system."
        echo "When adding new nodes to a k8s cluster, containerd after installation needs to be reset."
        sleep 1s
        echo -e "Do you agree on resetting the actual containerd configuration before adding this node to the k8s cluster?"
        read containerdreset

        case $containerdreset in
          "Yes" | "YEs" | "YES" | "yES" | "yEs" | "yes" )
            echo "Generating a new containerd config.Please wait!"
            ## containerd config default > /etc/containerd/config.toml
            containerd config default > /etc/containerd/config.toml
            ;;
          "No" | "NO" | "nO" | "n" | "N" )
            echo "Skipping containerd reset!"
            echo "Pleae make sure that containerd configuration file is not the default."
            ;;
        esac
else
        echo "No containerd configuration file have been found on this system."
fi

# Disabling swap on the fly. Also disable swap on the boot
echo "Disabling swap"
swapoff -a

# use sed here to open /etc/fstab and comment the swap partition

# Enabling ipv4 forward
echo "Enabling ipv4 forwarding"
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.d/99-sysctl.conf

# Configuring permissive mode on SELinux
echo "Configuring SELinux permissive mode"
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Installing kubeadm tools.
# Register the Kubernetes yum repository
echo"Registering the Kubernetes yum repository"
sleep 1s
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
exclude=kubelet kubectl cri-tools kubernetes-cni
EOF

echo "Installing K8S tools: kubelet kubeadm and kubectl!"
yum install -y kubelet kubectl kubeadm --disableexcludes=kubernetes

echo "Enabling K8S tools: kubelet kubeadm and kubectl!"
systemctl enable --now kubelet

echo ""
echo "Which role is to be applied to this server? ( 1 - Master | 2 - Worker )"
read roleserver
echo ""
echo ""
case $roleserver in
   "1" | "Master" | "M" | "master" | "m" )
       echo "Applying firewall rules to enable the Master role on this server."
       echo ""
       echo "Allowing traffic from any source towards the Kubernetes API service"
       firewall-cmd --add-port=6443/tcp --permanent
       sleep 1s
       echo "Allowing traffic from the kube-apiserver and etc to the etc server client API"
       sleep 1s
       firewall-cmd --add-port=2379-2380/tcp --permanent
       echo "Allowing traffic from localhost to the Kubelet API service"
       sleep 1s
       firewall-cmd --add-port=10250/tcp --permanent
       echo "Allowing traffic from localhost to the Kube-scheduler service"
       sleep 1s
       firewall-cmd --add-port=10259/tcp
       echo "Allowing traffic from localhost to the Kube-controller-manager service"
       firewall-cmd --add-port=10257/tcp --permanent
       ;;
   "2" | "Worker" | "worker" | "w" )
       echo "Applying firewall rules to enable the Worner role on this server."
       echo ""
       echo "Allowing traffic from localhost and the Kubernetes Control Plane to the Kubelet API service"
       sleep 1s
       firewall-cmd --add-port=10250/tcp --permanent
       echo "Allowing traffic from any node to the NodePort on the worker node"
       sleep 1s
       firewall-cmd --add-port=30000-32757/tcp --permanent
       ;;
esac

# Configure the firewall to allow the below
