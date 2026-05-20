#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

### Change default log channel to stdout for backend and controller
if [ ${MONITORING} == "no" ]; then
	sed -i "s@LOG_CHANNEL=.*@LOG_CHANNEL=stdout@g" ../vms-backend/environments/.env
	sed -i "s@LOG_CHANNEL=.*@LOG_CHANNEL=stdout@g" ../controller/environments/.env
fi

### Update VMS
../kubernetes/configure-vms.sh
../kubernetes/update-vms-skip-redis-mysql-push1st-beanstalkd.sh

### Update VGW
if [ ${VGW} == "yes" ]; then
	../kubernetes/configure-vgw.sh
	../kubernetes/update-vgw.sh
else
	echo "VGW is not installed, continue update"
fi

### Update Analytics
if [ ${ANALYTICS} == "yes" ]; then
	../kubernetes/configure-analytics.sh
	../kubernetes/update-analytics.sh
else
	echo "Analytics is not installed, continue update"
fi

### Update MSE
if [[ $(kubectl get ns | grep ${NS_MS}) ]]; then
	../kubernetes/update-mse.sh
else
	echo "MSE is not installed in k8s, continue update"
fi

### Update monitoring
if [ ${MONITORING} == "yes" ]; then
	cat <<'EOF' >/tmp/prometheus-values.yaml
- job_name: "media-server"
  scheme: https
  metrics_path: /metrics
  tls_config:
    insecure_skip_verify: true
  static_configs:
    - targets: ["mse.example.com:9665"]
EOF
	yq -i '.extraScrapeConfigs += load_str("/tmp/prometheus-values.yaml")' ../monitoring/prometheus-values.yaml
	rm /tmp/prometheus-values.yaml
	../kubernetes/configure-monitoring.sh
	../kubernetes/deploy-monitoring.sh
else
	echo "Monitoring is not installed, continue update"
fi

echo """
Upgrade script completed successfuly!

"""
