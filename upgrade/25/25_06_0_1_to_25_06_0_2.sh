#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

### Backup MySQL databases
kubectl exec -n ${NS_VMS} deployment.apps/cron -- ./db_dump.sh
../kubernetes/db-dump.sh

### Update VMS

kubectl -n ${NS_VMS} delete deployments.apps vgw-backend || true

# Update VGW
if [ ${VGW} == "yes" ]; then
    sed -i 's@KAM_CONTROLL.*@KAM_CONTROLL: "http://vgw-backend/api/v1/intercom-module/"@g' ../vgw/values.yaml
    ../kubernetes/update-vgw.sh
else
    echo "VGW is not installed, continue update"
fi

# Update VMS
../kubernetes/update-vms.sh

### Update Analytics
if [ ${ANALYTICS} == "yes" ]; then
    ../kubernetes/configure-analytics.sh
    ../kubernetes/update-analytics.sh
else
    echo "Analytics is not installed, continue update"
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