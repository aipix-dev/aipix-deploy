#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh
source ./k8s-onprem/sources.sh

kubectl delete secret minio-secret -n ${NS_MINIO}
kubectl create secret generic minio-secret -n ${NS_MINIO} --from-literal="username=${MINIO_USR}" --from-literal="password=${MINIO_PSW}"

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

echo "
Update script completed successfuly!

Minio console can be reached with the following URL:
http://${K8S_API_ENDPOINT}:30090
https://${MINIO_CONSOLE_DOMAIN} (${MINIO_CONSOLE_DOMAIN} should be resolved on DNS-server)
"
