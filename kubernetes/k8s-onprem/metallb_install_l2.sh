#!/bin/bash

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml
echo "Waiting for 30 sec to start MeetalLB containers"
sleep 30

kubectl create -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.205.24-192.168.205.31
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


