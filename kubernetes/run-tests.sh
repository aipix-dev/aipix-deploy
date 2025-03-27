#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh
export TEST_NS="testing"
export REPO_NAME="aipix"
export REPO_URL="https://download.aipix.ai/repository/charts/"

./configure-tests.sh

# Deploy RTSP-server
kubectl create ns ${TEST_NS} || true

kubectl delete secret download-aipix-ai --namespace=${TEST_NS} || true
kubectl create secret docker-registry download-aipix-ai --namespace=${TEST_NS} \
                                                        --docker-server=https://download.aipix.ai:8443 \
                                                        --docker-username=${DOCKER_USERNAME} \
                                                        --docker-password=${DOCKER_PASSWORD}

kubectl delete configmap robot-tests --namespace=${TEST_NS} || true
kubectl create configmap robot-tests --namespace=${TEST_NS} --from-file=../tests/variables.yaml

helm uninstall --namespace=${TEST_NS} rtsp-server || true
helm uninstall --namespace=${TEST_NS} robot-tests || true

helm repo rm ${REPO_NAME} || true
helm repo add ${REPO_NAME} ${REPO_URL} --username "${DOCKER_USERNAME}" --password "${DOCKER_PASSWORD}"
helm repo update
helm install --namespace=${TEST_NS} rtsp-server ${REPO_NAME}/rtsp-server -f ../tests/rtsp-server-helm-values.yaml >/dev/null
helm install --namespace=${TEST_NS} robot-tests ${REPO_NAME}/robot-tests -f ../tests/robot-tests-helm-values.yaml >/dev/null

while true
do
    if [[ $(kubectl get deployment rtsp-server -n ${TEST_NS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]] && \
        [[ $(kubectl get jobs.batch robot-tests -n ${TEST_NS} -o jsonpath='{.status.active}') -ge 1 ]]
        then break
    fi
    sleep 5
    echo "Waiting for starting containers ..."
done
sleep 5

echo """
Tests are started

"""
