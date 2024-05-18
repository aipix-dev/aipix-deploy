#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

# Check if Traefik is installed
if [[ $(kubectl get ns | grep traefik-v2) ]]; then
    echo "

    Warning!

    You have Traefik already installed in namespace traefik-v2.
    If you have some custom configurations (ingressroutes, helm values, etc.) in traefik namespace save them for future use.
    Make your choice:
    1 - I saved my configs, continue upgrade;
    2 - Exit to terminal
    "
    read -p "Enter selected numder: " CHOISE
    case "${CHOISE}" in
        1 ) ;;
        2 ) exit 1;;
        * ) echo "Wrong choise, exit
            "
            exit 1;;
    esac
fi

### Backup MySQL database
kubectl exec --namespace=${NS_VMS} deployment.apps/cron -- ./db_dump.sh

### Delete resources from namespaces
echo "Delete resources from traefik-v2 namespace"
kubectl --namespace=traefik-v2 delete all --all > /dev/null
kubectl delete namespace traefik-v2

echo "Delete resources from ${NS_VMS} namespace"
kubectl --namespace=${NS_VMS} delete all --all > /dev/null

if [[ $(kubectl get ns | grep ${NS_MS}) ]]; then
    echo "Delete resources from ${NS_MS} namespace"
    kubectl --namespace=${NS_MS} delete all --all > /dev/null
fi

if [ ${ANALYTICS} == "yes" ]; then
    echo "Delete resources from ${NS_A} namespace"
    kubectl --namespace=${NS_A} delete all --all > /dev/null
fi

if [ ${MONITORING} == "yes" ]; then
    echo "Delete resources from monitoring namespace"
    kubectl --namespace=monitoring delete all --all > /dev/null
fi

if [[ $(kubectl get ns | grep minio-single) ]]; then
    echo "Delete resources from minio-single namespace"
    kubectl --namespace=minio-single delete all --all > /dev/null
fi

### Deploy ingress controller - Traefik
../kubernetes/configure-traefik.sh
../kubernetes/deploy-traefik.sh

### Deploy Minio s3
# Delete entities associated with the old bucket
sed -i '/MINIO_BUCKET_NAME/d' ../kubernetes/sources.sh
sed -i '/MINIO_ACCESS_KEY/d' ../kubernetes/sources.sh
# Deploy Minio s3
../kubernetes/deploy-minio-single.sh

### Restore VMS
# Run configure script
../kubernetes/configure-vms.sh
# Deploy portal if configured
if [ ${PORTAL} == "yes" ]; then
    echo "Deploy PORTAL"
    #Create PORTAL configmaps
    kubectl create configmap vms-portal-backend-env --namespace=${NS_VMS} --from-env-file=../portal/environments/.env
    kubectl create configmap vms-portal-stub-env --namespace=${NS_VMS} --from-env-file=../portal/environments-stub/.env

    # Deploying PORTAL
    ../kustomize/deployments/${VMS_TEMPLATE}/update-kustomization.sh || exit 1
    kubectl apply -k ../kustomize/deployments/${VMS_TEMPLATE}

    echo "Portal manifests are applied !"
    sleep 10
    while true
    do
        if [[ $(kubectl get deployment mysql-server -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]] && \
            [[ $(kubectl get deployment controller -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]] && \
            [[ $(kubectl get deployment cron -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]] && \
            [[ $(kubectl get deployment backend -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]        
        then break
        fi
        sleep 5
        echo "Waiting for starting containers ..."
    done
    sleep 10
    kubectl -n ${NS_VMS} exec deployment.apps/portal-backend -- ./scripts/create_db.sh
    kubectl -n ${NS_VMS} exec deployment.apps/portal-stub -- ./scripts/create_db.sh
    kubectl -n ${NS_VMS} exec deployment.apps/portal-backend -- ./scripts/start.sh
    kubectl -n ${NS_VMS} exec deployment.apps/portal-stub -- ./scripts/start.sh
fi
# Restore VMS
../kubernetes/configure-vms.sh
../kubernetes/update-vms.sh
kubectl -n ${NS_VMS} exec deployment.apps/controller -- ./artisan ip-access:manage private_api '0.0.0.0/0'
kubectl -n ${NS_VMS} exec deployment.apps/controller -- ./artisan ip-access:manage public_api '0.0.0.0/0'
kubectl -n ${NS_VMS} exec deployment.apps/controller -- ./artisan ip-access:manage media_servers_callback '0.0.0.0/0'

# Restore Mediaserver
if [[ $(kubectl get ns | grep ${NS_MS}) ]]; then
    ../kubernetes/configure-mediaserver.sh ${MS1_IP}
    ../kubernetes/configure-mediaserver.sh ${MS1_IP} $(echo ${USER}) configure
    ../kubernetes/deploy-mediaserver.sh
fi

# Restore Analytics
if [ ${ANALYTICS} == "yes" ]; then
    ../kubernetes/configure-analytics.sh
    ../kubernetes/update-analytics.sh
fi

# Restore Monitoring
if [ ${MONITORING} == "yes" ]; then
    ../kubernetes/configure-monitoring.sh
    ../kubernetes/deploy-monitoring.sh
fi

echo """
Upgrade script finished successfuly!

"""