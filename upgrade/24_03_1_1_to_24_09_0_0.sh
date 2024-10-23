#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

# Backup MySQL database
kubectl exec --namespace=${NS_VMS} deployment.apps/cron -- ./db_dump.sh

kubectl --namespace=${NS_VMS} exec deployments/backend -- cat storage/file.key > ../vms-backend/certificates/file.key
kubectl --namespace=${NS_VMS} exec deployments/backend -- cat storage/oauth-public.key > ../vms-backend/certificates/oauth-public.key
kubectl --namespace=${NS_VMS} exec deployments/backend -- cat storage/oauth-private.key > ../vms-backend/certificates/oauth-private.key

for i in $(kubectl -n metallb-system get ipaddresspools.metallb.io | awk 'NR>1 { print $1 }'); do kubectl -n metallb-system delete ipaddresspools.metallb.io $i; done
for i in $(kubectl -n metallb-system get l2advertisements.metallb.io | awk 'NR>1 { print $1 }'); do kubectl -n metallb-system delete l2advertisements.metallb.io $i; done

kubectl create -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: traefik-pool
  namespace: metallb-system
spec:
  addresses:
  - ${TRAEFIK_ADVERTISEMENT_RANGE}
  serviceAllocation:
    priority: 50
    serviceSelectors:
    - matchExpressions:
      - key: app.kubernetes.io/name
        operator: In
        values:
        - traefik
EOF

kubectl create -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: traefik-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - traefik-pool
EOF

kubectl create -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: service-pool
  namespace: metallb-system
spec:
  addresses:
  - ${L2_ADVERTISEMENT_RANGE}
EOF

kubectl create -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: service-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - service-pool
EOF

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

### Delete resources from namespaces
echo "Delete resources from traefik-v2 namespace"
kubectl --namespace=traefik-v2 delete all --all > /dev/null
kubectl delete namespace traefik-v2

echo "Delete resources from ${NS_VMS} namespace"
kubectl --namespace=${NS_VMS} delete all --all > /dev/null

if [[ $(kubectl get ns | grep minio-single) ]]; then
    echo "Delete resources from minio-single namespace"
    BACKEND_BUCKET_NAME_OLD=$BACKEND_BUCKET_NAME
    ANALYTICS_BUCKET_NAME_OLD=$ANALYTICS_BUCKET_NAME
    mc admin user rm local $BACKEND_BUCKET_NAME_OLD-user
    mc admin policy rm local $BACKEND_BUCKET_NAME_OLD-policy
    mc admin user rm local $ANALYTICS_BUCKET_NAME_OLD-user
    mc admin policy rm local $ANALYTICS_BUCKET_NAME_OLD-policy
    mc alias rm local
    kubectl --namespace=minio-single delete all --all > /dev/null
    kubectl --namespace=minio-single delete secrets minio-secret
    kubectl --namespace=minio-single delete ingressroutes.traefik.io minio-api || true
fi

### Deploy ingress controller - Traefik
../kubernetes/deploy-traefik.sh

### Deploy Minio s3
../kubernetes/generate-sources.sh force
source ../kubernetes/sources.sh
# Restore Minio s3
../kubernetes/deploy-minio-single.sh
mc mv --recursive local/$BACKEND_BUCKET_NAME_OLD/ local/$MINIO_BACKEND_BUCKET_NAME && mc rb local/$BACKEND_BUCKET_NAME_OLD

### Restore VMS
# Run configure script
../kubernetes/configure-vms.sh

# Restore VMS
../kubernetes/update-vms.sh

# Restore Mediaserver
if [[ $(kubectl get ns | grep ${NS_MS}) ]]; then
    echo "Delete resources from ${NS_MS} namespace"
    kubectl --namespace=${NS_MS} delete all --all > /dev/null
fi

# Restore Analytics
if [ ${ANALYTICS} == "yes" ]; then
    echo "Delete resources from ${NS_A} namespace"
    kubectl --namespace=${NS_A} delete all --all > /dev/null
    ../kubernetes/configure-analytics.sh
    ../kubernetes/update-analytics.sh
fi

# Restore Monitoring
if [ ${MONITORING} == "yes" ]; then
    echo "Delete resources from monitoring namespace"
    kubectl --namespace=monitoring delete all --all > /dev/null
    ../kubernetes/configure-monitoring.sh
    ../kubernetes/deploy-monitoring.sh
fi

echo """
Upgrade script finished successfuly!

"""
