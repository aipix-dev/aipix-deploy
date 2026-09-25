#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

### Delete unused envs and resources
sed -i '/Intercom settings/d' ../vms-backend/environments/.env
sed -i '/INTERCOM_USER_NUMBER_POSTFIX=/d' ../vms-backend/environments/.env
sed -i '/INTERCOM_AUTH_TOKEN/d' ../vms-backend/environments/.env
sed -i '/INTERCOM_SIP_SERVER/d' ../vms-backend/environments/.env
sed -i '/INTERCOM_IS_BLE_KEYS_AVAILABLE/d' ../vms-backend/environments/.env

# Update minio to new image
if [ ${TYPE} == "prod" ]; then
	../kubernetes/update-minio-ha.sh
else
	../kubernetes/update-minio-single.sh
fi

### Update VMS
../kubernetes/configure-vms.sh
../kubernetes/update-vms.sh

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
