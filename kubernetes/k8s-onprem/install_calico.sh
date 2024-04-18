#!/bin/bash
#Install Calico

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml

curl https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml -O

sed -i -e '/cidr:/s/\([0-9]\+.\)\{3\}[0-9]\+\/[0-9]\+/10.244.0.0\/16/' custom-resources.yaml # Update your podSubnet

echo "Please wait 30 sec for tigera-operator starts up"
sleep 30

kubectl create -f custom-resources.yaml

echo "
Calico instalation is finished succesfuly
"
