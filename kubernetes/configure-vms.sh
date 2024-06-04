#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

#Creating configs files for vms
cp -n ./sources.sh.sample ./sources.sh
cp -n ../vms-backend/environments/env.sample ../vms-backend/environments/.env
sed -i "s@BASE_ENDPOINT_S3_STORAGE=.*@BASE_ENDPOINT_S3_STORAGE=https://${MINIO_CONSOLE_DOMAIN}/@g" ../vms-backend/environments/.env
sed -i "s@AWS_ACCESS_KEY_ID=.*@AWS_ACCESS_KEY_ID=${MINIO_BACKEND_ACCESS_KEY}@g" ../vms-backend/environments/.env
sed -i "s@AWS_SECRET_ACCESS_KEY=.*@AWS_SECRET_ACCESS_KEY=${MINIO_SECRET_KEY}@g" ../vms-backend/environments/.env
sed -i "s@AWS_BUCKET=.*@AWS_BUCKET=${BACKEND_BUCKET_NAME}@g" ../vms-backend/environments/.env
sed -i "s@AWS_ENDPOINT=.*@AWS_ENDPOINT=https://${MINIO_CONSOLE_DOMAIN}/@g" ../vms-backend/environments/.env
cp -n ../controller/environments/env.sample ../controller/environments/.env
sed -i "s@CONTROL_PLAIN_HLS_REDIRECT_ENDPOINT=.*@CONTROL_PLAIN_HLS_REDIRECT_ENDPOINT=${VMS_DOMAIN}/controller-hls@g" ../controller/environments/.env
sed -i "s@CONTROL_PLAIN_RTSP_REDIRECT_ENDPOINT=.*@CONTROL_PLAIN_RTSP_REDIRECT_ENDPOINT=${VMS_DOMAIN}:5554@g" ../controller/environments/.env
sed -i "s@CONTROL_PLAIN_RTSP_REDIRECT_ENDPOINT_INTERNAL=.*@CONTROL_PLAIN_RTSP_REDIRECT_ENDPOINT_INTERNAL=controller-control-plane-rtsp.vsaas-vms.svc:5554@g" ../controller/environments/.env
cp -n ../nginx/nginx.conf.sample ../nginx/nginx.conf
if [ ${ANALYTICS} == "yes" ]; then
    sed -i "s@ORCHESTRATOR_ENDPOINT=http://.*@ORCHESTRATOR_ENDPOINT=http://orchestrator.${NS_A}.svc@g" ../vms-backend/environments/.env
    sed -i "s@CLICKHOUSE_HOST=.*@CLICKHOUSE_HOST=clickhouse-server.${NS_A}.svc@g" ../vms-backend/environments/.env
fi
cp -n ../vms-backend/license/license.json.sample ../vms-backend/license/license.json
if [ ${PORTAL} == "yes" ]; then
    cp -n ../portal/environments/env.sample ../portal/environments/.env
    cp -n ../portal/environments-stub/env.sample ../portal/environments-stub/.env
    sed -i "s@BILLING_PAYMENT_GETAWAY_URL=.*@BILLING_PAYMENT_GETAWAY_URL=https://${PORTAL_STUB_DOMAIN}@g" ../portal/environments/.env
    sed -i "s@BILLING_PAYMENT_GETAWAY_AUTH_ENDPOINT=.*@BILLING_PAYMENT_GETAWAY_AUTH_ENDPOINT=https://${PORTAL_STUB_DOMAIN}/connect/token@g" ../portal/environments/.env
    sed -i "s@EXTERNAL_OAUTH_REDIRECT_URI_WEB=.*@EXTERNAL_OAUTH_REDIRECT_URI_WEB=https://${VMS_DOMAIN}/auth/login@g" ../portal/environments/.env
fi

echo """

Configuration script is finished successfuly!

"""
