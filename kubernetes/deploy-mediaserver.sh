#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

kubectl create ns ${NS_MS}


kubectl create secret docker-registry download-aipix-ai --namespace=${NS_MS} \
                                                        --docker-server=https://download.aipix.ai:8443 \
                                                        --docker-username=${DOCKER_USERNAME} \
                                                        --docker-password=${DOCKER_PASSWORD}
kubectl create secret generic ms-key-pem --namespace=${NS_MS} --from-file=../mediaserver/key.pem
kubectl create secret generic ms-cert-pem --namespace=${NS_MS} --from-file=../mediaserver/cert.pem


#Deploying mediaserver
../kustomize/deployments/${MS_TEMPLATE}/update-kustomization.sh || exit 1
kubectl apply -k ../kustomize/deployments/${MS_TEMPLATE}


echo """
Deployment script completed successfuly!
"""
