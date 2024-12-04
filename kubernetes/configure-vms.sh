#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh
source ./k8s-onprem/sources.sh

if [ ${TYPE} == "prod" ]; then
    S3_PORT_INTERNAL=""
else
    S3_PORT_INTERNAL=":9000"
fi

export CONTROLLER_ONVIF_EXTERNAL_HOST=$(echo $TRAEFIK_ADVERTISEMENT_RANGE | cut -d "-" -f1)          #Get ip addres from TRAEFIK_ADVERTISEMENT_RANGE

#Creating configs files for vms
cp -n ./sources.sh.sample ./sources.sh
cp -n ../vms-backend/environments/env.sample ../vms-backend/environments/.env
cp -n ../vms-backend/99-overrides-php.ini.sample ../vms-backend/99-overrides-php.ini
cp -n ../vms-backend/z-overrides-pool-www.conf.sample ../vms-backend/z-overrides-pool-www.conf
cp -n ../push1st/app.yml.sample ../push1st/app.yml
cp -n ../push1st/cluster.yml.sample ../push1st/cluster.yml
cp -n ../push1st/orchestrator.yml.sample ../push1st/orchestrator.yml
cp -n ../push1st/server.yml.sample ../push1st/server.yml
cp -n ../push1st/devices.yml.sample ../push1st/devices.yml

sed -i "s@BASE_ENDPOINT_S3_STORAGE=.*@BASE_ENDPOINT_S3_STORAGE=https://${VMS_DOMAIN}/s3@g" ../vms-backend/environments/.env
sed -i "s@PUBLIC_AWS_BUCKET=.*@PUBLIC_AWS_BUCKET=${MINIO_BACKEND_BUCKET_NAME}@g" ../vms-backend/environments/.env
sed -i "s@PUBLIC_AWS_ACCESS_KEY_ID=.*@PUBLIC_AWS_ACCESS_KEY_ID=${MINIO_BACKEND_ACCESS_KEY}@g" ../vms-backend/environments/.env
sed -i "s@PUBLIC_AWS_SECRET_ACCESS_KEY=.*@PUBLIC_AWS_SECRET_ACCESS_KEY=${MINIO_BACKEND_SECRET_KEY}@g" ../vms-backend/environments/.env
sed -i "s@PUBLIC_AWS_ENDPOINT=.*@PUBLIC_AWS_ENDPOINT=http://minio.${NS_MINIO}.svc${S3_PORT_INTERNAL}@g" ../vms-backend/environments/.env
sed -i "s@PUBLIC_AWS_URL=.*@PUBLIC_AWS_URL=https://${VMS_DOMAIN}/s3@g" ../vms-backend/environments/.env
sed -i "s@PRIVATE_AWS_BUCKET=.*@PRIVATE_AWS_BUCKET=${MINIO_BACKEND_BUCKET_NAME_PRIV}@g" ../vms-backend/environments/.env
sed -i "s@PRIVATE_AWS_ACCESS_KEY_ID=.*@PRIVATE_AWS_ACCESS_KEY_ID=${MINIO_BACKEND_ACCESS_KEY_PRIV}@g" ../vms-backend/environments/.env
sed -i "s@PRIVATE_AWS_SECRET_ACCESS_KEY=.*@PRIVATE_AWS_SECRET_ACCESS_KEY=${MINIO_BACKEND_SECRET_KEY_PRIV}@g" ../vms-backend/environments/.env
sed -i "s@PRIVATE_AWS_ENDPOINT=.*@PRIVATE_AWS_ENDPOINT=http://minio.${NS_MINIO}.svc${S3_PORT_INTERNAL}@g" ../vms-backend/environments/.env
sed -i "s@PRIVATE_AWS_URL=.*@PRIVATE_AWS_URL=https://${VMS_DOMAIN}/s3@g" ../vms-backend/environments/.env
if [[ ${TYPE} == "single" ]] && [[ ${BACKEND_STORAGE_TYPE} == "disk" ]]; then
    sed -E -i "s@^ *#? *FILESYSTEM_DISK_PUBLIC=.*@#FILESYSTEM_DISK_PUBLIC=s3-public@g" ../vms-backend/environments/.env
    sed -E -i "s@^ *#? *FILESYSTEM_DISK_PRIVATE=.*@#FILESYSTEM_DISK_PRIVATE=s3-private@g" ../vms-backend/environments/.env
    sed -E -i "s@^ *#? *S3_BACKUP_PATH=.*@#S3_BACKUP_PATH=database_backups@g" ../vms-backend/environments/.env
