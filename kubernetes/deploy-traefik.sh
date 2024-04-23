#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

# Deploy traefik
kubectl create ns ${TRAEFIK_NAMESPACE}
helm repo add traefik https://helm.traefik.io/traefik >/dev/null
helm repo update >/dev/null
helm install --namespace=${TRAEFIK_NAMESPACE} traefik traefik/traefik >/dev/null

# Create secrets from certificates
kubectl -n ${TRAEFIK_NAMESPACE} create secret tls certificate \
   --cert=../nginx/ssl/tls.crt \
   --key=../nginx/ssl/tls.key >/dev/null

while true
do
    if [[ $(kubectl get deployment traefik -n ${TRAEFIK_NAMESPACE} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]
        then break
    fi
    sleep 5
    echo "Waiting for starting containers ..."
done
sleep 5

# Apply helm values
envsubst < ./traefik/traefik-helm-values.yaml.template > ./traefik/traefik-helm-values.yaml
helm upgrade -n ${TRAEFIK_NAMESPACE} traefik traefik/traefik -f ./traefik/traefik-helm-values.yaml >/dev/null

echo "
Traefik helm values are applied!
"

TRAEFIK_IP=$(kubectl -n ${TRAEFIK_NAMESPACE} get services/traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo """
Deployment script completed successfuly!

Access your Traefik dashboard with the following URL:
http://${TRAEFIK_IP}/dashboard/
https://${TRAEFIK_DOMAIN}/dashboard/ (${TRAEFIK_DOMAIN} should be resolved on DNS-server)
"""
