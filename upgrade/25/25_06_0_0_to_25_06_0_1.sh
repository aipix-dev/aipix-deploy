#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

### Backup MySQL databases
kubectl exec -n ${NS_VMS} deployment.apps/cron -- ./db_dump.sh
../kubernetes/db-dump.sh

# Update VMS
../kubernetes/update-vms.sh
kubectl -n ${NS_VMS} delete deployments.apps intercom-calls controller-set-configs controller-media-servers-callback-queue || true

### Update Analytics
if [ ${ANALYTICS} == "yes" ]; then
    ../kubernetes/configure-analytics.sh
    ../kubernetes/update-analytics.sh
    kubectl -n ${NS_A} delete pvc a-license-config
else
    echo "Analytics is not installed, continue update"
fi

echo """
Upgrade script completed successfuly!

"""