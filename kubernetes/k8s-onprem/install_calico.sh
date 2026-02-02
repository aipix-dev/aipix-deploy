#!/bin/bash
#Install Calico

# script_path=$(pwd)
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

CALICO_VER=${SRC_CALICO_VER}

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VER}/manifests/tigera-operator.yaml

curl https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VER}/manifests/custom-resources.yaml -O

sed -i "s@cidr:.*@cidr: ${POD_SUBNET}@g" custom-resources.yaml # Update your podSubnet
sed -i "s/calicoNetwork:/&\n    linuxDataplane: Nftables/" custom-resources.yaml

echo "Please wait 30 sec for tigera-operator starts up"
sleep 30

kubectl create -f custom-resources.yaml

sleep 30

kubectl patch Installation default --type 'json' -p '[{"op": "replace", "path": "/spec/calicoNetwork/nodeAddressAutodetectionV4", "value": {kubernetes: NodeInternalIP}}]'

timeout=600
interval=5
elapsed=0
while ! kubectl get bgpconfigurations >/dev/null 2>&1; do
    if [ $elapsed -ge $timeout ]; then
        echo "Timed out waiting for calico CRDs, continuing..."
        break
    fi
    echo "Calico CRDs not available yet, sleeping $interval seconds..."
    sleep $interval
    elapsed=$((elapsed + interval))
done

echo "Waiting 10s for Calico CRDs"
sleep 10 

kubectl apply -f - <<EOF
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata:
  name: default
spec:
  logSeverityScreen: Info
  nodeToNodeMeshEnabled: false
  asNumber: 64512
EOF

echo "
Calico instalation is finished succesfuly
"
