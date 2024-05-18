#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh
source ./k8s-onprem/sources.sh

VMS_IP=$(kubectl get service/nginx -n ${NS_VMS} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
ORCH_IP=$(kubectl get service/orchestrator -n ${NS_A} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
GRAFANA_IP=$(kubectl get service/grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo """
VMS URL for admins: https://${VMS_IP}/admin
VMS URL dor clients: https://${VMS_IP}/  
Mediaserver URL: https://${MS1_IP}:8080/cpanel/
Analytics Orchestrator URL: http://${ORCH_IP}/orch-admin/
Monitoring URL: http://${GRAFANA_IP}:3000
"""

