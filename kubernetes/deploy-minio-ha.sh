#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

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
until [[ $(kubectl get deployments.apps minio-1 -n ${NS_MINIO} -o jsonpath='{.status.readyReplicas}') -ge 1 ]] && \
	[[ $(kubectl get deployments.apps minio-2 -n ${NS_MINIO} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]; do
  echo "Waiting for starting minio container ..."
  sleep 10
  wait_period=$(($wait_period+10))
  if [ $wait_period -gt 300 ];then
     echo "The script ran for 5 minutes to start containers, exiting now.."
     exit 1
  fi
done

export MINIO_IP1=$(kubectl -n ${NS_MINIO} get service/minio-1 -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
export MINIO_IP2=$(kubectl -n ${NS_MINIO} get service/minio-2 -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')

#MINIO_IP=${K8S_API_ENDPOINT}
# MINIO_IP=$(kubectl -n ${TRAEFIK_NAMESPACE} get services/traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

mc alias set minio-1 http://${MINIO_IP1}:9000 ${MINIO_USR} ${MINIO_PSW}
mc alias set minio-2 http://${MINIO_IP2}:9000 ${MINIO_USR} ${MINIO_PSW}
mc mb -p minio-1/${MINIO_BACKEND_BUCKET_NAME}
mc mb -p minio-2/${MINIO_BACKEND_BUCKET_NAME}
mc mb -p minio-1/${MINIO_BACKEND_BUCKET_NAME_PRIV}
mc mb -p minio-2/${MINIO_BACKEND_BUCKET_NAME_PRIV}
mc mb -p minio-1/${MINIO_PORTAL_BUCKET_NAME}
mc mb -p minio-2/${MINIO_PORTAL_BUCKET_NAME}
mc mb -p minio-1/${MINIO_PORTAL_BUCKET_NAME_PRIV}
mc mb -p minio-2/${MINIO_PORTAL_BUCKET_NAME_PRIV}
mc mb -p minio-1/${MINIO_ANALYTICS_BUCKET_NAME}
mc mb -p minio-2/${MINIO_ANALYTICS_BUCKET_NAME}

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

mc admin policy create minio-1 ${MINIO_BACKEND_BUCKET_NAME}-policy /tmp/${MINIO_BACKEND_BUCKET_NAME}-policy.json
mc admin policy create minio-1 ${MINIO_BACKEND_BUCKET_NAME_PRIV}-policy /tmp/${MINIO_BACKEND_BUCKET_NAME_PRIV}-policy.json
mc admin policy create minio-1 ${MINIO_PORTAL_BUCKET_NAME}-policy /tmp/${MINIO_PORTAL_BUCKET_NAME}-policy.json
mc admin policy create minio-1 ${MINIO_PORTAL_BUCKET_NAME_PRIV}-policy /tmp/${MINIO_PORTAL_BUCKET_NAME_PRIV}-policy.json
mc admin policy create minio-1 ${MINIO_ANALYTICS_BUCKET_NAME}-policy /tmp/${MINIO_ANALYTICS_BUCKET_NAME}-policy.json
mc admin user add minio-1 ${MINIO_BACKEND_BUCKET_NAME}-user ${MINIO_PSW}
mc admin user add minio-1 ${MINIO_BACKEND_BUCKET_NAME_PRIV}-user ${MINIO_PSW}
mc admin user add minio-1 ${MINIO_PORTAL_BUCKET_NAME}-user ${MINIO_PSW}
mc admin user add minio-1 ${MINIO_PORTAL_BUCKET_NAME_PRIV}-user ${MINIO_PSW}
mc admin user add minio-1 ${MINIO_ANALYTICS_BUCKET_NAME}-user ${MINIO_PSW}
mc admin user svcacct add minio-1 ${MINIO_BACKEND_BUCKET_NAME}-user --access-key ${MINIO_BACKEND_ACCESS_KEY} --secret-key ${MINIO_BACKEND_SECRET_KEY}
mc admin user svcacct add minio-1 ${MINIO_BACKEND_BUCKET_NAME_PRIV}-user --access-key ${MINIO_BACKEND_ACCESS_KEY_PRIV} --secret-key ${MINIO_BACKEND_SECRET_KEY_PRIV}
mc admin user svcacct add minio-1 ${MINIO_PORTAL_BUCKET_NAME}-user --access-key ${MINIO_PORTAL_ACCESS_KEY} --secret-key ${MINIO_PORTAL_SECRET_KEY}
mc admin user svcacct add minio-1 ${MINIO_PORTAL_BUCKET_NAME_PRIV}-user --access-key ${MINIO_PORTAL_ACCESS_KEY_PRIV} --secret-key ${MINIO_PORTAL_SECRET_KEY_PRIV}
mc admin user svcacct add minio-1 ${MINIO_ANALYTICS_BUCKET_NAME}-user --access-key ${MINIO_ANALYTICS_ACCESS_KEY} --secret-key ${MINIO_ANALYTICS_SECRET_KEY}
mc admin policy attach minio-1 ${MINIO_BACKEND_BUCKET_NAME}-policy --user ${MINIO_BACKEND_BUCKET_NAME}-user
mc admin policy attach minio-1 ${MINIO_BACKEND_BUCKET_NAME_PRIV}-policy --user ${MINIO_BACKEND_BUCKET_NAME_PRIV}-user
mc admin policy attach minio-1 ${MINIO_PORTAL_BUCKET_NAME}-policy --user ${MINIO_PORTAL_BUCKET_NAME}-user
mc admin policy attach minio-1 ${MINIO_PORTAL_BUCKET_NAME_PRIV}-policy --user ${MINIO_PORTAL_BUCKET_NAME_PRIV}-user
mc admin policy attach minio-1 ${MINIO_ANALYTICS_BUCKET_NAME}-policy --user ${MINIO_ANALYTICS_BUCKET_NAME}-user
mc anonymous set download minio-1/${MINIO_BACKEND_BUCKET_NAME}
mc anonymous set download minio-1/${MINIO_PORTAL_BUCKET_NAME}
mc anonymous set download minio-1/${MINIO_ANALYTICS_BUCKET_NAME}
mc version enable minio-1/${MINIO_BACKEND_BUCKET_NAME}
mc version enable minio-1/${MINIO_BACKEND_BUCKET_NAME_PRIV}
mc version enable minio-1/${MINIO_PORTAL_BUCKET_NAME}
mc version enable minio-1/${MINIO_PORTAL_BUCKET_NAME_PRIV}
mc version enable minio-1/${MINIO_ANALYTICS_BUCKET_NAME}
mc ilm rule add minio-1/${MINIO_BACKEND_BUCKET_NAME} --noncurrent-expire-days "1" --expire-delete-marker
mc ilm rule add minio-1/${MINIO_BACKEND_BUCKET_NAME}/archive --expire-days "1"
mc ilm rule add minio-1/${MINIO_BACKEND_BUCKET_NAME_PRIV} --noncurrent-expire-days "1" --expire-delete-marker
mc ilm rule add minio-1/${MINIO_BACKEND_BUCKET_NAME_PRIV}/database_backups --expire-days "14"
mc ilm rule add minio-1/${MINIO_PORTAL_BUCKET_NAME} --noncurrent-expire-days "1" --expire-delete-marker
mc ilm rule add minio-1/${MINIO_PORTAL_BUCKET_NAME_PRIV} --noncurrent-expire-days "1" --expire-delete-marker
mc ilm rule add minio-1/${MINIO_ANALYTICS_BUCKET_NAME} --expire-days "14"
mc ilm rule add minio-1/${MINIO_ANALYTICS_BUCKET_NAME} --noncurrent-expire-days "1" --expire-delete-marker

mc admin policy create minio-2 ${MINIO_BACKEND_BUCKET_NAME}-policy /tmp/${MINIO_BACKEND_BUCKET_NAME}-policy.json
mc admin policy create minio-2 ${MINIO_BACKEND_BUCKET_NAME_PRIV}-policy /tmp/${MINIO_BACKEND_BUCKET_NAME_PRIV}-policy.json
mc admin policy create minio-2 ${MINIO_PORTAL_BUCKET_NAME}-policy /tmp/${MINIO_PORTAL_BUCKET_NAME}-policy.json
mc admin policy create minio-2 ${MINIO_PORTAL_BUCKET_NAME_PRIV}-policy /tmp/${MINIO_PORTAL_BUCKET_NAME_PRIV}-policy.json
mc admin policy create minio-2 ${MINIO_ANALYTICS_BUCKET_NAME}-policy /tmp/${MINIO_ANALYTICS_BUCKET_NAME}-policy.json
mc admin user add minio-2 ${MINIO_BACKEND_BUCKET_NAME}-user ${MINIO_PSW}
mc admin user add minio-2 ${MINIO_BACKEND_BUCKET_NAME_PRIV}-user ${MINIO_PSW}
mc admin user add minio-2 ${MINIO_PORTAL_BUCKET_NAME}-user ${MINIO_PSW}
mc admin user add minio-2 ${MINIO_PORTAL_BUCKET_NAME_PRIV}-user ${MINIO_PSW}
mc admin user add minio-2 ${MINIO_ANALYTICS_BUCKET_NAME}-user ${MINIO_PSW}
mc admin user svcacct add minio-2 ${MINIO_BACKEND_BUCKET_NAME}-user --access-key ${MINIO_BACKEND_ACCESS_KEY} --secret-key ${MINIO_BACKEND_SECRET_KEY}
mc admin user svcacct add minio-2 ${MINIO_BACKEND_BUCKET_NAME_PRIV}-user --access-key ${MINIO_BACKEND_ACCESS_KEY_PRIV} --secret-key ${MINIO_BACKEND_SECRET_KEY_PRIV}
mc admin user svcacct add minio-2 ${MINIO_PORTAL_BUCKET_NAME}-user --access-key ${MINIO_PORTAL_ACCESS_KEY} --secret-key ${MINIO_PORTAL_SECRET_KEY}
mc admin user svcacct add minio-2 ${MINIO_PORTAL_BUCKET_NAME_PRIV}-user --access-key ${MINIO_PORTAL_ACCESS_KEY_PRIV} --secret-key ${MINIO_PORTAL_SECRET_KEY_PRIV}
mc admin user svcacct add minio-2 ${MINIO_ANALYTICS_BUCKET_NAME}-user --access-key ${MINIO_ANALYTICS_ACCESS_KEY} --secret-key ${MINIO_ANALYTICS_SECRET_KEY}
mc admin policy attach minio-2 ${MINIO_BACKEND_BUCKET_NAME}-policy --user ${MINIO_BACKEND_BUCKET_NAME}-user
mc admin policy attach minio-2 ${MINIO_BACKEND_BUCKET_NAME_PRIV}-policy --user ${MINIO_BACKEND_BUCKET_NAME_PRIV}-user
mc admin policy attach minio-2 ${MINIO_PORTAL_BUCKET_NAME}-policy --user ${MINIO_PORTAL_BUCKET_NAME}-user
mc admin policy attach minio-2 ${MINIO_PORTAL_BUCKET_NAME_PRIV}-policy --user ${MINIO_PORTAL_BUCKET_NAME_PRIV}-user
mc admin policy attach minio-2 ${MINIO_ANALYTICS_BUCKET_NAME}-policy --user ${MINIO_ANALYTICS_BUCKET_NAME}-user
mc anonymous set download minio-2/${MINIO_BACKEND_BUCKET_NAME}
mc anonymous set download minio-2/${MINIO_PORTAL_BUCKET_NAME}
mc anonymous set download minio-2/${MINIO_ANALYTICS_BUCKET_NAME}
mc version enable minio-2/${MINIO_BACKEND_BUCKET_NAME}
mc version enable minio-2/${MINIO_BACKEND_BUCKET_NAME_PRIV}
mc version enable minio-2/${MINIO_PORTAL_BUCKET_NAME}
mc version enable minio-2/${MINIO_PORTAL_BUCKET_NAME_PRIV}
mc version enable minio-2/${MINIO_ANALYTICS_BUCKET_NAME}
mc ilm rule add minio-2/${MINIO_BACKEND_BUCKET_NAME} --noncurrent-expire-days "1" --expire-delete-marker
mc ilm rule add minio-2/${MINIO_BACKEND_BUCKET_NAME}/archive --expire-days "1"
mc ilm rule add minio-2/${MINIO_BACKEND_BUCKET_NAME_PRIV} --noncurrent-expire-days "1" --expire-delete-marker
mc ilm rule add minio-2/${MINIO_BACKEND_BUCKET_NAME_PRIV}/database_backups --expire-days "14"
mc ilm rule add minio-2/${MINIO_PORTAL_BUCKET_NAME} --noncurrent-expire-days "1" --expire-delete-marker
mc ilm rule add minio-2/${MINIO_PORTAL_BUCKET_NAME_PRIV} --noncurrent-expire-days "1" --expire-delete-marker
mc ilm rule add minio-2/${MINIO_ANALYTICS_BUCKET_NAME} --expire-days "14"
mc ilm rule add minio-2/${MINIO_ANALYTICS_BUCKET_NAME} --noncurrent-expire-days "1" --expire-delete-marker


mc admin user add minio-1 replication-user ${MINIO_PSW}
mc admin user add minio-2 replication-user ${MINIO_PSW}
mc admin policy attach minio-1 consoleAdmin --user replication-user
mc admin policy attach minio-2 consoleAdmin --user replication-user
mc replicate add minio-1/${MINIO_BACKEND_BUCKET_NAME} \
   --remote-bucket "http://replication-user:${MINIO_PSW}@minio-2:9000/${MINIO_BACKEND_BUCKET_NAME}" \
   --replicate "delete,delete-marker,existing-objects,metadata-sync"
mc replicate add minio-2/${MINIO_BACKEND_BUCKET_NAME} \
   --remote-bucket "http://replication-user:${MINIO_PSW}@minio-1:9000/${MINIO_BACKEND_BUCKET_NAME}" \
   --replicate "delete,delete-marker,existing-objects,metadata-sync"
mc replicate add minio-1/${MINIO_BACKEND_BUCKET_NAME_PRIV} \
   --remote-bucket "http://replication-user:${MINIO_PSW}@minio-2:9000/${MINIO_BACKEND_BUCKET_NAME_PRIV}" \
   --replicate "delete,delete-marker,existing-objects,metadata-sync"
mc replicate add minio-2/${MINIO_BACKEND_BUCKET_NAME_PRIV} \
   --remote-bucket "http://replication-user:${MINIO_PSW}@minio-1:9000/${MINIO_BACKEND_BUCKET_NAME_PRIV}" \
   --replicate "delete,delete-marker,existing-objects,metadata-sync"
mc replicate add minio-1/${MINIO_PORTAL_BUCKET_NAME} \
   --remote-bucket "http://replication-user:${MINIO_PSW}@minio-2:9000/${MINIO_PORTAL_BUCKET_NAME}" \
   --replicate "delete,delete-marker,existing-objects,metadata-sync"
mc replicate add minio-2/${MINIO_PORTAL_BUCKET_NAME} \
   --remote-bucket "http://replication-user:${MINIO_PSW}@minio-1:9000/${MINIO_PORTAL_BUCKET_NAME}" \
   --replicate "delete,delete-marker,existing-objects,metadata-sync"
mc replicate add minio-1/${MINIO_PORTAL_BUCKET_NAME_PRIV} \
   --remote-bucket "http://replication-user:${MINIO_PSW}@minio-2:9000/${MINIO_PORTAL_BUCKET_NAME_PRIV}" \
   --replicate "delete,delete-marker,existing-objects,metadata-sync"
mc replicate add minio-2/${MINIO_PORTAL_BUCKET_NAME_PRIV} \
   --remote-bucket "http://replication-user:${MINIO_PSW}@minio-1:9000/${MINIO_PORTAL_BUCKET_NAME_PRIV}" \
   --replicate "delete,delete-marker,existing-objects,metadata-sync"
mc replicate add minio-1/${MINIO_ANALYTICS_BUCKET_NAME} \
   --remote-bucket "http://replication-user:${MINIO_PSW}@minio-2:9000/${MINIO_ANALYTICS_BUCKET_NAME}" \
   --replicate "delete,delete-marker,existing-objects,metadata-sync"
mc replicate add minio-2/${MINIO_ANALYTICS_BUCKET_NAME} \
   --remote-bucket "http://replication-user:${MINIO_PSW}@minio-1:9000/${MINIO_ANALYTICS_BUCKET_NAME}" \
   --replicate "delete,delete-marker,existing-objects,metadata-sync"


echo "
Deployment script completed successfuly!

Minio console can be reached with the following URL:
http://${MINIO_IP1}:9090
http://${MINIO_IP2}:9090
https://${MINIO_CONSOLE_DOMAIN_1}
https://${MINIO_CONSOLE_DOMAIN_2}
${MINIO_CONSOLE_DOMAIN_1} and ${MINIO_CONSOLE_DOMAIN_2} should be resolved with DNS-server
"
