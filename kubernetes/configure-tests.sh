#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

# cp -n ../tests/variables.yaml.sample ../tests/variables.yaml
cp -n ../tests/env.example ../tests/.env
cp -n ../tests/rtsp-server-helm-values.yaml.template ../tests/rtsp-server-helm-values.yaml
cp -n ../tests/robot-tests-helm-values.yaml.template ../tests/robot-tests-helm-values.yaml
sed -i "s@example.com@${VMS_DOMAIN}@g" ../tests/.env
if [ ${ANALYTICS} == "yes" ]; then
	sed -i "s@IS_ANALYTIC=.*@IS_ANALYTIC=true@g" ../tests/.env
else
	sed -i "s@IS_ANALYTIC=.*@IS_ANALYTIC=false@g" ../tests/.env
fi

echo """

Tests configuration script completed successfuly!
"""
