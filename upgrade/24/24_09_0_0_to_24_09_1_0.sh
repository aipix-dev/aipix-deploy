#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

# Backup MySQL database
kubectl exec --namespace=${NS_VMS} deployment.apps/cron -- ./db_dump.sh

kubectl --namespace=${NS_VMS} exec deployments/backend -- cat storage/file.key > ../vms-backend/certificates/file.key
kubectl --namespace=${NS_VMS} exec deployments/backend -- cat storage/oauth-public.key > ../vms-backend/certificates/oauth-public.key
kubectl --namespace=${NS_VMS} exec deployments/backend -- cat storage/oauth-private.key > ../vms-backend/certificates/oauth-private.key

### Apply new config for push1st devices app
cp ../push1st/devices.yml.sample ../push1st/devices.yml

### Update Traefik
../kubernetes/update-traefik-certs.sh

### Update VMS
# Run configure script
../kubernetes/configure-vms.sh
sed -i "s@BRIDGE_SOCKET_GATEWAY_ENDPOINT=.*@BRIDGE_SOCKET_GATEWAY_ENDPOINT=http://push1st:6002/apps/devices/events@g" ../controller/environments/.env
sed -i "s@AGENT_SOCKET_GATEWAY_ENDPOINT=.*@AGENT_SOCKET_GATEWAY_ENDPOINT=http://push1st:6002/apps/devices/events@g" ../controller/environments/.env
sed -i "s@BRIDGE_ENCRYPTION_KEY=.*@BRIDGE_ENCRYPTION_KEY=3AsSNzf056mcdF4V5tzV11xkbosIV9wX@g" ../controller/environments/.env

# Update VMS
../kubernetes/update-vms.sh
kubectl --namespace=${NS_VMS} delete pvc storage || true
kubectl --namespace=${NS_VMS} delete pvc controller-storage || true
kubectl --namespace=${NS_VMS} delete pvc portal-storage || true

# Update Analytics
../kubernetes/update-analytics.sh
kubectl --namespace=${NS_A} delete pvc tarantool || true

# Update Monitoring
../kubernetes/configure-monitoring.sh
../kubernetes/deploy-monitoring.sh

echo """
Upgrade script finished successfuly!

"""
