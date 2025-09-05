#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh
source ./k8s-onprem/sources.sh

PROMETHEUS_PORT=$(kubectl get service/prometheus-service --namespace=${NS_MONITORING} -o jsonpath='{.spec.ports[0].nodePort}')
INFLUX_PORT=$(kubectl get service/vsaas-influxdb2 --namespace=${NS_MONITORING} -o jsonpath='{.spec.ports[0].nodePort}')

echo """
VMS URL for admins: https://${VMS_DOMAIN}/admin
VMS URL dor clients: https://${VMS_DOMAIN}/
MINIO DOMAIN: https://${MINIO_CONSOLE_DOMAIN}
Analytics Orchestrator URL: https://${ANALYTICS_DOMAIN}/orch-admin/
Monitoring URL: https://${VMS_DOMAIN}/monitoring
Prometheus: http://${K8S_API_ENDPOINT}:${PROMETHEUS_PORT}
InflixDB: http://${K8S_API_ENDPOINT}:${INFLUX_PORT}
"""

