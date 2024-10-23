#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh
source ./k8s-onprem/sources.sh

kubectl create ns monitoring || true

if [ ${PROVISION_DASHBOARDS} == "yes" ]; then
  kubectl -n monitoring delete cm grafana-dashboards > /dev/null 2>&1 || true 
  kubectl -n monitoring delete cm grafana-dashboards-config > /dev/null 2>&1 || true
  kubectl -n monitoring create cm grafana-dashboards --from-file ../monitoring/grafana-dashboards
  kubectl -n monitoring create cm grafana-dashboards-config --from-file ../monitoring/grafana-dashboards-config.yaml
fi

#copy config-maps 
cp ../monitoring/prometheus-config-map.yaml ../kustomize/deployments/monitoring1/
cp ../monitoring/grafana-datasources-config.yaml ../kustomize/deployments/monitoring1/

../kustomize/deployments/monitoring1/update-kustomization.sh
kubectl apply -k ../kustomize/deployments/monitoring1

sleep 5
# PROMETHEUS_IP=$(kubectl get service/prometheus-service -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# GRAFANA_IP=$(kubectl get service/grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# INFLUX_IP=$(kubectl get service/vsaas-influxdb2 -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
PROMETHEUS_PORT=$(kubectl get service/prometheus-service -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
GRAFANA_PORT=$(kubectl get service/grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
INFLUX_PORT=$(kubectl get service/vsaas-influxdb2 -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')

echo "
Installations of monitoring components is finished !

URL to access Prometheus is
http://${K8S_API_ENDPOINT}:${PROMETHEUS_PORT}

URL to access InfluxDB is
http://${K8S_API_ENDPOINT}:${INFLUX_PORT}
user: ${INFLUX_USR}
pass: ${INFLUX_PSW}
token: ${INFLUX_TOKEN}
keep your credentials in safe place !

URL to access Grafana is
http://${K8S_API_ENDPOINT}:${GRAFANA_PORT}
https://${VMS_DOMAIN}/monitoring
Default credentials are admin/admin.
Replace them during first login.
"
