#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

#Create configs and secrets
kubectl -n ${TRAEFIK_NAMESPACE} delete secret certificate >/dev/null || true
kubectl -n ${TRAEFIK_NAMESPACE} create secret tls certificate \
					--cert=../nginx/ssl/tls.crt \
					--key=../nginx/ssl/tls.key >/dev/null

kubectl -n ${TRAEFIK_NAMESPACE} delete ingressroutes.traefik.io traefik-dashboard >/dev/null
helm upgrade -n ${TRAEFIK_NAMESPACE} traefik traefik/traefik -f ../traefik/traefik-helm-values.yaml >/dev/null

echo """

Traefik and certificates update script completed successfuly!

"""