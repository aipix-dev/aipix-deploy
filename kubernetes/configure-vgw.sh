#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

BRAND=aipix
HELM_REPO="https://download.aipix.ai/repository/charts/"

helm repo rm "${BRAND}" || true
helm repo add "${BRAND}" "${HELM_REPO}" --username "${DOCKER_USERNAME}" --password "${DOCKER_PASSWORD}"
helm repo update

helm show values ${BRAND}/vgw > ../vgw/values.yaml.sample
cp -n ../vgw/values.yaml.sample ../vgw/values.yaml

echo """

VGW configuration script completed successfuly!

"""
