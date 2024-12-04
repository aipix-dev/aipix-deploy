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

#Creating configs for orchestrator and analytics-worker
cp -n ./sources.sh.sample ./sources.sh
cp -n ../analytics/env.sample ../analytics/.env
sed -i 's@//django:8000/client_api/servers/@//orchestrator/client_api/servers/@g' ../analytics/.env
sed -i "s@://push1st-analytics:@://push1st.${NS_VMS}.svc:@g" ../analytics/.env
sed -i "s@mysql-server-analytics@mysql-server.${NS_VMS}.svc@g" ../analytics/.env
sed -i "s@redis-server-analytics@redis-server.${NS_VMS}.svc@g" ../analytics/.env
sed -i 's@//vectorizator:.*/process/@//vectorizator/process/@g' ../analytics/.env
sed -i 's@//analytics-licensing:8888@//127.0.0.1:8888@g' ../analytics/.env
sed -i 's@REDIS_STATS_DB =.*@REDIS_STATS_DB = 7@g' ../analytics/.env
sed -i 's@^MONITORING_@#MONITORING_@g' ../analytics/.env
sed -i 's@^DEPLOYMENT_NAME@#DEPLOYMENT_NAME@g' ../analytics/.env

cp -n ../analytics/licensing.yaml.sample ../analytics/licensing.yaml
sed -i "s@host:.*mysql-server.*@host: mysql-server.${NS_VMS}.svc@g" ../analytics/licensing.yaml
sed -i "s@://push1st.*:@://push1st.${NS_VMS}.svc:@g" ../analytics/licensing.yaml
cp -n ../analytics/license.json.sample ../analytics/license.json
cp -n ../analytics/analytics-worker.conf.sample ../analytics/analytics-worker.conf
sed -i "s@://push1st.*:@://push1st.${NS_VMS}.svc:@g" ../analytics/analytics-worker.conf
sed -i "s@^PUSH_ERRORS_@#PUSH_ERRORS_@g" ../analytics/analytics-worker.conf
sed -i "s@MINIO_URL=.*@MINIO_URL=minio.${NS_MINIO}.svc${S3_PORT_INTERNAL}@g" ../analytics/analytics-worker.conf
sed -i "s@MINIO_ACCESS_KEY=.*@MINIO_ACCESS_KEY=${MINIO_ANALYTICS_ACCESS_KEY}@g" ../analytics/analytics-worker.conf
sed -i "s@MINIO_SECRET_KEY=.*@MINIO_SECRET_KEY=${MINIO_ANALYTICS_SECRET_KEY}@g" ../analytics/analytics-worker.conf
sed -i "s@MINIO_BUCKET_NAME=.*@MINIO_BUCKET_NAME=${MINIO_ANALYTICS_BUCKET_NAME}@g" ../analytics/analytics-worker.conf

if [ ${MONITORING} == "yes" ]; then
    sed -i 's@^#MONITORING_@MONITORING_@g' ../analytics/.env
    sed -i "s@.DEPLOYMENT_NAME.*@DEPLOYMENT_NAME = ${NS_A}@g" ../analytics/.env
    sed -i "s@^#PUSH_ERRORS_@PUSH_ERRORS_@g" ../analytics/analytics-worker.conf
    envsubst < ../analytics/metrics-pusher.env.sample > ../analytics/metrics-pusher.env
    envsubst < ../analytics/telegraf.conf.sample > ../analytics/telegraf.conf
fi

echo """

Configurations script is finished successfuly!

"""
