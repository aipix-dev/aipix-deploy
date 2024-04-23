#!/bin/bash -e

source ./sources.sh

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
PROMETHEUS_IP=$(kubectl get service/prometheus-service -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
GRAFANA_IP=$(kubectl get service/grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
INFLUX_IP=$(kubectl get service/vsaas-influxdb2 -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
#INFLUX_PSW=$(kubectl -n monitoring get secrets vsaas-influxdb2-auth -o=jsonpath='{.data.admin-password}' | base64 --decode)
#INFLUX_TOKEN=$(kubectl -n monitoring get secrets vsaas-influxdb2-auth -o=jsonpath='{.data.admin-token}' | base64 --decode)

echo "
Installations of monitoring components is finished !

URL to access Prometheus is
http://${PROMETHEUS_IP}:8080

URL to access InfluxDB is
http://${INFLUX_IP}
user: ${INFLUX_USR}
pass: ${INFLUX_PSW}
token: ${INFLUX_TOKEN}
keep your credentials in safe place !

URL to access Grafana is
http://${GRAFANA_IP}:3000
https://${VMS_DOMAIN}/monitoring
Default credentials are admin/admin.
Replace them during first login.
"
