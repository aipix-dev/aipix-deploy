#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

sed -i "s@MINIO_GRAFANA_BUCKET_NAME=.*@MINIO_GRAFANA_BUCKET_NAME=grafana@" ../kubernetes/sources.sh

### Update monitoring
if [ ${MONITORING} == "yes" ]; then

    if [ ${TYPE} == "prod" ]; then
        mc admin user svcacct remove minio-1 ${MINIO_GRAFANA_BUCKET_NAME}-user
        mc admin user svcacct remove minio-2 ${MINIO_GRAFANA_BUCKET_NAME}-user
        mc ilm rule remove minio-1/${MINIO_GRAFANA_BUCKET_NAME} --all --force
        mc ilm rule remove minio-2/${MINIO_GRAFANA_BUCKET_NAME} --all --force
        mc admin user remove minio-1 ${MINIO_GRAFANA_BUCKET_NAME}-user
        mc admin user remove minio-2 ${MINIO_GRAFANA_BUCKET_NAME}-user
        mc admin policy remove minio-1 ${MINIO_GRAFANA_BUCKET_NAME}-policy
        mc admin policy remove minio-2 ${MINIO_GRAFANA_BUCKET_NAME}-policy
        mc rb minio-1/${MINIO_GRAFANA_BUCKET_NAME} --force
        mc rb minio-2/${MINIO_GRAFANA_BUCKET_NAME} --force
    else
        mc admin user svcacct remove local ${MINIO_GRAFANA_BUCKET_NAME}-user
        mc ilm rule remove local/${MINIO_GRAFANA_BUCKET_NAME} --all --force
        mc admin user remove local ${MINIO_GRAFANA_BUCKET_NAME}-user
        mc admin policy remove local ${MINIO_GRAFANA_BUCKET_NAME}-policy
        mc rb local/${MINIO_GRAFANA_BUCKET_NAME} --force
    fi

    source ../kubernetes/sources.sh

    if [ ${TYPE} == "prod" ]; then
        ../kubernetes/deploy-minio-ha.sh
    else
        ../kubernetes/deploy-minio-single.sh
    fi

    ../kubernetes/configure-monitoring.sh
    ../kubernetes/deploy-monitoring.sh
else
    echo "Monitoring is not installed, continue update"
fi

### Update VMS
../kubernetes/configure-vms.sh
../kubernetes/update-vms.sh

### Update Analytics
if [ ${ANALYTICS} == "yes" ]; then
    ../kubernetes/configure-analytics.sh
    ../kubernetes/update-analytics.sh
else
    echo "Analytics is not installed, continue update"
fi

### Update MSE
if [[ $(kubectl get ns | grep ${NS_MS}) ]]; then
    ../kubernetes/update-mse.sh
else
    echo "MSE is not installed in k8s, continue update"
fi

echo """
Upgrade script completed successfuly!

"""