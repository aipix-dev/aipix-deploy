#!/bin/bash

######################################
# Install Kubernetes Base Components #
######################################

# script_path=$(pwd)
scriptdir="$(dirname "$0")"
cd "$scriptdir"

if [ ! -f "./sources.sh" ]; then
	echo "Using ENV from sources.sh.sample"
	source ./sources.sh.sample
else
	echo "Using ENV from sources.sh"
	source ./sources.sh
	if [ -z "${SRC_K8S_VER}" ]; then
		echo >&2  "ERROR: File sources.sh does not contain K8S version variables. Copy system variables fom sources.sh.sample file."
		exit 2
	fi
fi


K8S_VER=${SRC_K8S_VER}
K8S_VER_PATCH=${SRC_K8S_VER_PATCH}
K8S_VER_BUILD=${SRC_K8S_VER_BUILD}
CONTAINERD_VER=${SRC_CONTAINERD_VER}
RUNC_VER=${SRC_RUNC_VER}
CALICO_VER=${SRC_CALICO_VER}

sudo swapoff -a
sudo sed -i '/^\/swap/s/^/#/' /etc/fstab

sudo apt update -y && sudo apt install -y apt-transport-https ca-certificates gnupg rsync curl ntp net-tools lvm2 ioping
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod a+x /usr/local/bin/yq

curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VER}/deb/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VER}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update -y
sudo apt install -y kubelet=${K8S_VER}.${K8S_VER_PATCH}-${K8S_VER_BUILD} \
					kubeadm=${K8S_VER}.${K8S_VER_PATCH}-${K8S_VER_BUILD} \
					kubectl=${K8S_VER}.${K8S_VER_PATCH}-${K8S_VER_BUILD}
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

cat <<EOF | sudo tee /etc/sysctl.d/99-inotify.conf
fs.inotify.max_user_instances = 8192
EOF

# Apply sysctl params without reboot
sudo sysctl --system

#containerd --version
echo "Starting containerd v${CONTAINERD_VER} installation"
sudo curl -L https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VER}/containerd-${CONTAINERD_VER}-linux-amd64.tar.gz -o containerd-${CONTAINERD_VER}-linux-amd64.tar.gz

sudo tar Cxzvf /usr/local containerd-${CONTAINERD_VER}-linux-amd64.tar.gz
sudo rm containerd-${CONTAINERD_VER}-linux-amd64.tar.gz

CONFIG_FILE="/etc/containerd/config.toml"
TARGET_LINE_1="\[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options\]"
TARGET_LINE_2="\[plugins.'io.containerd.grpc.v1.cri'\]"

sudo mkdir -p /etc/containerd/certs.d
sudo sh -c "containerd config default > ${CONFIG_FILE}"

if sudo grep  "SystemdCgroup =" $CONFIG_FILE >/dev/null 2>&1; then
    echo "Seting existing SystemdCgroup in /etc/containerd/config.toml to true"
    sudo sed -i 's/SystemdCgroup =.*/SystemdCgroup = true/' ${CONFIG_FILE}
elif
    sudo grep -q "$TARGET_LINE_1" $CONFIG_FILE >/dev/null 2>&1 ; then
    echo "Adding SystemdCgroup in /etc/containerd/config.toml and seting to true"
    sudo sed -i "/${TARGET_LINE_1}/a\            SystemdCgroup = true" ${CONFIG_FILE}
else
    echo "Error: Unable to configure SystemdCgroup in /etc/containerd/config.toml: Target line not found"
    exit 2
fi

if sudo grep  "sandbox_image =" $CONFIG_FILE >/dev/null 2>&1; then
    echo "Seting existing sandbox_image in /etc/containerd/config.toml to new value"
    sudo sed -i "s/sandbox_image =.*/sandbox_image = 'registry.k8s.io\/pause:3.10'/" ${CONFIG_FILE}
elif
    sudo grep -q "$TARGET_LINE_2" $CONFIG_FILE >/dev/null 2>&1 ; then
    echo "Adding sandbox_image in /etc/containerd/config.toml and seting value"
    sudo sed -i "/${TARGET_LINE_2}/a\    sandbox_image = 'registry.k8s.io/pause:3.10'" ${CONFIG_FILE}
else
    echo "Error: Unable to configure sandbox_image in /etc/containerd/config.toml: Target line not found"
    exit 2
fi

#Replace config_path in config.toml
if sudo grep '\[plugins\."io\.containerd\.grpc\.v1\.cri"\.registry\]' ${CONFIG_FILE} >/dev/null 2>&1; then
    sudo sed -i '/\[plugins\."io\.containerd\.grpc\.v1\.cri"\.registry\]/,/^$/s|config_path = ".*"|config_path = "/etc/containerd/certs.d"|' ${CONFIG_FILE}
elif
    sudo grep "\[plugins\.'io.containerd.cri.v1.images'\.registry\]" ${CONFIG_FILE} >/dev/null 2>&1; then
    sudo sed -i "/\[plugins\.'io.containerd.cri.v1.images'\.registry\]/,/^$/s|config_path = '.*'|config_path = '/etc/containerd/certs.d'|" ${CONFIG_FILE}
else
    echo "Error: Unable to configure config_path in /etc/containerd/config.toml: Target line not found"
    exit 2
fi

#Create containerd.service file
sudo curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /usr/lib/systemd/system/containerd.service
sudo mkdir -p /usr/lib/systemd/system/containerd.service.d
cat <<EOF | sudo tee /usr/lib/systemd/system/containerd.service.d/limits.conf
[Service]
LimitNOFILE=infinity
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now containerd
echo "Containerd v${CONTAINERD_VER} installed"

#runc --version
echo "Starting runc v${RUNC_VER} installation"
sudo curl -L https://github.com/opencontainers/runc/releases/download/v${RUNC_VER}/runc.amd64 -o runc.amd64

sudo install -m 755 runc.amd64 /usr/local/sbin/runc
sudo rm runc.amd64
echo "Runc v${RUNC_VER} installed"

#Install Calico control client for network plugin
echo "Starting calicoctl v${CALICO_VER} installation"
sudo curl -L https://github.com/projectcalico/calico/releases/download/v${CALICO_VER}/calicoctl-linux-amd64 -o /usr/local/bin/calicoctl
sudo chmod +x /usr/local/bin/calicoctl
echo "Calicoctl v${CALICO_VER} installed"

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
