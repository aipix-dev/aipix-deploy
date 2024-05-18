#!/bin/bash -e
scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./update-analytics-funcs.sh

apply_manifests

update_push1st
update_secrets
update_tarantool
update_vectorizator
update_clickhouse
update_orchestrator
update_analytics-worker

if [ ${MONITORING} == "yes" ]; then
  update_metrics-pusher
fi

ORCH_IP=$(kubectl get service/orchestrator -n ${NS_A} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo """
Update script completed successfuly!

Access your ORCHESTRATOR with the following URL:
http://${ORCH_IP}/orch-admin/
https://${ANALYTICS_DOMAIN}/orch-admin/ (${ANALYTICS_DOMAIN} should be resolved on DNS-server)
"""