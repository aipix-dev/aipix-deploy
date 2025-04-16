#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

update_secrets () {
	set -e
	kubectl delete secret download-aipix-ai --namespace=${NS_A} || true
	kubectl create secret docker-registry download-aipix-ai --namespace=${NS_A} \
                                                            --docker-server=https://download.aipix.ai:8443 \
                                                            --docker-username=${DOCKER_USERNAME} \
                                                            --docker-password=${DOCKER_PASSWORD}
}

update_analytics-worker () {
    set -e
    kubectl delete configmap analytics-worker-cm  --namespace=${NS_A} || true
    kubectl create configmap analytics-worker-cm  --namespace=${NS_A} --from-file=.env=../analytics/analytics-worker.conf
    TargetReplicas=$(kubectl get deployment analytics-worker --namespace=${NS_A} -o jsonpath='{.status.replicas}')
    kubectl -n ${NS_A} rollout restart deployment analytics-worker
    # Waiting for starting containers
    while true
    do
        if [[ $(kubectl get deployment analytics-worker -n ${NS_A} -o jsonpath='{.status.readyReplicas}') -ge ${TargetReplicas} ]]
        then break
        fi
        sleep 10
        echo "Waiting for starting ${TargetReplicas} analytics-worker PODs (max 5 minutes) ..."
    done
    sleep 10

}

update_orchestrator () {
	set -e
	kubectl delete configmap analytics-env --namespace=${NS_A} || true
	kubectl delete configmap a-licensing-yaml --namespace=${NS_A} || true
	kubectl delete configmap a-license-json --namespace=${NS_A} || true
	kubectl create configmap analytics-env --namespace=${NS_A} --from-file=../analytics/.env
	kubectl create configmap a-licensing-yaml --namespace=${NS_A} --from-file=../analytics/licensing.yaml
	kubectl create configmap a-license-json --namespace=${NS_A} --from-file=../analytics/license.json
	kubectl -n ${NS_A} rollout restart deployment orchestrator
    # Waiting for starting containers
    while true
    do
        if ([[ ${TYPE} == "prod" ]] || [[ $(kubectl get  deployment mysql-server -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]) && \
            [[ $(kubectl get deployment orchestrator -n ${NS_A} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]
        then break
        fi
        echo "Waiting for starting orchestrator and mysql container if presents (max 5 minutes) ..."
        sleep 10
    done
    sleep 10
    kubectl exec -n ${NS_A} deployment.apps/orchestrator -c django --  python manage.py seed
}

update_tarantool () {
	set -e
	kubectl -n ${NS_A} rollout restart deployment tarantool
}

update_vectorizator () {
	set -e
	kubectl -n ${NS_A} rollout restart deployment vectorizator
}

update_push1st () {
	set -e
	kubectl delete configmap push1st-orchestrator --namespace=${NS_VMS} || true
	kubectl create configmap push1st-orchestrator --namespace=${NS_VMS} --from-file=../push1st/orchestrator.yml --dry-run=client -o yaml | \
	sed -e "s@http://django:8000/api/events/@http://orchestrator.${NS_A}.svc/api/events/@g" | kubectl apply -f-
	kubectl -n ${NS_VMS} rollout restart deployment push1st
}

update_clickhouse () {
	set -e
	kubectl delete configmap clickhouse-orchestrator --namespace=${NS_A} || true
	kubectl delete configmap clickhouse-scheme --namespace=${NS_A} || true
	kubectl delete configmap clickhouse-timezone --namespace=${NS_A} || true
	kubectl delete configmap clickhouse-disable-logs --namespace=${NS_A} || true
	kubectl create configmap clickhouse-orchestrator --namespace=${NS_A} --from-file=../clickhouse/orchestrator.xml
	kubectl create configmap clickhouse-scheme --namespace=${NS_A} --from-file=../clickhouse/scheme.sql
	kubectl create configmap clickhouse-timezone --namespace=${NS_A} --from-file=../clickhouse/timezone.xml
	kubectl create configmap clickhouse-disable-logs --namespace=${NS_A} --from-file=../clickhouse/disable_logs.xml
	kubectl -n ${NS_A} rollout restart deployment clickhouse-server
}

update_metrics-pusher () {
	set -e
	kubectl delete configmap metrics-pusher-env --namespace=${NS_A} || true
	kubectl delete configmap telegraf-conf --namespace=${NS_A} || true
	kubectl create configmap metrics-pusher-env  --namespace=${NS_A}  --from-env-file=../analytics/metrics-pusher.env
	kubectl create configmap telegraf-conf  --namespace=${NS_A}  --from-file=../analytics/telegraf.conf
	kubectl -n ${NS_A} rollout restart deployment metrics-pusher
}

apply_manifests () {
	set -e
	../kustomize/deployments/${A_TEMPLATE}/update-kustomization.sh
	kubectl apply -k ../kustomize/deployments/${A_TEMPLATE}
}
