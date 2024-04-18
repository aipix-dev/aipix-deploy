#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

if [ ${ANALYTICS} != "yes" ]; then
  echo 'Variable ANALYTICS is not set to "yes". Exiting ...'
  exit 1
fi

kubectl create ns ${NS_A} || true


kubectl create secret docker-registry download-aipix-ai --namespace=${NS_A} --docker-server=https://download.aipix.ai:8443  --docker-username=reader --docker-password=reader1
kubectl create configmap analytics-env --namespace=${NS_A} --from-file=../analytics/.env
kubectl create configmap a-licensing-yaml --namespace=${NS_A} --from-file=../analytics/licensing.yaml
kubectl create configmap a-license-json --namespace=${NS_A} --from-file=../analytics/license.json
kubectl create configmap clickhouse-orchestrator --namespace=${NS_A} --from-file=../clickhouse/orchestrator.xml
kubectl create configmap clickhouse-scheme --namespace=${NS_A} --from-file=../clickhouse/scheme.sql
kubectl create configmap clickhouse-timezone --namespace=${NS_A} --from-file=../clickhouse/timezone.xml
kubectl create configmap clickhouse-disable-logs --namespace=${NS_A} --from-file=../clickhouse/disable_logs.xml
kubectl create configmap push1st-orchestrator --namespace=${NS_VMS} --from-file=../push1st/orchestrator.yml --dry-run=client -o yaml | \
	sed -e "s@http://django:8000/api/events/@http://orchestrator.${NS_A}.svc/api/events/@g" | kubectl apply -f-
kubectl create configmap analytics-worker-cm  --namespace=${NS_A} --from-file=.env=../analytics/analytics-worker.conf

if [ ${MONITORING} == "yes" ]; then
  kubectl create configmap metrics-pusher-env  --namespace=${NS_A}  --from-env-file=../analytics/metrics-pusher.env
  kubectl create configmap telegraf-conf  --namespace=${NS_A}  --from-file=../analytics/telegraf.conf
fi

#Deploying orchestrator and analytics-worker
../kustomize/deployments/${A_TEMPLATE}/update-kustomization.sh || exit 1
kubectl apply -k ../kustomize/deployments/${A_TEMPLATE}


# Waiting for starting containers
wait_period=0
while true
do
    wait_period=$(($wait_period+10))
    if [ $wait_period -gt 300 ];then
       echo "The script ran for 5 minutes to start containers, exiting now.."
       exit 1
    else
       if [[ $(kubectl get  deployment mysql-server -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]] && \
          [[ $(kubectl get  deployment orchestrator -n ${NS_A} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]
       then break
       fi
       echo "Waiting for starting orchestrator and mysql containers ..."
       sleep 10
    fi
done
sleep 10

CREATE_DATABASE="CREATE DATABASE IF NOT EXISTS analytics character set 'utf8mb4' collate 'utf8mb4_unicode_ci';"
CREATE_USER="CREATE USER IF NOT EXISTS 'orchestrator'@'%' IDENTIFIED BY '456redko';"
GRANT_PRIVILEGES="GRANT ALL PRIVILEGES ON analytics.* TO 'orchestrator'@'%';FLUSH PRIVILEGES;"
kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysql --protocol=TCP -u root -pmysql --execute="${CREATE_DATABASE}"
kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysql --protocol=TCP -u root -pmysql --execute="${CREATE_USER}"
kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysql --protocol=TCP -u root -pmysql --execute="${GRANT_PRIVILEGES}"
sleep 10
kubectl exec -n ${NS_A} deployment.apps/orchestrator -c django --  python manage.py seed

kubectl -n ${NS_A} annotate service analytics-worker prometheus.io/port="8081"
kubectl -n ${NS_A} annotate service analytics-worker prometheus.io/scrape="true"

ORCH_IP=$(kubectl get service/orchestrator -n ${NS_A} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo """

Deployment script is finished successfuly!
Access your ORCHESTRATOR with the following URL:
http://${ORCH_IP}/orch-admin/
https://${ANALYTICS_DOMAIN}/orch-admin/ (${ANALYTICS_DOMAIN} should be resolved on DNS-server)

"""
