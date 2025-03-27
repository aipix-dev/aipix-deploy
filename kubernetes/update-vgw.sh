#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

VALUES="../vgw/values.yaml"
BRAND=aipix
HELM_REPO="https://download.aipix.ai/repository/charts/"

helm repo rm "${BRAND}" || true
helm repo add "${BRAND}" "${HELM_REPO}" --username "${DOCKER_USERNAME}" --password "${DOCKER_PASSWORD}"
helm repo update

if [ -z "${VALUES}" ]; then
	echo -e "\033[0;31mvgw values are not set!!!"
	echo "Use deploy-vgw.sh <name_space> <values.yaml>"
	exit 1
fi

if [ ! -e "$VALUES" ]; then
	echo -e "\033[0;31m ${VALUES} doesn't exist !!!\033[0m"
	exit 1
fi

kubectl delete secret vgw-certificate -n ${NS_VMS} || true
kubectl create secret tls vgw-certificate -n ${NS_VMS} --cert=../vgw/tls.crt --key=../vgw/tls.key

helm -n ${NS_VMS} upgrade -i -f "${VALUES}" vgw "${BRAND}/vgw"
helm -n ${NS_VMS} list -f vgw

echo """

VGW update script completed successfuly!
"""
