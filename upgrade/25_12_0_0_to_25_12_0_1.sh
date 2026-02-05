#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

### Update monitoring
if [ ${MONITORING} == "yes" ]; then
	yq e '
	.scrapeConfigs = (
		.scrapeConfigs //
		{
			"kubernetes-nodes": {
			"tls_config": {
				"insecure_skip_verify": true
			}
			},
			"kubernetes-nodes-cadvisor": {
			"tls_config": {
				"insecure_skip_verify": true
			}
			}
		}
		)
		' -i ../monitoring/prometheus-values.yaml

	../kubernetes/configure-monitoring.sh
	../kubernetes/deploy-monitoring.sh
else
	echo "Monitoring is not installed, continue update"
fi

### Update VMS
../kubernetes/configure-vms.sh
../kubernetes/update-vms.sh

echo """
Upgrade script completed successfuly!

"""
