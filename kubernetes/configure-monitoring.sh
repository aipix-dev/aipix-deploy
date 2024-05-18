#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

git -C ../kustomize/apps/monitoring clone https://github.com/techiescamp/kubernetes-prometheus.git || true
git -C ../kustomize/apps/monitoring clone https://github.com/devopscube/kube-state-metrics-configs.git || true
git -C ../kustomize/apps/monitoring clone https://github.com/bibinwilson/kubernetes-node-exporter.git || true
git -C ../kustomize/apps/monitoring clone https://github.com/bibinwilson/kubernetes-grafana.git || true
helm repo add influxdata https://helm.influxdata.com/
helm repo add fluent https://fluent.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

mkdir -p ../kustomize/apps/monitoring/kubernetes-influxdb
envsubst < ../monitoring/influxdb-values.yaml.sample > ../monitoring/influxdb-values.yaml
helm template vsaas --debug influxdata/influxdb2 -f ../monitoring/influxdb-values.yaml > ../kustomize/apps/monitoring/kubernetes-influxdb/influxdb.yaml

cat << EOF > ../kustomize/apps/monitoring/kubernetes-prometheus/kustomization.yaml
resources:
- clusterRole.yaml
- prometheus-deployment.yaml
- prometheus-service.yaml
EOF

cat << EOF > ../kustomize/apps/monitoring/kube-state-metrics-configs/kustomization.yaml
resources:
- cluster-role.yaml
- cluster-role-binding.yaml
- service-account.yaml
- deployment.yaml
- service.yaml
EOF

cat << EOF > ../kustomize/apps/monitoring/kubernetes-node-exporter/kustomization.yaml
resources:
- daemonset.yaml
- service.yaml
EOF

cat << EOF > ../kustomize/apps/monitoring/kubernetes-grafana/kustomization.yaml
resources:
- deployment.yaml
- service.yaml
EOF

cat << EOF > ../kustomize/apps/monitoring/kubernetes-influxdb/kustomization.yaml
resources:
- influxdb.yaml
EOF

cp -n ../monitoring/prometheus-config-map.yaml.sample ../monitoring/prometheus-config-map.yaml
cp ../monitoring/prometheus-config-map.yaml ../kustomize/deployments/monitoring1/
envsubst < ../monitoring/grafana-datasources-config.yaml.sample  > ../monitoring/grafana-datasources-config.yaml
cp ../monitoring/grafana-datasources-config.yaml ../kustomize/deployments/monitoring1/
cp -n ../monitoring/grafana-dashboards-config.yaml.sample ../monitoring/grafana-dashboards-config.yaml

# Configure logging
## Configure fluent-bit
cp -n ../monitoring/fluentbit-values.yaml.sample ../monitoring/fluentbit-values.yaml
helm -n monitoring template --debug fluent-bit fluent/fluent-bit --set testFramework.enabled=false -f ../monitoring/fluentbit-values.yaml > ../kustomize/deployments/monitoring1/fluent-bit.yaml
cp  ../monitoring/syslog-service.yaml ../kustomize/deployments/monitoring1/

## Configure loki
cp -n ../monitoring/loki-values.yaml.sample ../monitoring/loki-values.yaml
helm -n monitoring template --debug loki grafana/loki -f ../monitoring/loki-values.yaml --version 5.47.2 > ../kustomize/deployments/monitoring1/loki.yaml

echo """

Configurations script is finished successfuly!

"""
