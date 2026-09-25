#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

UPDATE_MODE=$1   #If passed "full" script will rollout restart all of services

source ./sources.sh

#Create configs and secrets
kubectl -n ${TRAEFIK_NAMESPACE} delete secret certificate >/dev/null || true
kubectl -n ${TRAEFIK_NAMESPACE} create secret tls certificate \
					--cert=../nginx/ssl/tls.crt \
					--key=../nginx/ssl/tls.key >/dev/null

if [[ "${UPDATE_MODE:-}" == "full" ]]; then
	echo -e "\033[32mUPDATE_MODE = 'full', restarting traefik deployment\033[0m"
	kubectl -n ${TRAEFIK_NAMESPACE} delete ingressroutes.traefik.io traefik-dashboard >/dev/null
	helm upgrade -n ${TRAEFIK_NAMESPACE} traefik traefik/traefik -f ../traefik/traefik-helm-values.yaml >/dev/null
	echo """
	Update of Traefik deployment and certificates completed successfuly!
	"""
else
	echo """
	Update of Traefik certificates completed successfuly!
	"""
fi

echo -e "\033[33mDont't forget to update VGW and MSE certificates\033[0m"