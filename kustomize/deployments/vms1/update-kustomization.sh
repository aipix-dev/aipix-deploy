#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../../../kubernetes/sources.sh

if [ ${ANALYTICS} == "yes" ]; then
    export ADD_RESOURCE1="- ../../apps/vms/analytics"
    export ADD_COMPONENT1="- ../../components/vms/push1st-orch-app
- ../../components/vms/analytics-env"
fi

if [ ${VMS_LIC_OFFLINE} == "yes" ]; then
    export ADD_COMPONENT2="- ../../components/vms/vms-backend-license"
fi

if [ ${PORTAL} == "yes" ]; then
    export ADD_COMPONENT3="- ../../components/middlewares/strip-prefixes-portal"
    export ADD_RESOURCE2="- ../../apps/vms/portal
- ../../apps/vms/portal-landing"
fi

if [[ ${BACKEND_STORAGE_TYPE} == "s3" ]]; then
    export ADD_PATCH1="$(cat ./patch-backends-for-s3-storage.yaml.kustomize 2>/dev/null)"
fi

export CUSTOM_IMAGES="$(cat ./custom-images.d/*.yaml 2>/dev/null)"
export CUSTOM_PATCHES="$(cat ./custom-patches.d/custom-patches.yaml 2>/dev/null)"

files=$(ls | grep ".*.template$")
for file in $files; do
	new_file=$(echo $file | sed -e 's/\.template//g')
	envsubst \
	    < ./${file} \
	    > ./${new_file}
done