elif [ -z "${BACKEND_STORAGE_TYPE}" ]; then
	echo "Skipping FILESYSTEM_DISK config"
else
	sed -E -i "s@^ *#? *FILESYSTEM_DISK_PUBLIC=.*@FILESYSTEM_DISK_PUBLIC=s3-public@g" ../vms-backend/environments/.env
    sed -E -i "s@^ *#? *FILESYSTEM_DISK_PRIVATE=.*@FILESYSTEM_DISK_PRIVATE=s3-private@g" ../vms-backend/environments/.env
    sed -E -i "s@^ *#? *S3_BACKUP_PATH=.*@S3_BACKUP_PATH=database_backups@g" ../vms-backend/environments/.env
fi

cp -n ../controller/environments/env.sample ../controller/environments/.env
sed -i "s@CONTROL_PLAIN_HLS_REDIRECT_ENDPOINT=.*@CONTROL_PLAIN_HLS_REDIRECT_ENDPOINT=${VMS_DOMAIN}/controller-hls@g" ../controller/environments/.env
sed -i "s@CONTROL_PLAIN_RTSP_REDIRECT_ENDPOINT=.*@CONTROL_PLAIN_RTSP_REDIRECT_ENDPOINT=${VMS_DOMAIN}:5554@g" ../controller/environments/.env
sed -i "s@CONTROL_PLAIN_RTSP_REDIRECT_ENDPOINT_INTERNAL=.*@CONTROL_PLAIN_RTSP_REDIRECT_ENDPOINT_INTERNAL=controller-control-plane-rtsp.${NS_VMS}.svc:5554@g" ../controller/environments/.env
sed -i "s@ONVIF_EXTERNAL_HOST=.*@ONVIF_EXTERNAL_HOST=http://${CONTROLLER_ONVIF_EXTERNAL_HOST}:8888@g" ../controller/environments/.env
cp -n ../nginx/nginx.conf.sample ../nginx/nginx.conf
cp -n ../nginx/vms-backend-nginx-server.conf.sample ../nginx/vms-backend-nginx-server.conf
cp -n ../nginx/vms-backend-nginx.conf.sample ../nginx/vms-backend-nginx.conf
cp -n ../nginx/controller-nginx-server.conf.sample ../nginx/controller-nginx-server.conf
cp -n ../nginx/controller-nginx.conf.sample ../nginx/controller-nginx.conf
cp -n ../vms-frontend/admin.env.sample ../vms-frontend/admin.env
cp -n ../vms-frontend/client.env.sample ../vms-frontend/client.env

if [ ${ANALYTICS} == "yes" ]; then
    sed -i "s@ORCHESTRATOR_ENDPOINT=http://.*@ORCHESTRATOR_ENDPOINT=http://orchestrator.${NS_A}.svc@g" ../vms-backend/environments/.env
    sed -i "s@CLICKHOUSE_HOST=.*@CLICKHOUSE_HOST=clickhouse-server.${NS_A}.svc@g" ../vms-backend/environments/.env
    sed -i "s@ANALYTIC_CASE_CALLBACK_ENDPOINT=.*@ANALYTIC_CASE_CALLBACK_ENDPOINT=http://backend.${NS_VMS}.svc@g" ../vms-backend/environments/.env
fi

if [ ${MONITORING} == "yes" ]; then
    sed -E -i "s@^ *#? *LOG_CHANNEL=.*@LOG_CHANNEL=syslogudp@g" ../vms-backend/environments/.env
    sed -E -i "s@^ *#? *LOG_CHANNEL=.*@LOG_CHANNEL=syslogudp@g" ../controller/environments/.env
fi

cp -n ../vms-backend/license/license.json.sample ../vms-backend/license/license.json

