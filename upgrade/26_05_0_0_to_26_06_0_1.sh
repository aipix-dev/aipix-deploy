#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

### Delete unused envs and resources
sed -i '/CONTROLLER_ENDPOINT=/d' ../vms-backend/environments/.env
sed -i '/Liscensing source/d' ../vms-backend/environments/.env
sed -i '/LICENSE_SOURCE=/d' ../vms-backend/environments/.env
sed -i '/Online Liscensing/d' ../vms-backend/environments/.env
sed -i '/LICENSE_URL=/d' ../vms-backend/environments/.env
sed -i '/Offline Licensing/d' ../vms-backend/environments/.env
sed -i '/LICENSE_PUBLIC_KEY=/d' ../vms-backend/environments/.env

kubectl -n ${NS_VMS} delete ingressroutes.traefik.io portal frontend-admin || true
kubectl -n ${NS_VMS} delete middlewares.traefik.io strip-prefix-frontend-admin || true

rm ../kustomize/deployments/${VMS_TEMPLATE}/patch-ingressroute-portal.yaml || true
rm ../vms-backend/license/license.json || true

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
