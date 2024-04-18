#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh

# Backup MySQL database
kubectl exec --namespace=${NS_VMS} deployment.apps/cron -- ./db_dump.sh

### Changes ###
cp ../controller/environments/env.sample ../controller/environments/.env
kubectl --namespace=${NS_VMS} delete deployment.apps controller-control-plane || true
kubectl --namespace=${NS_VMS} delete services controller-control-plane || true

# Updating VMS
../kubernetes/update-vms.sh >/dev/null

echo """
Upgrade script finished successfuly!

"""