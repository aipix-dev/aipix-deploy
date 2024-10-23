#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh
source ./k8s-onprem/sources.sh

export PATH=$PATH:$HOME/minio-binaries/
kubectl create ns ${NS_MINIO}

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

# export MINIO_IP=$(kubectl -n ${NS_MINIO} get service/minio -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
export MINIO_IP=${K8S_API_ENDPOINT}
# MINIO_IP=$(kubectl -n ${TRAEFIK_NAMESPACE} get services/traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# MINIO_IP =$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}') # for GKE

mc alias set local http://${MINIO_IP}:30900 ${MINIO_USR} ${MINIO_PSW}
mc mb -p local/${MINIO_BACKEND_BUCKET_NAME}
mc mb -p local/${MINIO_BACKEND_BUCKET_NAME_PRIV}
mc mb -p local/${MINIO_PORTAL_BUCKET_NAME}
mc mb -p local/${MINIO_PORTAL_BUCKET_NAME_PRIV}
mc mb -p local/${MINIO_ANALYTICS_BUCKET_NAME}

cat <<EOF > /tmp/${MINIO_BACKEND_BUCKET_NAME}-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::${MINIO_BACKEND_BUCKET_NAME}/*"
            ]
        }
    ]
}
EOF

cat <<EOF > /tmp/${MINIO_BACKEND_BUCKET_NAME_PRIV}-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::${MINIO_BACKEND_BUCKET_NAME_PRIV}/*"
            ]
        }
    ]
}
EOF

cat <<EOF > /tmp/${MINIO_PORTAL_BUCKET_NAME}-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::${MINIO_PORTAL_BUCKET_NAME}/*"
            ]
        }
    ]
}
EOF

cat <<EOF > /tmp/${MINIO_PORTAL_BUCKET_NAME_PRIV}-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::${MINIO_PORTAL_BUCKET_NAME_PRIV}/*"
            ]
        }
    ]
}
EOF

cat <<EOF > /tmp/${MINIO_ANALYTICS_BUCKET_NAME}-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::${MINIO_ANALYTICS_BUCKET_NAME}/*"
            ]
        }
    ]
}
EOF

mc admin policy create local ${MINIO_BACKEND_BUCKET_NAME}-policy /tmp/${MINIO_BACKEND_BUCKET_NAME}-policy.json
mc admin policy create local ${MINIO_BACKEND_BUCKET_NAME_PRIV}-policy /tmp/${MINIO_BACKEND_BUCKET_NAME_PRIV}-policy.json
mc admin policy create local ${MINIO_PORTAL_BUCKET_NAME}-policy /tmp/${MINIO_PORTAL_BUCKET_NAME}-policy.json
mc admin policy create local ${MINIO_PORTAL_BUCKET_NAME_PRIV}-policy /tmp/${MINIO_PORTAL_BUCKET_NAME_PRIV}-policy.json
mc admin policy create local ${MINIO_ANALYTICS_BUCKET_NAME}-policy /tmp/${MINIO_ANALYTICS_BUCKET_NAME}-policy.json
mc admin user add local ${MINIO_BACKEND_BUCKET_NAME}-user ${MINIO_PSW}
mc admin user add local ${MINIO_BACKEND_BUCKET_NAME_PRIV}-user ${MINIO_PSW}
mc admin user add local ${MINIO_PORTAL_BUCKET_NAME}-user ${MINIO_PSW}
mc admin user add local ${MINIO_PORTAL_BUCKET_NAME_PRIV}-user ${MINIO_PSW}
mc admin user add local ${MINIO_ANALYTICS_BUCKET_NAME}-user ${MINIO_PSW}
mc admin user svcacct add local ${MINIO_BACKEND_BUCKET_NAME}-user --access-key ${MINIO_BACKEND_ACCESS_KEY} --secret-key ${MINIO_BACKEND_SECRET_KEY}
mc admin user svcacct add local ${MINIO_BACKEND_BUCKET_NAME_PRIV}-user --access-key ${MINIO_BACKEND_ACCESS_KEY_PRIV} --secret-key ${MINIO_BACKEND_SECRET_KEY_PRIV}
mc admin user svcacct add local ${MINIO_PORTAL_BUCKET_NAME}-user --access-key ${MINIO_PORTAL_ACCESS_KEY} --secret-key ${MINIO_PORTAL_SECRET_KEY}
mc admin user svcacct add local ${MINIO_PORTAL_BUCKET_NAME_PRIV}-user --access-key ${MINIO_PORTAL_ACCESS_KEY_PRIV} --secret-key ${MINIO_PORTAL_SECRET_KEY_PRIV}
mc admin user svcacct add local ${MINIO_ANALYTICS_BUCKET_NAME}-user --access-key ${MINIO_ANALYTICS_ACCESS_KEY} --secret-key ${MINIO_ANALYTICS_SECRET_KEY}
mc admin policy attach local ${MINIO_BACKEND_BUCKET_NAME}-policy --user ${MINIO_BACKEND_BUCKET_NAME}-user
mc admin policy attach local ${MINIO_BACKEND_BUCKET_NAME_PRIV}-policy --user ${MINIO_BACKEND_BUCKET_NAME_PRIV}-user
mc admin policy attach local ${MINIO_PORTAL_BUCKET_NAME}-policy --user ${MINIO_PORTAL_BUCKET_NAME}-user
mc admin policy attach local ${MINIO_PORTAL_BUCKET_NAME_PRIV}-policy --user ${MINIO_PORTAL_BUCKET_NAME_PRIV}-user
mc admin policy attach local ${MINIO_ANALYTICS_BUCKET_NAME}-policy --user ${MINIO_ANALYTICS_BUCKET_NAME}-user
mc anonymous set download local/${MINIO_BACKEND_BUCKET_NAME}
mc anonymous set download local/${MINIO_PORTAL_BUCKET_NAME}
mc anonymous set download local/${MINIO_ANALYTICS_BUCKET_NAME}
mc ilm rule add local/${MINIO_BACKEND_BUCKET_NAME}/archive --expire-days "1"
mc ilm rule add local/${MINIO_BACKEND_BUCKET_NAME_PRIV}/database_backups --expire-days "14"
mc ilm rule add local/${MINIO_ANALYTICS_BUCKET_NAME} --expire-days "2"


echo "
Deployment script completed successfuly!

Minio console can be reached with the following URL:
http://${K8S_API_ENDPOINT}:30090
https://${MINIO_CONSOLE_DOMAIN} (${MINIO_CONSOLE_DOMAIN} should be resolved on DNS-server)
"
