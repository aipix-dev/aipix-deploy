#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

### Delete unused envs and resources
sed -i '/MSE_FORCE_GET_INFO/d' ../controller/environments/.env
sed -i '/MSE_DISABLE_STREAM_INFO/d' ../controller/environments/.env

### Update VMS
../kubernetes/configure-vms.sh
../kubernetes/update-vms.sh

### Update MSE
if [[ $(kubectl get ns | grep ${NS_MS}) ]]; then
	MS_TYPE="vsaas"
	cp ../mse/server.json.${MS1_IP}.${MS_TYPE} ../mse/server.json.${MS1_IP}.${MS_TYPE}.backup
	local_ip=$(ip addr show $(ip route | awk '/default/ {print $5; exit}') | awk '/inet / {split($2, a, "/");print a[1]; exit}')
	if [[ -z "$local_ip" ]]; then
		echo "WARNING: Failed to detect local IPv4 address. Use loopback" >&2
		local_ip='127.0.0.1'
	fi
	jq -e --arg ip "$local_ip" '
        . * {"dns": {"workers": 1, "poll": 64},"dvr": {"workers": 6,"poll": 1024}}
		| .camera //= {"workers": .rtsp.workers, "poll": 1024}
		| .ip //=$ip
		| .rtsp.workers = 6
		| del(.storage.localfs)
		| del(."#coroutine")
		| del(."gc")
		| .storage["localfs/storage"] = {
			"max-io-events": 1024,
			"writers": 4,
			"readers": 2,
			"max-read-events": 4096,
			"gc": {
				"timestart": "02:00:00",
				"limit": "5h",
				"period": "1d",
				"max-age": "31d"
			}
			}
		| .storage["#s3/my-bucket"] = {
			"endpoint": "https://s3.amazonaws.com:443",
			"access-key": "XXX",
			"secret-key": "XXX",
			"region": "us-east-1",
			"tls-verify": true,
			"cache-dir": "/tmp/vsaas/s3cache",
			"cache-size": "1G",
			"staging-dir": "/tmp/vsaas/s3staging",
			"staging-size": "100G",
			"max-connections": 64,
			"max-retry-chunks": 1,
			"max-io-events": 1024,
			"writers": 4,
			"readers": 2
		}
	' ../mse/server.json.${MS1_IP}.${MS_TYPE} >../mse/server.json.tmp && \
	jq -e 'type == "object"' "../mse/server.json.tmp" > /dev/null && \
    mv ../mse/server.json.tmp ../mse/server.json.${MS1_IP}.${MS_TYPE}
	../kubernetes/update-mse.sh
else
	echo "MSE is not installed in k8s, continue update"
fi

### Update monitoring
if [ ${MONITORING} == "yes" ]; then
	../kubernetes/configure-monitoring.sh
	../kubernetes/deploy-monitoring.sh
else
	echo "Monitoring is not installed, continue update"
fi

echo """
Upgrade script completed successfuly!

"""