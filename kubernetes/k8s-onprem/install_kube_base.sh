#!/bin/bash

#########################
# Install Kubernetes Base Components #
#########################

script_path=$(pwd)

scriptdir="$(dirname "$0")"
cd "$scriptdir"

sudo swapoff -a
sudo sed -i '/^\/swap/s/^/#/' /etc/fstab

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo apt install -y ntp net-tools lvm2 ioping

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list


sudo apt-get update
sudo apt-get install -y kubelet=1.28.10-1.1  kubeadm=1.28.10-1.1  kubectl=1.28.10-1.1
sudo apt-mark hold kubelet kubeadm kubectl

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

#containerd --version
sudo curl -L https://github.com/containerd/containerd/releases/download/v1.7.17/containerd-1.7.17-linux-amd64.tar.gz -o containerd-1.7.17-linux-amd64.tar.gz

sudo tar Cxzvf /usr/local containerd-1.7.17-linux-amd64.tar.gz
sudo rm containerd-1.7.17-linux-amd64.tar.gz

sudo mkdir /etc/containerd
sudo sh -c "containerd config default > /etc/containerd/config.toml"

sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo sed -i 's@sandbox_image =.*@sandbox_image = "registry.k8s.io/pause:3.9"@' /etc/containerd/config.toml

sudo curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /usr/lib/systemd/system/containerd.service

sudo systemctl daemon-reload
sudo systemctl enable --now containerd

#runc --version
sudo curl -L https://github.com/opencontainers/runc/releases/download/v1.1.12/runc.amd64 -o runc.amd64

sudo install -m 755 runc.amd64 /usr/local/sbin/runc
sudo rm runc.amd64

#Install network plugins
sudo curl -L https://github.com/containernetworking/plugins/releases/download/v1.5.0/cni-plugins-linux-amd64-v1.5.0.tgz -o cni-plugins-linux-amd64-v1.5.0.tgz
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.5.0.tgz
sudo rm cni-plugins-linux-amd64-v1.5.0.tgz

#Install Calico control client for network plugin
cd /usr/local/bin/
sudo curl -L https://github.com/projectcalico/calico/releases/download/v3.29.1/calicoctl-linux-amd64 -o calicoctl

sudo chmod +x calicoctl

#Define internal ip address
HOST_NETWORK=$1
if [[ -n "${HOST_NETWORK}" ]]; then
    K8S_INTERNAL_IP=$(ip route | grep "${HOST_NETWORK}" | awk '{print $9}')
    sudo sh -c "echo KUBELET_EXTRA_ARGS=--node-ip=${K8S_INTERNAL_IP} > /etc/default/kubelet"
    sudo systemctl restart kubelet
fi

echo "
Kubernetes base instalation is finished succesfuly
"
