#!/bin/bash

K8S_VER="1.32"
K8S_VER_PATCH="3"
K8S_VER_BUILD="1.1"
CALICO_VER="3.29.3"

sudo swapoff -a
sudo sed -i '/^\/swap/s/^/#/' /etc/fstab

sudo apt update && sudo apt install -y apt-transport-https ca-certificates curl net-tools jq mysql-client
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod a+x /usr/local/bin/yq


curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VER}/deb/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VER}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubectl=${K8S_VER}.${K8S_VER_PATCH}-${K8S_VER_BUILD}
sudo apt-mark hold kubectl


mkdir -p $HOME/.kube
echo 'source <(kubectl completion bash)' >> $HOME/.bashrc

#Helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
sudo helm completion bash | sudo tee  /etc/bash_completion.d/helm >/dev/null


#Calico ctl
cd /usr/local/bin/
sudo curl -L https://github.com/projectcalico/calico/releases/download/v${CALICO_VER}/calicoctl-linux-amd64 -o calicoctl

sudo chmod +x calicoctl
cd ~/

#Delete midnight commander if installed
dpkg -s mc > /dev/null 2>&1
if [ $? = 0 ]; then
    echo "Removing midnight commander"
    sudo apt purge -y mc > /dev/null 2>&1
fi

#Install minio client
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
    --create-dirs \
    -o $HOME/minio-binaries/mc
chmod +x $HOME/minio-binaries/mc
export PATH=$PATH:$HOME/minio-binaries/
echo 'export PATH=$PATH:$HOME/minio-binaries/' >> $HOME/.bashrc
mc alias ls
mc --autocompletion

echo "
Instalation is finished succesfuly
"
