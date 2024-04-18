#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
export VERSION="23.12.0.0"

# Check VMS version
if [[ $(kubectl --namespace=${NS_VMS} get deployment backend -o jsonpath='{.status.readyReplicas}') -lt 1 ]];then
    echo "VMS backend pod is not available. Quit"
    exit
else
    INSTALLED_VERSION=$(kubectl --namespace=${NS_VMS} exec deployments/backend -c backend -- cat .env | grep "RELEASE" | cut -d "=" -f 2)
    if [[ ${INSTALLED_VERSION} == ${VERSION} ]]; then
        echo "You already have version ${VERSION} installed"
        exit
    else
        echo "Installed version of VMS ${INSTALLED_VERSION} will be upgraded to ${VERSION}"
    fi
fi

# Backup MySQL database
kubectl exec --namespace=${NS_VMS} deployment.apps/cron -- ./db_dump.sh


### Changes ###
if ! grep -q "RWO_STORAGE\|RWX_STORAGE" ../kubernetes/sources.sh; then
    cat <<EOF | tee -a ../kubernetes/sources.sh >/dev/null

export RWO_STORAGE=local-storage
export RWX_STORAGE=openebs-kernel-nfs
EOF
echo "Add variables into ../kubernetes/sources.sh file"
fi

if ! grep -q "CONTROLLER_ENDPOINT\|CONTROLLER_TIMEOUT" ../vms-backend/environments/.env; then
    cat <<EOF | tee -a ../vms-backend/environments/.env >/dev/null

# Controller settings
CONTROLLER_ENDPOINT=http://controller-api/controller/api/v1/private/management
CONTROLLER_TIMEOUT=5
EOF
echo "Add controller variables into ../vms-backend/environments/.env file"
fi

if ! grep -q "QUEUE_NAME" ../vms-backend/environments/.env; then
    cat <<EOF | tee -a ../vms-backend/environments/.env >/dev/null

# Queue name for job dispatch, need to setup in queue config the similar name
QUEUE_NAME=vms
EOF
echo "Add QUEUE_NAME variable into ../vms-backend/environments/.env file"
fi

source ../kubernetes/sources.sh
../kubernetes/configure-vms.sh

# Create CONTROLLER configmsps
kubectl create configmap controller-env --namespace=${NS_VMS} --from-env-file=../controller/environments/.env
kubectl create configmap controller-nginx-conf --namespace=${NS_VMS} --from-file=../nginx/controller-nginx.conf
kubectl create configmap controller-nginx-server-conf --namespace=${NS_VMS} --from-file=../nginx/controller-nginx-server.conf

# Deploying VMS
../kustomize/deployments/${VMS_TEMPLATE}/update-kustomization.sh || exit 1
kubectl apply -k ../kustomize/deployments/${VMS_TEMPLATE} >/dev/null

# Deploy orchestrator and analytics-worker
../kustomize/deployments/${A_TEMPLATE}/update-kustomization.sh || exit 1
kubectl apply -k ../kustomize/deployments/${A_TEMPLATE} >/dev/null

while true
do
    if [[ $(kubectl --namespace=${NS_VMS} get deployment controller -o jsonpath='{.status.readyReplicas}') -ge 1 ]]; then
        break
    fi
    sleep 5
    echo "Waiting for starting controller ..."
done
sleep 10

# Init CONTROLLER
echo "Сontroller initialization ..."
kubectl exec --namespace=${NS_VMS} deployment.apps/controller -- ./scripts/create_db.sh
kubectl exec --namespace=${NS_VMS} deployment.apps/controller -- ./scripts/start.sh

echo """
Upgrade script finished successfuly!

"""