#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

### Update VMS

# Configure VMS
../kubernetes/configure-vms.sh

if [ ${WB} == "yes" ]; then
    kubectl create configmap integration-wb-env --namespace=${NS_VMS} --from-env-file=../integration-wb/environments/.env
    # Deploying WB
    ../kustomize/deployments/${VMS_TEMPLATE}/update-kustomization.sh || exit 1
    kubectl apply -k ../kustomize/deployments/${VMS_TEMPLATE}

    echo "WB manifests are applied !"
    sleep 10
    while true
	do
		if [[ $(kubectl get deployment integration-wb -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]
		then break
		fi
		sleep 5
		echo "Waiting for starting integration-wb container ..."
	done
    sleep 10
    echo -e "\033[32mStart WB migrations\033[0m"
	kubectl -n ${NS_VMS} exec deployment.apps/integration-wb -- ./scripts/create_db.sh
	kubectl -n ${NS_VMS} exec deployment.apps/integration-wb -- ./scripts/start.sh
	echo -e "\033[32mEnd WB migrations\033[0m"
fi

# Update VMS
../kubernetes/update-vms.sh

### Update Analytics
if [ ${ANALYTICS} == "yes" ]; then
    ../kubernetes/configure-analytics.sh
    ../kubernetes/update-analytics.sh
else
    echo "Analytics is not installed, continue update"
fi

### Update MSE
if [[ $(kubectl get ns | grep ${NS_MS}) ]]; then
    MS_TYPE="vsaas"
    cp ../mse/server.json.${MS1_IP}.${MS_TYPE} ../mse/server.json.${MS1_IP}.${MS_TYPE}.backup
    jq 'if .cview? == null then
        to_entries
        | map(
            if .key == "api" then
                [.,
                 {key:"cview", value:{
                   listen: "*:9665:/",
                   path: "/opt/vsaas/services/cview",
                   workers: 1,
                   poll: 1024,
                   ssl: true,
                   routes: ["streams", "server", "cluster"],
                   ip: 4
                 }}]
            else
                .
            end
          )
        | flatten
        | from_entries
        else
            .
        end' ../mse/server.json.${MS1_IP}.${MS_TYPE} > ../mse/server.json.tmp

    mv ../mse/server.json.tmp ../mse/server.json.${MS1_IP}.${MS_TYPE}
    ../kubernetes/update-mse.sh
else
    echo "MSE is not installed in k8s, continue update"
fi

echo """
Upgrade script completed successfuly!

"""