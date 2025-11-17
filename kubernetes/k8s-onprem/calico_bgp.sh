#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

if [ ! -f "./sources.sh" ]; then
	echo >&2 "ERROR: File sources.sh does not exist. Please make a copy from sources.sh.sample and edit as required"
	exit 2
fi
source ./sources.sh
if [ -z "${SRC_CALICO_VER}" ]; then
	echo >&2  "ERROR: File sources.sh does not contain K8S version variables. Copy system variables fom sources.sh.sample file."
	exit 2
fi

kubectl apply -f - <<EOF
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata:
  name: default
spec:
  asNumber: 64512
  logSeverityScreen: Info
  nodeToNodeMeshEnabled: false
  serviceClusterIPs:
  - cidr: ${SERVICE_SUBNET}
#  serviceExternalIPs:
#  - cidr: 192.168.211.0/24
#  serviceLoadBalancerIPs:
#  - cidr: 192.168.209.0/24
EOF


kubectl apply -f - <<EOF
apiVersion: projectcalico.org/v3
kind: BGPPeer
metadata:
  name: worker-1-ebgp-peer-1
spec:
  peerIP: 192.168.206.1
  asNumber: 65001
  node: worker-01
EOF

kubectl apply -f - <<EOF
apiVersion: projectcalico.org/v3
kind: BGPPeer
metadata:
  name: worker-1-ebgp-peer-2
spec:
  peerIP: 192.168.206.2
  asNumber: 65001
  node: worker-01
EOF


kubectl apply -f - <<EOF
apiVersion: projectcalico.org/v3
kind: BGPPeer
metadata:
  name: worker-2-ebgp-peer-1
spec:
  peerIP: 192.168.206.1
  asNumber: 65001
  node: worker-02
EOF

kubectl apply -f - <<EOF
apiVersion: projectcalico.org/v3
kind: BGPPeer
metadata:
  name: worker-2-ebgp-peer-2
spec:
  peerIP: 192.168.206.2
  asNumber: 65001
  node: worker-02
EOF


echo "
BGP configuration is finished succesfuly
"
