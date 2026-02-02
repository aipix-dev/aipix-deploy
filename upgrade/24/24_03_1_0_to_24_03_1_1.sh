#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh

# Backup MySQL database
kubectl exec --namespace=${NS_VMS} deployment.apps/cron -- ./db_dump.sh

# Update configuration files
../kubernetes/update-configs.sh

# Update traefik
../kubernetes/configure-traefik.sh
../kubernetes/update-traefik-certs.sh >/dev/null

# Update minio
kubectl --namespace=${NS_MINIO} delete ingressroutes.traefik.io minio-console
../kubernetes/update-minio-single.sh

# Updating VMS
../kubernetes/configure-vms.sh
../kubernetes/update-vms.sh >/dev/null

# Updating Mediaserver
if [[ $(kubectl get ns | grep ${NS_MS}) ]]; then
    ../kubernetes/update-mse.sh >/dev/null
fi

# Updating Analytics
if [ ${ANALYTICS} == "yes" ]; then
    ../kubernetes/configure-analytics.sh
    ../kubernetes/update-analytics.sh >/dev/null
fi

echo """
Upgrade script finished successfuly!

"""