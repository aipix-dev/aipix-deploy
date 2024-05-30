#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh

# Backup MySQL database
kubectl exec --namespace=${NS_VMS} deployment.apps/cron -- ./db_dump.sh

# Updating VMS
../kubernetes/update-vms.sh >/dev/null

echo """
Upgrade script finished successfuly!

"""