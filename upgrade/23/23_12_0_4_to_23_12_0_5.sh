#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh

# Backup MySQL database
kubectl exec --namespace=${NS_VMS} deployment.apps/cron -- ./db_dump.sh

# Update VMS
../kustomize/deployments/${VMS_TEMPLATE}/update-kustomization.sh || exit 1
kubectl apply -k ../kustomize/deployments/${VMS_TEMPLATE} >/dev/null

#Waiting for containers are started
while true
do
        if [[ $(kubectl get  deployment mysql-server -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]] && \
           [[ $(kubectl get  deployment backend -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]
        then break
       	fi
        sleep 5
        echo "Waiting for updating containers ..."
done

kubectl exec -n ${NS_VMS} deployment.apps/backend -- scripts/docker/update.sh
kubectl exec -n ${NS_VMS} deployment.apps/backend -- chown www-data:www-data -R storage/logs

echo """
Upgrade script finished successfuly!

"""