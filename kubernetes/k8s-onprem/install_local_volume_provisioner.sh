#!/bin/bash -e 

cat << EOF > local-value.yaml
classes:
- name: local-storage
  hostDir: /mnt/disks
  volumeMode: Filesystem
  storageClass: true
tolerations:
- effect: NoSchedule
  key: monitoring
  operator: Exists
- effect: NoSchedule
  key: analytics
  operator: Exists
- effect: NoSchedule
  key: mediaserver
  operator: Exists
- effect: NoSchedule
  key: storage
  operator: Exists
- effect: NoSchedule
  key: db
  operator: Exists
EOF

kubectl create ns local-volume || true
helm repo add sig-storage-local-static-provisioner https://kubernetes-sigs.github.io/sig-storage-local-static-provisioner
helm template --debug sig-storage-local-static-provisioner/local-static-provisioner -f local-value.yaml --namespace local-volume > local-volume-provisioner.generated.yaml
kubectl apply -f local-volume-provisioner.generated.yaml

echo "Please wait 20 sec for local-volume-static-provisioner starts up"
sleep 20

echo "
sig-storage-local-static-provisioner is installed !
" 
