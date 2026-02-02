#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
export VERSION="23.12.0.2"

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

source ../kubernetes/sources.sh
../kubernetes/configure-analytics.sh

# Update VMS
../kustomize/deployments/${VMS_TEMPLATE}/update-kustomization.sh || exit 1
kubectl apply -k ../kustomize/deployments/${VMS_TEMPLATE} >/dev/null

../kubernetes/update-analytics.sh >/dev/null

echo """
Upgrade script finished successfuly!

"""