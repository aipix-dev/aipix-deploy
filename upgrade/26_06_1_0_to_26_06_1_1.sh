#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

### Delete unused resources
rm ../push1st/cluster.yml
kubectl -n ${NS_VMS} delete deployments.apps push1st || true
kubectl -n ${NS_VMS} delete services push1st || true
kubectl -n ${NS_VMS} delete ingressroutes.traefik.io push1st || true
kubectl -n ${NS_VMS} delete configmaps push1st-server || true


### Update VMS
../kubernetes/configure-vms.sh
../kubernetes/update-vms.sh

### Update VGW
if [ ${VGW} == "yes" ]; then
	../kubernetes/configure-vgw.sh
	../kubernetes/update-vgw.sh
else
	echo "VGW is not installed, continue update"
fi

### Update Analytics
if [ ${ANALYTICS} == "yes" ]; then
	../kubernetes/configure-analytics.sh
	../kubernetes/update-analytics.sh
else
	echo "Analytics is not installed, continue update"
fi

### Update MSE
if [[ $(kubectl get ns | grep ${NS_MS}) ]]; then
	../kubernetes/update-mse.sh
else
	echo "MSE is not installed in k8s, continue update"
fi

### Update monitoring
if [ ${MONITORING} == "yes" ]; then
	../kubernetes/configure-monitoring.sh
	../kubernetes/deploy-monitoring.sh
else
	echo "Monitoring is not installed, continue update"
fi

echo """
Upgrade script completed successfuly!

"""
