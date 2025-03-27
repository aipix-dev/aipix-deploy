#!/bin/bash
#Install Calico

CALICO_VER="3.29.3"

# script_path=$(pwd)

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VER}/manifests/tigera-operator.yaml

curl https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VER}/manifests/custom-resources.yaml -O

sed -i  "s@cidr:.*@cidr: ${POD_SUBNET}@g" custom-resources.yaml # Update your podSubnet
sed -i "s/calicoNetwork:/&\n    linuxDataplane: Nftables/" custom-resources.yaml

echo "Please wait 30 sec for tigera-operator starts up"
sleep 30

kubectl create -f custom-resources.yaml

sleep 30

kubectl patch  Installation default --type 'json' -p '[{"op": "replace", "path": "/spec/calicoNetwork/nodeAddressAutodetectionV4", "value": {kubernetes: NodeInternalIP}}]'

echo "
Calico instalation is finished succesfuly
"
