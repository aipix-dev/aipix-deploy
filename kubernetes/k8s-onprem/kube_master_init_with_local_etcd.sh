#!/bin/bash

cat << EOF > kubeadm_init.yaml
---
apiServer:
  extraArgs:
    authorization-mode: Node,RBAC
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta3
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controlPlaneEndpoint: 192.168.205.12:6443 # change to LB IP or DNS name
controllerManager:
  extraArgs:
    allocate-node-cidrs: 'false'
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.k8s.io
kind: ClusterConfiguration
kubernetesVersion: v1.28.2
networking:
  dnsDomain: cluster.local
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.245.0.0/16
scheduler: {}
EOF

sudo kubeadm init --config kubeadm_init.yaml  --upload-certs


mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo 'source <(kubectl completion bash)' >> $HOME/.bashrc

echo "
Kubernates instalation is finished succesfuly
Clusetr inited with  kubeadm init --config kubeadm_init.yaml
Save the output. It will be used on the next steps.
"
