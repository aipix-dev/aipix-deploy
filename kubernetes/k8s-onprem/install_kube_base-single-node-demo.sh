#!/bin/bash

#########################
# Install additional  Kubernetes Components for single node nstallation#
#########################

# script_path=$(pwd)
scriptdir="$(dirname "$0")"
cd "$scriptdir"

if [ ! -f "./sources.sh" ]; then
    echo >&2 "ERROR: File sources.sh does not exist. Please make a copy from sources.sh.sample and edit as required"
    exit 2
fi
source ./sources.sh
if [ -z "${SRC_K8S_VER}" ]; then
    echo >&2  "ERROR: File sources.sh does not contain K8S version variables. Copy system variables fom sources.sh.sample file."
    exit 2
fi


K8S_VER=${SRC_K8S_VER}
K8S_VER_PATCH=${SRC_K8S_VER_PATCH}
MetalLB_VER=${SRC_MetalLB_VER}
CALICO_VER=${SRC_CALICO_VER}

sudo apt install -y jq nfs-common

#Init K8S cluster
./kube_master_init_with_local_etcd.sh

K8S_HOST=$(kubectl get node -o json | jq -c '.items[].metadata.name' | tr -d \")
echo "Node hostname is ${K8S_HOST}"
kubectl taint nodes ${K8S_HOST} node-role.kubernetes.io/control-plane:NoSchedule-
kubectl label nodes ${K8S_HOST} mediaserver=true
kubectl label node ${K8S_HOST} node.kubernetes.io/exclude-from-external-load-balancers-

echo "
Waiting for 10 sec for starting containers
"
sleep 10

sudo systemctl restart containerd.service
sleep 10

#Calico instalation
./install_calico.sh

#Helm instalation
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt update && sudo apt install -y helm
sudo helm completion bash | sudo tee /etc/bash_completion.d/helm >/dev/null


#MetalLB instalation
./metallb_install_l2.sh


#Metric Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
#Disable TLS
kubectl patch deployment metrics-server -n kube-system --type 'json' -p '[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'


#Prepare storages
sudo mkdir -p /mnt/disk-sdb /storage
sudo mkfs.ext4 /dev/sdb
sudo mkfs.ext4 /dev/sdc
sudo mount /dev/sdb /mnt/disk-sdb
sudo mount /dev/sdc /storage

echo /dev/sdb /mnt/disk-sdb ext4 defaults,nofail 0 2 | sudo tee -a /etc/fstab
echo /dev/sdc /storage ext4 defaults,nofail 0 2 | sudo tee -a /etc/fstab

for i in $(seq 1 20); do
    sudo mkdir -p /mnt/disk-sdb/vol${i} /mnt/disks/disk_vol${i}
    sudo mount --bind /mnt/disk-sdb/vol${i} /mnt/disks/disk_vol${i}
    echo /mnt/disk-sdb/vol${i} /mnt/disks/disk_vol${i} none bind 0 0 | sudo tee -a /etc/fstab
done

#for ubuntu 24.04 you need to apply fstab changes
sudo systemctl daemon-reload

./install_local_volume_provisioner.sh

helm repo add openebs-nfs https://openebs-archive.github.io/dynamic-nfs-provisioner
helm repo update
helm install openebs-nfs openebs-nfs/nfs-provisioner --namespace local-volume  \
	--set-string nfsStorageClass.backendStorageClass="local-storage"


ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa <<<y >/dev/null 2>&1
cat ~/.ssh/id_rsa.pub | tee -a ~/.ssh/authorized_keys

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
Kubernetes single node instalation is finished succesfuly


"
