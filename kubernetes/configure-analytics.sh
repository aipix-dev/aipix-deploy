#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

if [ ${ANALYTICS} != "yes" ]; then
	echo 'Variable ANALYTICS is not set to "yes". Exiting ...'
	exit 1
fi

if [ ${TYPE} == "prod" ]; then
	S3_PORT_INTERNAL=""
else
	S3_PORT_INTERNAL=":9000"
fi

#Creating configs for orchestrator
cp -n ./sources.sh.sample ./sources.sh
cp -n ../analytics/env.sample ../analytics/.env
sed -i "s@://push1st:@://push1st.${NS_VMS}.svc:@g" ../analytics/.env
sed -i "s@mysql-server-analytics@mysql-server.${NS_VMS}.svc@g" ../analytics/.env
sed -i "s@redis-server-analytics@redis-server.${NS_VMS}.svc@g" ../analytics/.env
sed -i 's@^MONITORING_@#MONITORING_@g' ../analytics/.env
sed -i 's@^DEPLOYMENT_NAME@#DEPLOYMENT_NAME@g' ../analytics/.env
# sed -i "s@^POD_NAMESPACE.*@POD_NAMESPACE = ${NS_A}@g" ../analytics/.env
sed -i "s@^BACKEND_SERVICE_HOST.*@BACKEND_SERVICE_HOST = \"backend.${NS_VMS}.svc\"@g" ../analytics/.env
sed -i "s@django:8000@orchestrator.${NS_A}.svc@g" ../push1st/orchestrator.yml

#Creating configs for license service
cp -n ../analytics/licensing.yaml.sample ../analytics/licensing.yaml
sed -i "s@host:.*mysql-server.*@host: mysql-server.${NS_VMS}.svc@g" ../analytics/licensing.yaml
sed -i "s@://push1st.*:@://push1st.${NS_VMS}.svc:@g" ../analytics/licensing.yaml
cp -n ../analytics/license.json.sample ../analytics/license.json

#Creating configs for analytics-worker
cp -n ../analytics/analytics-worker-env.sample ../analytics/analytics-worker-env
sed -i "s@://push1st.*:@://push1st.${NS_VMS}.svc:@g" ../analytics/analytics-worker-env
sed -i "s@^PUSH_ERRORS_MONITORING_ENDPOINT@#PUSH_ERRORS_MONITORING_ENDPOINT@g" ../analytics/analytics-worker-env
sed -i "s@^PUSH_ERRORS_VMS_ENDPOINT=.*@PUSH_ERRORS_VMS_ENDPOINT=http://backend.${NS_VMS}.svc/api/v1/ovms/callback@g" ../analytics/analytics-worker-env
sed -i "s@MINIO_URL=.*@MINIO_URL=http://minio.${NS_MINIO}.svc${S3_PORT_INTERNAL}@g" ../analytics/analytics-worker-env
sed -i "s@MINIO_ACCESS_KEY=.*@MINIO_ACCESS_KEY=${MINIO_ANALYTICS_ACCESS_KEY}@g" ../analytics/analytics-worker-env
sed -i "s@MINIO_SECRET_KEY=.*@MINIO_SECRET_KEY=${MINIO_ANALYTICS_SECRET_KEY}@g" ../analytics/analytics-worker-env
sed -i "s@MINIO_BUCKET_NAME=.*@MINIO_BUCKET_NAME=${MINIO_ANALYTICS_BUCKET_NAME}@g" ../analytics/analytics-worker-env

if [ ${MONITORING} == "yes" ]; then
	sed -i 's@^#MONITORING_@MONITORING_@g' ../analytics/.env
	sed -i "s@.DEPLOYMENT_NAME.*@DEPLOYMENT_NAME = ${NS_A}@g" ../analytics/.env
	sed -i "s@^#PUSH_ERRORS_MONITORING_ENDPOINT@PUSH_ERRORS_MONITORING_ENDPOINT@g" ../analytics/analytics-worker-env
	envsubst < ../analytics/metrics-pusher.env.sample > ../analytics/metrics-pusher.env
	envsubst < ../analytics/telegraf.conf.sample > ../analytics/telegraf.conf
fi

echo """

Analytics configuration script completed successfuly!

"""
