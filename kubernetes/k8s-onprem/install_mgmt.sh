#!/bin/bash

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
    echo >&2 "ERROR: File sources.sh does not contain K8S version variables. Copy system variables fom sources.sh.sample file."
    exit 2
  fi
fi

K8S_VER=${SRC_K8S_VER}
K8S_VER_PATCH=${SRC_K8S_VER_PATCH}
K8S_VER_BUILD=${SRC_K8S_VER_BUILD}
CALICO_VER=${SRC_CALICO_VER}

sudo swapoff -a
sudo sed -i '/^\/swap/s/^/#/' /etc/fstab

sudo apt update && sudo apt install -y apt-transport-https ca-certificates gnupg rsync curl net-tools jq mysql-client
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod a+x /usr/local/bin/yq

curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VER}/deb/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VER}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubectl=${K8S_VER}.${K8S_VER_PATCH}-${K8S_VER_BUILD}
sudo apt-mark hold kubectl

mkdir -p $HOME/.kube
echo 'source <(kubectl completion bash)' >>$HOME/.bashrc
echo 'alias k="kubectl"' >>$HOME/.bashrc
echo 'complete -F __start_kubectl k' >>$HOME/.bashrc

#Helm
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
sudo helm completion bash | sudo tee /etc/bash_completion.d/helm >/dev/null

#Install Calico control for network plugin
echo "Starting calicoctl v${CALICO_VER} installation"
sudo curl -L https://github.com/projectcalico/calico/releases/download/v${CALICO_VER}/calicoctl-linux-amd64 -o /usr/local/bin/calicoctl
sudo chmod +x /usr/local/bin/calicoctl
echo "Calicoctl v${CALICO_VER} installed"

#Delete midnight commander if installed
dpkg -s mc >/dev/null 2>&1
if [ $? = 0 ]; then
  echo "Removing midnight commander"
  sudo apt purge -y mc >/dev/null 2>&1
fi

#Install minio client
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/minio-binaries/mc
chmod +x $HOME/minio-binaries/mc
export PATH=$PATH:$HOME/minio-binaries/
echo 'export PATH=$PATH:$HOME/minio-binaries/' >>$HOME/.bashrc
mc alias ls
mc --autocompletion

echo "
Instalation is finished succesfuly
"
