#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

# Backup MySQL database
kubectl exec --namespace=${NS_VMS} deployment.apps/cron -- apt update >/dev/null  #Remove in 25.03.0.0
kubectl exec --namespace=${NS_VMS} deployment.apps/cron -- apt install -y s3cmd >/dev/null  #Remove in 25.03.0.0
kubectl exec --namespace=${NS_VMS} deployment.apps/cron -- ./db_dump.sh


### Update Traefik
yq -i '.ports.logger={"port": 8109, "protocol": "UDP", "expose": {"default": true},"exposedPort": 8109}' ../traefik/traefik-helm-values.yaml
yq -i '.additionalArguments += "--entrypoints.logger.address=:8109/udp"' ../traefik/traefik-helm-values.yaml
../kubernetes/update-traefik-certs.sh

### Update VMS

# Update VGW
if [[ $(kubectl -n vsaas-vms get deployments.apps vgw) ]]; then
    ../kubernetes/update-vgw.sh
fi

# Update VMS
kubectl --namespace=${NS_VMS} delete deployment.apps/nginx
../kubernetes/configure-vms.sh
../kubernetes/update-vms.sh

# Update MSE
if [[ $(kubectl get ns | grep ${NS_MS}) ]]; then
    ../kubernetes/update-mse.sh
fi

# Update Analytics
if [ ${ANALYTICS} == "yes" ]; then
    ../kubernetes/configure-analytics.sh
    ../kubernetes/update-analytics.sh
fi

# Update monitoring
if [ ${MONITORING} == "yes" ]; then
    if [ ${TYPE} == "prod" ]; then
        export S3_PORT_INTERNAL=""
    else
        export S3_PORT_INTERNAL="9000"
    fi
    mc mb -p local/${MINIO_LOGS_BUCKET_NAME}
    cat <<EOF > /tmp/${MINIO_LOGS_BUCKET_NAME}-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::${MINIO_LOGS_BUCKET_NAME}/*"
            ]
        }
    ]
}
EOF
    mc admin policy create local ${MINIO_LOGS_BUCKET_NAME}-policy /tmp/${MINIO_LOGS_BUCKET_NAME}-policy.json
    mc admin user add local ${MINIO_LOGS_BUCKET_NAME}-user ${MINIO_PSW}
    mc admin user svcacct add local ${MINIO_LOGS_BUCKET_NAME}-user --access-key ${MINIO_LOGS_ACCESS_KEY} --secret-key ${MINIO_LOGS_SECRET_KEY}
    mc admin policy attach local ${MINIO_LOGS_BUCKET_NAME}-policy --user ${MINIO_LOGS_BUCKET_NAME}-user
    mc ilm rule add local/${MINIO_LOGS_BUCKET_NAME} --expire-days "3"

    rm ../monitoring/fluentbit-values.yaml ../monitoring/loki-values.yaml 
    cp ../monitoring/fluentbit-values.yaml.sample ../monitoring/fluentbit-values.yaml
    envsubst \
            < ../monitoring/loki-values.yaml.sample \
            > ../monitoring/loki-values.yaml

    helm -n monitoring template --debug fluent-bit fluent/fluent-bit --set testFramework.enabled=false -f ../monitoring/fluentbit-values.yaml --version 0.48.9 > ../kustomize/deployments/monitoring1/fluent-bit.yaml
    helm -n monitoring template --debug loki grafana/loki -f ../monitoring/loki-values.yaml --version 6.28.0 > ../kustomize/deployments/monitoring1/loki.yaml
    ../kustomize/deployments/monitoring1/update-kustomization.sh
    kubectl apply -k ../kustomize/deployments/monitoring1
    
    # deploy vsaas-logger
    kubectl create secret docker-registry download-aipix-ai --namespace=monitoring \
                                                            --docker-server=https://download.aipix.ai:8443 \
                                                            --docker-username=${DOCKER_USERNAME} \
                                                            --docker-password=${DOCKER_PASSWORD}
    ../kubernetes/configure-monitoring.sh
    ../kubernetes/deploy-monitoring.sh
    # helm -n monitoring upgrade -i vsaas-media-logger --set imagePullSecrets[0].name=download-aipix-ai aipix/vsaas-media-logger
fi

echo """
Upgrade script completed successfuly!

"""
