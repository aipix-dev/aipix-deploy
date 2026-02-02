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
  echo -e "\033[0;31mvgw values are not set!!!\033[0m"
  echo "Use 'helm show values ${BRAND}/vgw >> ${VALUES}'"
  exit 1
fi

if [ ! -e "$VALUES" ]; then
  echo -e "\033[0;31m ${VALUES} doesn't exist !!!\033[0m"
  exit 1
fi

kubectl delete secret vgw-certificate -n ${NS_VMS} || true
kubectl create secret tls vgw-certificate -n ${NS_VMS} --cert=../vgw/tls.crt --key=../vgw/tls.key

yq -V
if [[ $? -ne 0 ]]; then
  echo "\033[0;31mPlease install yq\033[0m"
  exit 1
fi

ver=$(yq '.version' ${VALUES})
if [[ $ver == 'null' ]]; then
  VERSION=""
else
  VERSION="--version $ver"
  echo "\033[0;33mUsing helm chart version $ver \033[0m"
fi

helm -n ${NS_VMS} upgrade -i -f "${VALUES}" vgw "${BRAND}/vgw" ${VERSION}
if [[ $? -ne 0 ]]; then
  echo "\033[0;31mChart installation failed\033[0m"
  exit 1
fi

echo """
VGW update script completed successfuly!
"""
