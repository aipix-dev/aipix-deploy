#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

### Update monitoring
if [ ${MONITORING} == "yes" ]; then
	../kubernetes/configure-monitoring.sh
	../kubernetes/deploy-monitoring.sh
else
	echo "Monitoring is not installed, continue update"
fi

### Update VMS
../kubernetes/configure-vms.sh
../kubernetes/update-vms.sh

echo """
Upgrade script completed successfuly!

"""
