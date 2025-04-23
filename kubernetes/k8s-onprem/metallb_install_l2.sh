#!/bin/bash

# script_path=$(pwd)
scriptdir="$(dirname "$0")"
cd "$scriptdir"

if [ ! -f "./sources.sh" ]; then
	echo >&2 "ERROR: File sources.sh does not exist. Please make a copy from sources.sh.sample and edit as required"
	exit 2
fi
source ./sources.sh
if [ -z "${SRC_MetalLB_VER}" ]; then
	echo >&2 "ERROR: File sources.sh does not contain K8S version variables. Copy system variables fom sources.sh.sample file."
	exit 2
fi


MetalLB_VER=${SRC_MetalLB_VER}


kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v${MetalLB_VER}/config/manifests/metallb-native.yaml

# Waiting for starting MetalLB
wait_period=0
while true
do
	wait_period=$(($wait_period+10))
	if [ $wait_period -gt 600 ]; then
		echo "The script ran for 10 minutes to start containers, exiting now.."
		exit 1
	else
		if [[ $(kubectl get daemonset speaker -n metallb-system -o jsonpath='{.status.numberReady}') -ge 1 ]]; then
			break
		fi
		echo "Waiting for starting MetalLB (max 10 min) ..."
		sleep 10
	fi
done
sleep 10

#Delete tolerations
kubectl -n metallb-system patch daemonsets.apps speaker --type 'json' -p '[{"op": "remove", "path": "/spec/template/spec/tolerations"}]'

kubectl create -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: traefik-pool
  namespace: metallb-system
spec:
  addresses:
  - ${TRAEFIK_ADVERTISEMENT_RANGE}
  serviceAllocation:
    priority: 50
    serviceSelectors:
    - matchExpressions:
      - key: app.kubernetes.io/name
        operator: In
        values:
        - traefik
EOF

kubectl create -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: traefik-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - traefik-pool
#  nodeSelectors:
#  - matchLabels:
#      kubernetes.io/hostname: k8s-worker-01
#  - matchLabels:
#      kubernetes.io/hostname: k8s-worker-02
#  - matchLabels:
#      kubernetes.io/hostname: k8s-worker-03
EOF

if [[ -n ${L2_ADVERTISEMENT_RANGE} ]]; then
	kubectl create -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: service-pool
  namespace: metallb-system
spec:
  addresses:
  - ${L2_ADVERTISEMENT_RANGE}
EOF

	kubectl create -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: service-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - service-pool
#  nodeSelectors:
#  - matchLabels:
#      kubernetes.io/hostname: k8s-worker-01
#  - matchLabels:
#      kubernetes.io/hostname: k8s-worker-02
#  - matchLabels:
#      kubernetes.io/hostname: k8s-worker-03
EOF
fi
