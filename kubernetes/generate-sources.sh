#!/bin/bash -e

#This script create sources.sh file from sources.sh.sample and generate new passwords inside.
#No updates are performed if the file sources.sh already exists.
#If you need to update only passwords in the existing sources.sh file
#(for the purpose of the re-installation as example) run the script with "force" argument: ./generate-sources.sh force

scriptdir="$(dirname "$0")"
cd "$scriptdir"

UPD_PASS=$1

if [[ ! -f ./sources.sh ]]; then
	cp -n ./sources.sh.sample ./sources.sh
	UPD_PASS="force"
	echo "
File sources.sh is created.
	"
	UPDATED="yes"
fi

if [[ ${UPD_PASS} == "force" ]]; then
	MINIO_PSW=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1 | xargs echo -n)
	MINIO_BACKEND_ACCESS_KEY=$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 20 | head -n 1 | xargs echo -n)
	MINIO_BACKEND_SECRET_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 40 | head -n 1 | xargs echo -n)
	MINIO_BACKEND_ACCESS_KEY_PRIV=$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 20 | head -n 1 | xargs echo -n)
	MINIO_BACKEND_SECRET_KEY_PRIV=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 40 | head -n 1 | xargs echo -n)
	MINIO_PORTAL_ACCESS_KEY=$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 20 | head -n 1 | xargs echo -n)
	MINIO_PORTAL_SECRET_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 40 | head -n 1 | xargs echo -n)
	MINIO_PORTAL_ACCESS_KEY_PRIV=$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 20 | head -n 1 | xargs echo -n)
	MINIO_PORTAL_SECRET_KEY_PRIV=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 40 | head -n 1 | xargs echo -n)
	MINIO_ANALYTICS_ACCESS_KEY=$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 20 | head -n 1 | xargs echo -n)
	MINIO_ANALYTICS_SECRET_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 40 | head -n 1 | xargs echo -n)
	MINIO_LOGS_ACCESS_KEY=$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 20 | head -n 1 | xargs echo -n)
	MINIO_LOGS_SECRET_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 40 | head -n 1 | xargs echo -n)
    MINIO_GRAFANA_ACCESS_KEY=$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 20 | head -n 1 | xargs echo -n)
    MINIO_GRAFANA_SECRET_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 40 | head -n 1 | xargs echo -n)
	INFLUX_PSW=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 | xargs echo -n)
	INFLUX_TOKEN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 | xargs echo -n)
	sed -E -i "s/(MINIO_PSW *= *)\S*/\1${MINIO_PSW}/g" ./sources.sh
	sed -E -i "s/(MINIO_BACKEND_ACCESS_KEY *= *)\S*/\1${MINIO_BACKEND_ACCESS_KEY}/g" ./sources.sh
	sed -E -i "s/(MINIO_BACKEND_SECRET_KEY *= *)\S*/\1${MINIO_BACKEND_SECRET_KEY}/g" ./sources.sh
	sed -E -i "s/(MINIO_BACKEND_ACCESS_KEY_PRIV *= *)\S*/\1${MINIO_BACKEND_ACCESS_KEY_PRIV}/g" ./sources.sh
	sed -E -i "s/(MINIO_BACKEND_SECRET_KEY_PRIV *= *)\S*/\1${MINIO_BACKEND_SECRET_KEY_PRIV}/g" ./sources.sh
	sed -E -i "s/(MINIO_PORTAL_ACCESS_KEY *= *)\S*/\1${MINIO_PORTAL_ACCESS_KEY}/g" ./sources.sh
	sed -E -i "s/(MINIO_PORTAL_SECRET_KEY *= *)\S*/\1${MINIO_PORTAL_SECRET_KEY}/g" ./sources.sh
	sed -E -i "s/(MINIO_PORTAL_ACCESS_KEY_PRIV *= *)\S*/\1${MINIO_PORTAL_ACCESS_KEY_PRIV}/g" ./sources.sh
	sed -E -i "s/(MINIO_PORTAL_SECRET_KEY_PRIV *= *)\S*/\1${MINIO_PORTAL_SECRET_KEY_PRIV}/g" ./sources.sh
	sed -E -i "s/(MINIO_ANALYTICS_ACCESS_KEY *= *)\S*/\1${MINIO_ANALYTICS_ACCESS_KEY}/g" ./sources.sh
	sed -E -i "s/(MINIO_ANALYTICS_SECRET_KEY *= *)\S*/\1${MINIO_ANALYTICS_SECRET_KEY}/g" ./sources.sh
	sed -E -i "s/(MINIO_LOGS_ACCESS_KEY *= *)\S*/\1${MINIO_LOGS_ACCESS_KEY}/g" ./sources.sh
	sed -E -i "s/(MINIO_LOGS_SECRET_KEY *= *)\S*/\1${MINIO_LOGS_SECRET_KEY}/g" ./sources.sh
    sed -E -i "s/(MINIO_GRAFANA_ACCESS_KEY *= *)\S*/\1${MINIO_GRAFANA_ACCESS_KEY}/g" ./sources.sh
    sed -E -i "s/(MINIO_GRAFANA_SECRET_KEY *= *)\S*/\1${MINIO_GRAFANA_SECRET_KEY}/g" ./sources.sh
	sed -E -i "s/(INFLUX_PSW *= *)\S*/\1${INFLUX_PSW}/g" ./sources.sh
	sed -E -i "s/(INFLUX_TOKEN *= *)\S*/\1${INFLUX_TOKEN}/g" ./sources.sh
	echo "
Passwords in sources.sh are updated.
	"
	UPDATED="yes"
fi

echo """
Generate sources script completed successfuly!
"""

if [[ ${UPDATED} != "yes" ]]; then
	echo "
No any updates :-)
	"
fi
