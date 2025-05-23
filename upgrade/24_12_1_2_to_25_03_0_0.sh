#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

# Backup MySQL database
kubectl exec --namespace=${NS_VMS} deployment.apps/cron -- ./db_dump.sh


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

if [ ${TYPE} != "prod" ]; then
	CREATE_MONITORING_MYSQL_USER="CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY 'password' WITH MAX_USER_CONNECTIONS 3;"
	GRANT_PRIVILEGES="GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';FLUSH PRIVILEGES;"
	kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysql --protocol=TCP -u root -pmysql --execute="${CREATE_MONITORING_MYSQL_USER}"
	kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysql --protocol=TCP -u root -pmysql --execute="${GRANT_PRIVILEGES}"
fi

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
    kubectl -n monitoring rollout restart deployment prometheus-deployment
else
    echo "Monitoring is not installed, continue update"
fi

echo """
Upgrade script completed successfuly!

"""