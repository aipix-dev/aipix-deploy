#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

# Delete BACKEND_STORAGE_TYPE env from ../kubernetes/sources.sh file
sed -i '/^BACKEND_STORAGE_TYPE=/d' ../kubernetes/sources.sh

### Update VMS
../kubernetes/configure-vms.sh
../kubernetes/update-vms.sh

### Update VGW
if [ ${VGW} == "yes" ]; then
	../kubernetes/configure-vgw.sh
	../kubernetes/update-vgw.sh
else
	echo "VGW is not installed, continue update"
fi

if [ ${ANALYTICS} == "yes" ]; then
	../kubernetes/configure-analytics.sh
	../kubernetes/update-analytics.sh
else
	echo "Analytics is not installed, continue update"
fi

### Update monitoring
if [ ${MONITORING} == "yes" ]; then
	../kubernetes/configure-monitoring.sh
	../kubernetes/deploy-monitoring.sh
else
	echo "Monitoring is not installed, continue update"
fi

echo """
Upgrade script completed successfuly!

"""
