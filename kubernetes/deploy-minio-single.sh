#!/bin/bash

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
until [[ $(kubectl get deployments.apps minio -n ${NS_MINIO} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]; do
  echo "Waiting for starting minio container ..."
  sleep 10
  wait_period=$(($wait_period+10))
  if [ $wait_period -gt 300 ];then
     echo "The script ran for 5 minutes to start containers, exiting now.."
     exit 1
  fi
done

export MINIO_IP=$(kubectl -n ${NS_MINIO} get service/minio -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')

#mc config host add local http://${MINIO_IP}:9000 ${MINIO_USR} ${MINIO_PSW}
mc alias set local http://${MINIO_IP}:9000 ${MINIO_USR} ${MINIO_PSW}
mc mb -p local/${BACKEND_BUCKET_NAME}
mc mb -p local/${ANALYTICS_BUCKET_NAME}

cat <<EOF > /tmp/${BACKEND_BUCKET_NAME}-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::${BACKEND_BUCKET_NAME}/*"
            ]
        }
    ]
}
EOF

cat <<EOF > /tmp/${ANALYTICS_BUCKET_NAME}-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::${ANALYTICS_BUCKET_NAME}/*"
            ]
        }
    ]
}
EOF

mc admin policy create local ${BACKEND_BUCKET_NAME}-policy /tmp/${BACKEND_BUCKET_NAME}-policy.json
mc admin policy create local ${ANALYTICS_BUCKET_NAME}-policy /tmp/${ANALYTICS_BUCKET_NAME}-policy.json
mc admin user add local ${BACKEND_BUCKET_NAME}-user ${MINIO_PSW}
mc admin user add local ${ANALYTICS_BUCKET_NAME}-user ${MINIO_PSW}
mc admin user svcacct add local ${BACKEND_BUCKET_NAME}-user --access-key ${MINIO_BACKEND_ACCESS_KEY} --secret-key ${MINIO_SECRET_KEY}
mc admin user svcacct add local ${ANALYTICS_BUCKET_NAME}-user --access-key ${MINIO_ANALYTICS_ACCESS_KEY} --secret-key ${MINIO_SECRET_KEY}
mc admin policy attach local ${BACKEND_BUCKET_NAME}-policy --user ${BACKEND_BUCKET_NAME}-user
mc admin policy attach local ${ANALYTICS_BUCKET_NAME}-policy --user ${ANALYTICS_BUCKET_NAME}-user
mc anonymous set download local/${BACKEND_BUCKET_NAME}
mc anonymous set download local/${ANALYTICS_BUCKET_NAME}
mc ilm rule add local/${ANALYTICS_BUCKET_NAME} --expire-days "2"

echo "

Minio console can be reached with the following URL:
http://${MINIO_IP}:9090
https://${MINIO_CONSOLE_DOMAIN}

"
