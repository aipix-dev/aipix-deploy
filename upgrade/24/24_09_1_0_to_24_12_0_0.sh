#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

# Backup MySQL database
kubectl exec --namespace=${NS_VMS} deployment.apps/cron -- apt update >/dev/null
kubectl exec --namespace=${NS_VMS} deployment.apps/cron -- apt install -y s3cmd >/dev/null
kubectl exec --namespace=${NS_VMS} deployment.apps/cron -- ./db_dump.sh

# kubectl --namespace=${NS_VMS} exec deployments/backend -- cat storage/file.key > ../vms-backend/certificates/file.key
# kubectl --namespace=${NS_VMS} exec deployments/backend -- cat storage/oauth-public.key > ../vms-backend/certificates/oauth-public.key
# kubectl --namespace=${NS_VMS} exec deployments/backend -- cat storage/oauth-private.key > ../vms-backend/certificates/oauth-private.key

### Update VMS
# Remove unused frontend envs 
rm -rf ../vms-frontend/client* || true
sed -i "/MAP_CENTER/d" ../vms-frontend/admin.env || true

# Update VMS
../kubernetes/configure-vms.sh
../kubernetes/update-vms.sh
kubectl -n ${NS_VMS} exec deployment.apps/cron -- ./artisan ip-access:manage billing '10.0.0.0/8' --fresh || true
kubectl -n ${NS_VMS} exec deployment.apps/cron -- ./artisan ip-access:manage billing '172.16.0.0/12' || true
kubectl -n ${NS_VMS} exec deployment.apps/cron -- ./artisan ip-access:manage billing '192.168.0.0/16' || true

kubectl -n ${NS_VMS} exec deployment.apps/controller-api -- ./artisan ip-access:manage private_api '10.0.0.0/8' --fresh || true
kubectl -n ${NS_VMS} exec deployment.apps/controller-api -- ./artisan ip-access:manage private_api '172.16.0.0/12' || true
kubectl -n ${NS_VMS} exec deployment.apps/controller-api -- ./artisan ip-access:manage private_api '192.168.0.0/16' || true
kubectl -n ${NS_VMS} exec deployment.apps/controller-api -- ./artisan ip-access:manage media_servers_callback '0.0.0.0/0' --fresh || true
kubectl -n ${NS_VMS} exec deployment.apps/controller-api -- ./artisan ip-access:manage onvif_events_callback '10.0.0.0/8' --fresh || true
kubectl -n ${NS_VMS} exec deployment.apps/controller-api -- ./artisan ip-access:manage onvif_events_callback '172.16.0.0/12' || true
kubectl -n ${NS_VMS} exec deployment.apps/controller-api -- ./artisan ip-access:manage onvif_events_callback '192.168.0.0/16' || true


# Update VMS
if [[ $(kubectl get ns | grep ${NS_MS}) ]]; then
    ../kubernetes/update-mse.sh
fi

# Update Analytics
if [ ${ANALYTICS} == "yes" ]; then
    ../kubernetes/configure-analytics.sh
    ../kubernetes/update-analytics.sh
fi

echo """
Upgrade script finished successfuly!

"""