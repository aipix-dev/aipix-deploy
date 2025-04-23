#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../../../kubernetes/sources.sh


if [ ${MONITORING} == "yes" ]; then
    export ADD_RESOURCE1="- ../../apps/analytics/metrics-pusher"
fi

export CUSTOM_IMAGES="$(cat ./custom-images.d/*.yaml 2>/dev/null)"
export CUSTOM_PATCHES="$(cat ./custom-patches.d/custom-patches.yaml 2>/dev/null)"
export CUSTOM_RESOURCES="$(cat ./custom-resources.d/custom-resources.yaml 2>/dev/null)"
export patch='$patch'

files=$(ls | grep ".*.template$")
for file in $files; do
	new_file=$(echo $file | sed -e 's/\.template//g')
	envsubst \
	    < ./${file} \
	    > ./${new_file}
done
