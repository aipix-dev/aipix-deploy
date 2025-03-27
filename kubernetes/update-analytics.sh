#!/bin/bash -e
scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./update-analytics-funcs.sh

apply_manifests

update_push1st
update_secrets
update_tarantool
update_vectorizator
if [ ${TYPE} != "prod" ]; then
	update_clickhouse
fi
update_orchestrator
update_analytics-worker

if [ ${MONITORING} == "yes" ]; then
	update_metrics-pusher
fi

echo """
Analytics update script completed successfuly!

Access your ORCHESTRATOR with the following URL:
https://${ANALYTICS_DOMAIN}/orch-admin/ (${ANALYTICS_DOMAIN} should be resolved on DNS-server)
"""
