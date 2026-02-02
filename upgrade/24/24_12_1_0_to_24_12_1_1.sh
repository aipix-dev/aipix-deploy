#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

# Backup MySQL database
kubectl exec --namespace=${NS_VMS} deployment.apps/cron -- ./db_dump.sh


### Update Traefik
yq -i '.additionalArguments += "--entryPoints.websecure.transport.respondingTimeouts.readTimeout=120"' ../traefik/traefik-helm-values.yaml
../kubernetes/update-traefik-certs.sh

### Update VMS

# Update VGW
if [[ $(kubectl --namespace=${NS_VMS} get statefulsets.apps vgw) ]]; then
	../kubernetes/update-vgw.sh
else
	echo "VGW is not installed, continue update"
fi

# Update VMS
../kubernetes/configure-vms.sh
../kubernetes/update-vms.sh

kubectl -n ${NS_VMS} exec deployment.apps/cron -- ./artisan ip-access:manage analytic_video '10.0.0.0/8' || true
kubectl -n ${NS_VMS} exec deployment.apps/cron -- ./artisan ip-access:manage analytic_video '172.16.0.0/12' || true
kubectl -n ${NS_VMS} exec deployment.apps/cron -- ./artisan ip-access:manage analytic_video '192.168.0.0/16' || true

# Update MSE
if [[ $(kubectl get ns | grep ${NS_MS}) ]]; then
	../kubernetes/update-mse.sh
else
	echo "MSE is not installed in k8s, continue update"
fi

# Update Analytics
if [ ${ANALYTICS} == "yes" ]; then
	../kubernetes/configure-analytics.sh
	../kubernetes/update-analytics.sh
else
	echo "Analytics is not installed, continue update"
fi

# Update monitoring
if [ ${MONITORING} == "yes" ]; then
	../kubernetes/configure-monitoring.sh
	../kubernetes/deploy-monitoring.sh
else
	echo "Monitoring is not installed, continue update"
fi

echo """
Upgrade script completed successfuly!

"""