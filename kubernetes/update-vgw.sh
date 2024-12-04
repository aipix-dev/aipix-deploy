#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

VALUES="../vgw/values.yaml"
BRAND=aipix
REPO="https://download.aipix.ai/repository/charts/"
REPO_USER=aipix
REPO_PASSWORD=aipix

helm repo rm "${BRAND}" || true
helm repo add "${BRAND}" "${REPO}"  --username "${REPO_USER}" --password "${REPO_PASSWORD}"
helm repo update

if [ -z "${VALUES}" ]; then
	echo -e "\033[0;31mvgw values are not set!!!"
	echo "Use deploy-vgw.sh <name_space> <values.yaml>"
	exit 1
fi

if [ ! -e "$VALUES" ]; then
	echo -e "\033[0;31m ${VALUES} doesn't exist !!!"
	exit 1
fi
echo "${VALUES}"
helm -n "${NS_VMS}" upgrade -i -f "${VALUES}" vgw "${BRAND}/vgw"
helm -n "${NS_VMS}" list -f vgw
