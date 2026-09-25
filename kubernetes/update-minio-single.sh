#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh
source ./k8s-onprem/sources.sh

kubectl delete secret minio-secret --namespace=${NS_MINIO}
kubectl delete secret download-aipix-ai --namespace=${NS_MINIO} || true

kubectl create secret generic minio-secret --namespace=${NS_MINIO} --from-literal="username=${MINIO_USR}" --from-literal="password=${MINIO_PSW}"
kubectl create secret docker-registry download-aipix-ai --namespace=${NS_MINIO} \
	--docker-server=https://download.aipix.ai:8443 \
	--docker-username=${DOCKER_USERNAME} \
	--docker-password=${DOCKER_PASSWORD}

# Deploying Minio s3
../kustomize/deployments/${MINIO_TEMPLATE}/update-kustomization.sh || exit 1
kubectl apply -k ../kustomize/deployments/${MINIO_TEMPLATE}

echo "Minio manifests are applied !"
sleep 10

# Waiting for starting containers
wait_period=0
until [[ $(kubectl get deployments.apps minio -n ${NS_MINIO} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]; do
	echo "Waiting for starting minio container ..."
	sleep 10
	wait_period=$(($wait_period+10))
	if [ $wait_period -gt 300 ];then
		echo "The script ran for 5 minutes to start containers, exiting now.."
		exit 1
	fi
done

echo """
Minio-single update script completed successfuly!

Minio console can be reached with the following URL:
http://${K8S_API_ENDPOINT}:30090
https://${MINIO_CONSOLE_DOMAIN} (${MINIO_CONSOLE_DOMAIN} should be resolved on DNS-server)
"""
