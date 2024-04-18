#!/bin/bash

#########################
# Install additional  Kubernetes Components for single node nstallation#
#########################

script_path=$(pwd)

scriptdir="$(dirname "$0")"
cd "$scriptdir"

sudo apt install -y jq nfs-common

#Init K8S cluster
cat << EOF > kubeadm_init.yaml
---
apiServer:
  extraArgs:
    authorization-mode: Node,RBAC
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta3
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controlPlaneEndpoint: ${K8S_API_ENDPOINT}:6443 # change to LB IP or DNS name
controllerManager:
  extraArgs:
    allocate-node-cidrs: 'false'
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.k8s.io
kind: ClusterConfiguration
kubernetesVersion: v1.28.8
networking:
  dnsDomain: cluster.local
  podSubnet: ${POD_SUBNET}
  serviceSubnet: ${SERVICE_SUBNET}
scheduler: {}
EOF

sudo kubeadm init --config kubeadm_init.yaml  --upload-certs


mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo 'source <(kubectl completion bash)' >> $HOME/.bashrc

K8S_HOST=$(kubectl get node -o json | jq -c '.items[].metadata.name' | tr -d \")
echo ${K8S_HOST}
kubectl taint nodes ${K8S_HOST} node-role.kubernetes.io/control-plane:NoSchedule-
kubectl label nodes ${K8S_HOST} mediaserver=true

echo "
Waiting for 20 sec for starting containers
"
sleep 20



#Calico instalation

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml

curl https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml -O

sed -i  "s@cidr:.*@cidr: ${POD_SUBNET}@g" custom-resources.yaml # Update your podSubnet

echo "Please wait 30 sec for tigera-operator starts up"
sleep 30

kubectl create -f custom-resources.yaml


#Helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
sudo helm completion bash | sudo tee  /etc/bash_completion.d/helm >/dev/null


#Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml

# Waiting for starting MetalLB
wait_period=0
while true
do
    wait_period=$(($wait_period+10))
    if [ $wait_period -gt 600 ];then
       echo "The script ran for 10 minutes to start containers, exiting now.."
       exit 1
    else
       if [[ $(kubectl get  daemonset speaker -n metallb-system -o jsonpath='{.status.numberReady}') -ge 1 ]]
       then break
       fi
       echo "Waiting for starting MetalLB (max 10 min) ..."
       sleep 10
    fi
done
sleep 10

kubectl create -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - ${L2_ADVERTISEMENT_RANGE}
EOF

kubectl create -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: advertisement-1
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
EOF


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

echo /dev/sdb /mnt/disk-sdb ext4 defaults 0 1 | sudo tee -a /etc/fstab
echo /dev/sdc /storage ext4 defaults 0 1 | sudo tee -a /etc/fstab

for i in $(seq 1 20); do
  sudo mkdir -p /mnt/disk-sdb/vol${i} /mnt/disks/disk_vol${i}
  sudo mount --bind /mnt/disk-sdb/vol${i} /mnt/disks/disk_vol${i}
  echo /mnt/disk-sdb/vol${i} /mnt/disks/disk_vol${i} none bind 0 0 | sudo tee -a /etc/fstab
done

./install_local_volume_provisioner.sh

helm repo add openebs-nfs https://openebs.github.io/dynamic-nfs-provisioner
helm repo update
helm install openebs-nfs openebs-nfs/nfs-provisioner --namespace local-volume  \
	--set-string nfsStorageClass.backendStorageClass="local-storage"


ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa <<<y >/dev/null 2>&1
cat ~/.ssh/id_rsa.pub | tee -a ~/.ssh/authorized_keys

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
