#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

BRAND=aipix
HELM_REPO="https://download.aipix.ai/repository/charts/"

# Add helm repos
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add influxdata https://helm.influxdata.com/
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

## Add aipix helm repo
helm repo rm "${BRAND}" || true
helm repo add "${BRAND}" "${HELM_REPO}" --username "${DOCKER_USERNAME}" --password "${DOCKER_PASSWORD}"


# Configure Grafana and Loki deployment
if [ ${TYPE} == "prod" ]; then
	export S3_PORT_INTERNAL=""
else
	export S3_PORT_INTERNAL=":9000"
fi
envsubst < ../monitoring/grafana-values.yaml.sample > ../monitoring/grafana-values.yaml
envsubst < ../monitoring/loki-values.yaml.sample > ../monitoring/loki-values.yaml

## Copy grafana dashboards to S3
if kubectl -n ${NS_MINIO} get services minio-1 > /dev/null 2>&1 ; then
    mc cp --recursive ../monitoring/grafana-dashboards/ minio-1/${MINIO_GRAFANA_BUCKET_NAME}/ || echo -e "\033[31mUnable to copy grafana dashboards to S3\033[0m"
else
	mc cp --recursive ../monitoring/grafana-dashboards/ local/${MINIO_GRAFANA_BUCKET_NAME}/ || echo -e "\033[31mUnable to copy grafana dashboards to S3\033[0m"
fi

# Configure logging
## Configure fluent-bit
cp -n ../monitoring/fluentbit-values.yaml.sample ../monitoring/fluentbit-values.yaml
# envsubst < ../monitoring/fluentbit-values.yaml.sample > ../monitoring/fluentbit-values.yaml

# Configure InfluxDB deployment
envsubst < ../monitoring/influxdb-values.yaml.sample > ../monitoring/influxdb-values.yaml

# Configure Prometheus deployment
## Configure Prometheus
envsubst < ../monitoring/prometheus-values.yaml.sample > ../monitoring/prometheus-values.yaml.tmp
cp -n ../monitoring/prometheus-values.yaml.tmp ../monitoring/prometheus-values.yaml
rm ../monitoring/prometheus-values.yaml.tmp

## Configure mysql-exporter
envsubst < ../monitoring/mysql-exporter-values.yaml.sample > ../monitoring/mysql-exporter-values.yaml.tmp
cp -n ../monitoring/mysql-exporter-values.yaml.tmp ../monitoring/mysql-exporter-values.yaml
rm ../monitoring/mysql-exporter-values.yaml.tmp

## Configure node-exporter
envsubst < ../monitoring/node-exporter-values.yaml.sample > ../monitoring/node-exporter-values.yaml

## Configure redis-exporter
envsubst < ../monitoring/redis-exporter-values.yaml.sample > ../monitoring/redis-exporter-values.yaml

## Configure kube-state-metrics
envsubst < ../monitoring/kube-state-metrics-values.yaml.sample > ../monitoring/kube-state-metrics-values.yaml

# Configure vsaas-media-logger
envsubst < ../monitoring/vsaas-media-logger.yaml.sample > ../monitoring/vsaas-media-logger.yaml
echo """

Monitoring configuration script completed successfuly!

"""
