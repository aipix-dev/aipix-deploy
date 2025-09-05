#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"

BRAND=aipix
source ./sources.sh
if [ ${TYPE} != "prod" ]; then
	source ./k8s-onprem/sources.sh
fi

kubectl create ns ${NS_MONITORING} || true

kubectl delete secret download-aipix-ai --namespace=${NS_MONITORING} || true
kubectl create secret docker-registry download-aipix-ai --namespace=${NS_MONITORING} \
														--docker-server=https://download.aipix.ai:8443 \
														--docker-username=${DOCKER_USERNAME} \
														--docker-password=${DOCKER_PASSWORD}

# Create manifests
helm -n ${NS_MONITORING} template grafana grafana/grafana -f ../monitoring/grafana-values.yaml > ../kustomize/apps/monitoring/grafana/grafana.yaml
helm -n ${NS_MONITORING} template loki grafana/loki -f ../monitoring/loki-values.yaml --version 6.28.0 > ../kustomize/apps/monitoring/loki/loki.yaml
helm -n ${NS_MONITORING} template fluent-bit fluent/fluent-bit -f ../monitoring/fluentbit-values.yaml --version 0.48.9 > ../kustomize/apps/monitoring/fluent-bit/fluent-bit.yaml
helm -n ${NS_MONITORING} template influxdb influxdata/influxdb2 -f ../monitoring/influxdb-values.yaml > ../kustomize/apps/monitoring/influxdb/influxdb.yaml
helm -n ${NS_MONITORING} template prometheus prometheus-community/prometheus -f ../monitoring/prometheus-values.yaml > ../kustomize/apps/monitoring/prometheus/prometheus.yaml
helm -n ${NS_MONITORING} template mysql-exporter prometheus-community/prometheus-mysql-exporter -f ../monitoring/mysql-exporter-values.yaml > ../kustomize/apps/monitoring/prometheus/prometheus-mysql-exporter.yaml
helm -n ${NS_MONITORING} template node-exporter prometheus-community/prometheus-node-exporter -f ../monitoring/node-exporter-values.yaml > ../kustomize/apps/monitoring/prometheus/prometheus-node-exporter.yaml
helm -n ${NS_MONITORING} template redis-exporter prometheus-community/prometheus-redis-exporter -f ../monitoring/redis-exporter-values.yaml > ../kustomize/apps/monitoring/prometheus/prometheus-redis-exporter.yaml
helm -n ${NS_MONITORING} template kube-state-metrics prometheus-community/kube-state-metrics -f ../monitoring/kube-state-metrics-values.yaml > ../kustomize/apps/monitoring/prometheus/kube-state-metrics.yaml
helm -n ${NS_MONITORING} template vsaas-media-logger ${BRAND}/vsaas-media-logger -f ../monitoring/vsaas-media-logger.yaml > ../kustomize/apps/monitoring/media-logger/vsaas-media-logger.yaml



../kustomize/deployments/monitoring1/update-kustomization.sh
kubectl apply -k ../kustomize/deployments/monitoring1

sleep 5
PROMETHEUS_PORT=$(kubectl get service/prometheus-server --namespace=${NS_MONITORING} -o jsonpath='{.spec.ports[0].nodePort}')
GRAFANA_PORT=$(kubectl get service/grafana --namespace=${NS_MONITORING} -o jsonpath='{.spec.ports[0].nodePort}')
INFLUX_PORT=$(kubectl get service/influxdb-influxdb2 --namespace=${NS_MONITORING} -o jsonpath='{.spec.ports[0].nodePort}')

echo """
Monitoring deployment script completed successfuly!

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
"""
