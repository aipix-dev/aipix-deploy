#!/bin/bash

K8S_VER="1.32"
K8S_VER_PATCH="3"

# script_path=$(pwd)

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

cat << EOF > kubeadm_init.yaml
---
apiServer:
  extraArgs:
  - name: authorization-mode
    value: Node,RBAC
apiVersion: kubeadm.k8s.io/v1beta4
caCertificateValidityPeriod: 262800h0m0s
certificateValidityPeriod: 43800h0m0s
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controlPlaneEndpoint: ${K8S_API_ENDPOINT}:6443
controllerManager:
  extraArgs:
  - name: allocate-node-cidrs
    value: "false"
dns: {}
encryptionAlgorithm: RSA-2048
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.k8s.io
kind: ClusterConfiguration
kubernetesVersion: v${K8S_VER}.${K8S_VER_PATCH}
networking:
  dnsDomain: cluster.local
  podSubnet: ${POD_SUBNET}
  serviceSubnet: ${SERVICE_SUBNET}
proxy: {}
scheduler: {}
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: nftables
EOF

sudo kubeadm init --config kubeadm_init.yaml  --upload-certs


mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo 'source <(kubectl completion bash)' >> $HOME/.bashrc

echo "
Kubernates instalation is finished succesfuly
Clusetr inited with  kubeadm init --config kubeadm_init.yaml
Save the output above. It will be used on the next steps.
"
