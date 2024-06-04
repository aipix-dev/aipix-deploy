#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh
source ./k8s-onprem/sources.sh

./configure-mse.sh ${MS1_IP}
./configure-mse.sh ${MS1_IP} $(echo ${USER}) configure

kubectl delete secret download-aipix-ai --namespace=${NS_MS} | true
kubectl create secret docker-registry download-aipix-ai --namespace=${NS_MS} \
                                                        --docker-server=https://download.aipix.ai:8443 \
                                                        --docker-username=${DOCKER_USERNAME} \
                                                        --docker-password=${DOCKER_PASSWORD}
kubectl delete secret mse-key-pem --namespace=${NS_MS} | true
kubectl create secret generic mse-key-pem --namespace=${NS_MS} --from-file=../mse/key.pem
kubectl delete secret mse-cert-pem --namespace=${NS_MS} | true
kubectl create secret generic mse-cert-pem --namespace=${NS_MS} --from-file=../mse/cert.pem

#Deploying MSE
../kustomize/deployments/${MSE_TEMPLATE}/update-kustomization.sh || exit 1
kubectl apply -k ../kustomize/deployments/${MSE_TEMPLATE}
kubectl --namespace=${NS_MS} rollout restart daemonset mse 

echo """
Deployment script completed successfuly!
"""
