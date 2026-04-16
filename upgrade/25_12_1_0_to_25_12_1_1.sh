#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

# Delete BACKEND_STORAGE_TYPE env from ../kubernetes/sources.sh file
sed -i '/BACKEND_STORAGE_TYPE=/d' ../kubernetes/sources.sh

# Add new bucket for ble-service
if [ ${TYPE} == "prod" ]; then
	../kubernetes/deploy-minio-ha.sh
else
	../kubernetes/deploy-minio-single.sh
fi

# Add new entrypoint for ble-service
yq -i '.ports.ble-service={"port": 6444, "protocol": "TCP", "expose": {"default": true},"exposedPort": 6444}' ../traefik/traefik-helm-values.yaml || echo -e "\033[31mError adding ble-service entrypoint\033[0m"

if [[ $(kubectl -n ${NS_VMS} get deployments.apps | grep online-service) ]]; then
	kubectl -n ${NS_VMS} delete Service online-service
	kubectl -n ${NS_VMS} delete Deployment online-service
	kubectl -n ${NS_VMS} delete ingressroutes.traefik.io online-service-api
	kubectl -n ${NS_VMS} delete ingressroutetcps.traefik.io online-service-lock
	mc cp --recursive local/online-service/ local/${MINIO_BLE_BUCKET_NAME} || true
	mc admin user svcacct remove local online-service-user
	mc ilm rule remove local/online-service --all --force
	mc admin user remove local online-service-user
	mc admin policy remove local online-service-policy
	mc rb local/online-service --force
	yq -i 'del(.ports["online-lock"])' ../traefik/traefik-helm-values.yaml || echo -e "\033[31mError delete online-lock entrypoint\033[0m"
	sed -i "s@OPENY_ONLINE_URL=.*@OPENY_ONLINE_URL=http://ble-service:8080@g" ../vms-backend/environments/.env
	rm -rf ../kustomize/apps/vms/online-service
fi

### Update VMS
../kubernetes/configure-vms.sh

# Deplou BLE if set to yes
if [ ${BLE} == "yes" ]; then
	echo -e "\033[32mStart BLE migrations\033[0m"
	# Create database, user, grant permissions
	IFS="=" read name DB_HOST <<<$(cat ../ble-service/environments/.env | grep DB_HOST)
	IFS="=" read name DB_PORT <<<$(cat ../ble-service/environments/.env | grep -i DB_PORT)
	IFS="=" read name DB_NAME <<<$(cat ../ble-service/environments/.env | grep -i DB_NAME)
	IFS="=" read name DB_USER <<<$(cat ../ble-service/environments/.env | grep -i DB_USER)
	IFS="=" read name DB_PASSWORD <<<$(cat ../ble-service/environments/.env | grep -i DB_PASSWORD)
	IFS="=" read name DB_ROOT_USERNAME <<<$(cat ../vms-backend/environments/.env | grep -i DB_ROOT_USERNAME)
	IFS="=" read name DB_ROOT_PASSWORD <<<$(cat ../vms-backend/environments/.env | grep -i DB_ROOT_PASSWORD)

	CREATE_DATABASE="CREATE DATABASE IF NOT EXISTS ${DB_NAME} character set 'utf8mb4' collate 'utf8mb4_unicode_ci';"
	CREATE_USER="CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';"
	GRANT_PRIVILEGES="GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';FLUSH PRIVILEGES;"

	kubectl exec -n ${NS_VMS} deployment.apps/backend -- mysql --protocol=TCP -u ${DB_ROOT_USERNAME} -p${DB_ROOT_PASSWORD} -P ${DB_PORT} -h ${DB_HOST} --execute="${CREATE_DATABASE}"
	kubectl exec -n ${NS_VMS} deployment.apps/backend -- mysql --protocol=TCP -u ${DB_ROOT_USERNAME} -p${DB_ROOT_PASSWORD} -P ${DB_PORT} -h ${DB_HOST} --execute="${CREATE_USER}"
	kubectl exec -n ${NS_VMS} deployment.apps/backend -- mysql --protocol=TCP -u ${DB_ROOT_USERNAME} -p${DB_ROOT_PASSWORD} -P ${DB_PORT} -h ${DB_HOST} --execute="${GRANT_PRIVILEGES}"
	echo -e "\033[32mEnd BLE migrations\033[0m"
fi

../kubernetes/update-vms.sh

### Update VGW
if [ ${VGW} == "yes" ]; then
	../kubernetes/configure-vgw.sh
	../kubernetes/update-vgw.sh
else
	echo "VGW is not installed, continue update"
fi

### Update Analytics
if [ ${ANALYTICS} == "yes" ]; then
	../kubernetes/configure-analytics.sh
	../kubernetes/update-analytics.sh
else
	echo "Analytics is not installed, continue update"
fi

### Update MSE
if [[ $(kubectl get ns | grep ${NS_MS}) ]]; then
	../kubernetes/update-mse.sh
else
	echo "MSE is not installed in k8s, continue update"
fi

### Update monitoring
if [ ${MONITORING} == "yes" ]; then
	rm ../monitoring/grafana-alerts/rules/analytics-cases-rules.yaml
	kubectl -n ${NS_MONITORING} exec deployments/grafana -- rm -rf /var/lib/grafana/dashboards
	kubectl -n ${NS_MONITORING} delete deployments.apps x509-certificate-exporter
	../kubernetes/configure-monitoring.sh
	../kubernetes/deploy-monitoring.sh
else
	echo "Monitoring is not installed, continue update"
fi

echo """
Upgrade script completed successfuly!

"""