if [ ${PORTAL} == "yes" ]; then
    cp -n ../portal/environments/env.sample ../portal/environments/.env
    cp -n ../portal/environments-stub/env.sample ../portal/environments-stub/.env
    sed -i "s@BILLING_PAYMENT_GETAWAY_URL=.*@BILLING_PAYMENT_GETAWAY_URL=https://${PORTAL_STUB_DOMAIN}@g" ../portal/environments/.env
    sed -i "s@BILLING_PAYMENT_GETAWAY_AUTH_ENDPOINT=.*@BILLING_PAYMENT_GETAWAY_AUTH_ENDPOINT=https://${PORTAL_STUB_DOMAIN}/connect/token@g" ../portal/environments/.env
    sed -i "s@EXTERNAL_OAUTH_REDIRECT_URI_WEB=.*@EXTERNAL_OAUTH_REDIRECT_URI_WEB=https://${VMS_DOMAIN}/auth/login@g" ../portal/environments/.env
    sed -i "s@EXTERNAL_OAUTH_REDIRECT_URI_MOBILE=.*@EXTERNAL_OAUTH_REDIRECT_URI_MOBILE=https://${VMS_DOMAIN}/auth/login@g" ../portal/environments/.env
    sed -i "s@PUBLIC_AWS_BUCKET=.*@PUBLIC_AWS_BUCKET=${MINIO_PORTAL_BUCKET_NAME}@g" ../portal/environments/.env
    sed -i "s@PUBLIC_AWS_ACCESS_KEY_ID=.*@PUBLIC_AWS_ACCESS_KEY_ID=${MINIO_PORTAL_ACCESS_KEY}@g" ../portal/environments/.env
    sed -i "s@PUBLIC_AWS_SECRET_ACCESS_KEY=.*@PUBLIC_AWS_SECRET_ACCESS_KEY=${MINIO_PORTAL_SECRET_KEY}@g" ../portal/environments/.env
    sed -i "s@PUBLIC_AWS_ENDPOINT=.*@PUBLIC_AWS_ENDPOINT=http://minio.${NS_MINIO}.svc${S3_PORT_INTERNAL}@g" ../portal/environments/.env
    sed -i "s@PUBLIC_AWS_URL=.*@PUBLIC_AWS_URL=https://${VMS_DOMAIN}/s3@g" ../portal/environments/.env
    sed -i "s@PRIVATE_AWS_BUCKET=.*@PRIVATE_AWS_BUCKET=${MINIO_PORTAL_BUCKET_NAME_PRIV}@g" ../portal/environments/.env
    sed -i "s@PRIVATE_AWS_ACCESS_KEY_ID=.*@PRIVATE_AWS_ACCESS_KEY_ID=${MINIO_PORTAL_ACCESS_KEY_PRIV}@g" ../portal/environments/.env
    sed -i "s@PRIVATE_AWS_SECRET_ACCESS_KEY=.*@PRIVATE_AWS_SECRET_ACCESS_KEY=${MINIO_PORTAL_SECRET_KEY_PRIV}@g" ../portal/environments/.env
    sed -i "s@PRIVATE_AWS_ENDPOINT=.*@PRIVATE_AWS_ENDPOINT=http://minio.${NS_MINIO}.svc${S3_PORT_INTERNAL}@g" ../portal/environments/.env
    sed -i "s@PRIVATE_AWS_URL=.*@PRIVATE_AWS_URL=https://${VMS_DOMAIN}/s3@g" ../portal/environments/.env
    if [ ${MONITORING} == "yes" ]; then
        sed -E -i "s@^ *#? *LOG_CHANNEL=.*@LOG_CHANNEL=syslogudp@g" ../portal/environments/.env
    fi
    if [[ ${TYPE} == "single" ]] && [[ ${BACKEND_STORAGE_TYPE} == "disk" ]]; then
        sed -E -i "s@^ *#? *FILESYSTEM_DISK_PUBLIC=.*@#FILESYSTEM_DISK_PUBLIC=s3-public@g" ../portal/environments/.env
        sed -E -i "s@^ *#? *FILESYSTEM_DISK_PRIVATE=.*@#FILESYSTEM_DISK_PRIVATE=s3-private@g" ../portal/environments/.env
    elif [ -z "${BACKEND_STORAGE_TYPE}" ]; then
        echo "Skipping FILESYSTEM_DISK config"
    else
        sed -E -i "s@^ *#? *FILESYSTEM_DISK_PUBLIC=.*@FILESYSTEM_DISK_PUBLIC=s3-public@g" ../portal/environments/.env
        sed -E -i "s@^ *#? *FILESYSTEM_DISK_PRIVATE=.*@FILESYSTEM_DISK_PRIVATE=s3-private@g" ../portal/environments/.env
    fi
fi

echo """

Configuration script is finished successfuly!

"""
