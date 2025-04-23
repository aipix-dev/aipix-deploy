#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

kubectl create ns ${NS_MS}


kubectl create secret docker-registry download-aipix-ai --namespace=${NS_MS} \
														--docker-server=https://download.aipix.ai:8443 \
														--docker-username=${DOCKER_USERNAME} \
														--docker-password=${DOCKER_PASSWORD}
kubectl create secret generic mse-key-pem --namespace=${NS_MS} --from-file=../mse/key.pem
kubectl create secret generic mse-cert-pem --namespace=${NS_MS} --from-file=../mse/cert.pem


#Deploying MSE
../kustomize/deployments/${MSE_TEMPLATE}/update-kustomization.sh || exit 1
kubectl apply -k ../kustomize/deployments/${MSE_TEMPLATE}


echo """
MSE deployment script completed successfuly!
"""
