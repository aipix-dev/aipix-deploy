#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

### Delete unused envs and resources
sed -i '/LICENSE_SERVER_URL/d' ../ble-service/environments/.env
sed -i '/K8S_NAMESPACE/d' ../vms-backend/environments/.env

### Update VMS
../kubernetes/configure-vms.sh

#raise max_connections for mysql-server
if [ ${TYPE} != "prod" ]; then
	kubectl delete configmap mysql-cnf --namespace=${NS_VMS} || true
	kubectl create configmap mysql-cnf --namespace=${NS_VMS} --from-file=../mysql-server/my.cnf
	kubectl -n ${NS_VMS} rollout restart deployment mysql-server
fi

../kubernetes/update-vms.sh

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