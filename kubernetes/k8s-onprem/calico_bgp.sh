#!/bin/bash

cat << EOF > default-bgp.yaml
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata:
  name: default
spec:
  asNumber: 64514
  nodeToNodeMeshEnabled: true
  serviceClusterIPs:
  - cidr: 10.245.0.0/16
  serviceExternalIPs:
  - cidr: 192.168.211.0/24
EOF

calicoctl apply -f  default-bgp.yaml

cat << EOF > worker-1-ebgp-peer.yaml
apiVersion: projectcalico.org/v3
kind: BGPPeer
metadata:
  name: worker-1-ebgp-peer
spec:
  peerIP: 192.168.206.1
  asNumber: 65001
  node: worker01
EOF
calicoctl apply -f  worker-1-ebgp-peer.yaml

cat << EOF > worker-2-ebgp-peer.yaml
apiVersion: projectcalico.org/v3
kind: BGPPeer
metadata:
  name: worker-2-ebgp-peer
spec:
  peerIP: 192.168.206.1
  asNumber: 65001
  node: worker02
EOF
calicoctl apply -f  worker-2-ebgp-peer.yaml


echo "
Instalation is finished succesfuly
"
