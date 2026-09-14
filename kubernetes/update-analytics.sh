#!/bin/bash -e
scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./update-analytics-funcs.sh

apply_manifests

# if [ ${TYPE} != "prod" ]; then
# 	update_push1st
# fi

update_secrets
update_tarantool
update_vectorizator
if [ ${TYPE} != "prod" ]; then
	update_clickhouse
fi
update_orchestrator
update_analytics-worker

if [ ${TYPE} != "prod" ]; then
	update_push1st
fi

if [ ${MONITORING} == "yes" ]; then
	update_metrics-pusher
fi

echo """
Analytics update script completed successfuly!

List of used images:
"""
../kubernetes/print-image-versions.sh ${NS_A}