#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

BRAND=aipix
HELM_REPO="https://download.aipix.ai/repository/charts/"

version_gt() {
  local v1="$1" v2="$2"
  if [[ "$v1" == "$v2" ]]; then return 1; fi
  if [[ "$(printf '%s\n%s\n' "$v1" "$v2" | sort -V | tail -n1)" == "$v1" ]]; then
    return 0
  else
    return 1
  fi
}

helm repo rm "${BRAND}" || true
helm repo add "${BRAND}" "${HELM_REPO}" --username "${DOCKER_USERNAME}" --password "${DOCKER_PASSWORD}"
helm repo update ${BRAND}

helm show values ${BRAND}/vgw >../vgw/values.yaml.sample
if [[ ! -f ../vgw/values.yaml ]]; then
  cp ../vgw/values.yaml.sample ../vgw/values.yaml
fi

vgw_version=$(yq eval '.version' ../vgw/values.yaml)

if version_gt ${vgw_version} "25.12.2"; then
  sed -i 's/KAM_PROM_PORT/KAM_API_PORT/g' ../vgw/values.yaml
  echo "vgw settings updated for the new chart version"
fi

echo """

VGW configuration script completed successfuly!

"""
