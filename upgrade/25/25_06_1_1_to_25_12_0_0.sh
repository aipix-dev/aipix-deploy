#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

# Delete PUSH_ERRORS_MONITORING_ENDPOINT env from ../analytics/analytics-worker-env file
sed -i '/^PUSH_ERRORS_MONITORING_ENDPOINT=/d' ../analytics/analytics-worker-env

### Update monitoring
if [ ${MONITORING} == "yes" ]; then

	echo "Delete old loki deployment"
	kubectl -n ${NS_MONITORING} delete ServiceAccount loki
	kubectl -n ${NS_MONITORING} delete ClusterRole loki-clusterrole
	kubectl -n ${NS_MONITORING} delete ClusterRoleBinding loki-clusterrolebinding
	kubectl -n ${NS_MONITORING} delete ConfigMap loki
	kubectl -n ${NS_MONITORING} delete ConfigMap loki-gateway
	kubectl -n ${NS_MONITORING} delete ConfigMap loki-runtime
	kubectl -n ${NS_MONITORING} delete Service loki
	kubectl -n ${NS_MONITORING} delete Service loki-chunks-cache
	kubectl -n ${NS_MONITORING} delete Service loki-gateway
	kubectl -n ${NS_MONITORING} delete Service loki-headless
	kubectl -n ${NS_MONITORING} delete Service loki-memberlist
	kubectl -n ${NS_MONITORING} delete Service loki-results-cache
	kubectl -n ${NS_MONITORING} delete Deployment loki-gateway
	kubectl -n ${NS_MONITORING} delete StatefulSet loki
	kubectl -n ${NS_MONITORING} delete StatefulSet loki-chunks-cache
	kubectl -n ${NS_MONITORING} delete StatefulSet loki-results-cache
	kubectl -n ${NS_MONITORING} delete PodDisruptionBudget loki-memcached-chunks-cache
	kubectl -n ${NS_MONITORING} delete PodDisruptionBudget loki-memcached-results-cache

	../kubernetes/configure-monitoring.sh
	../kubernetes/deploy-monitoring.sh
else
	echo "Monitoring is not installed, continue update"
fi

### Update VMS
../kubernetes/configure-vms.sh
../kubernetes/update-vms.sh

### Update VGW
if [ ${VGW} == "yes" ]; then
	../kubernetes/configure-vgw.sh
	../kubernetes/update-vgw.sh
else
	echo "VGW is not installed, continue update"
fi

### Update Analytics
if [ ${ANALYTICS} == "yes" ]; then
	grep -q "licenseServerConnectionTimeout" ../analytics/licensing.yaml || sed -i '$a\licenseServerConnectionTimeout: 10' ../analytics/licensing.yaml
	../kubernetes/configure-analytics.sh
	../kubernetes/update-analytics.sh
else
	echo "Analytics is not installed, continue update"
fi

### Update MSE
if [[ $(kubectl get ns | grep ${NS_MS}) ]]; then
	MS_TYPE="vsaas"
	cp ../mse/server.json.${MS1_IP}.${MS_TYPE} ../mse/server.json.${MS1_IP}.${MS_TYPE}.backup
	jq 'to_entries
        | map(
            if .key == "cview" then
                {key: "webui", value: {
                    listen: "*:9665:/",
                    path: "/opt/vsaas/services/webui",
                    workers: 1,
                    poll: 1024,
                    ssl: true,
                    routes: ["streams", "server", "cluster"],
                    ip: 4
                }}
            else
                .
            end
        ) | flatten | from_entries' ../mse/server.json.${MS1_IP}.${MS_TYPE} >../mse/server.json.tmp

	jq 'if (.["#log"]?.file?.errpath? // .log.file.errpath?) == null then
        .log.file |= (to_entries | 
            map(if .key == "path" then 
                ., {key: "errpath", value: "/var/log/vsaas/media-server.err"} 
            else . end) | from_entries)
    else . end' ../mse/server.json.tmp >../mse/server.json.${MS1_IP}.${MS_TYPE}
	../kubernetes/update-mse.sh
else
	echo "MSE is not installed in k8s, continue update"
fi

echo """
Upgrade script completed successfuly!

"""
