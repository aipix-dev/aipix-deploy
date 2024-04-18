#!/bin/bash

sudo swapoff -a
sudo sed -i '/^\/swap/s/^/#/' /etc/fstab

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo apt install -y net-tools jq
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod a+x /usr/local/bin/yq


curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list


sudo apt-get update
sudo apt-get install -y kubectl=1.28.8-1.1
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
sudo curl -L https://github.com/projectcalico/calico/releases/download/v3.25.1/calicoctl-linux-amd64 -o calicoctl

sudo chmod +x calicoctl
cd ~/

echo "
Instalation is finished succesfuly
"
