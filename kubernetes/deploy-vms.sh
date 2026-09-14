#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

# Create VMS configmaps and secrets
kubectl create ns ${NS_VMS} || true

kubectl create secret docker-registry download-aipix-ai --namespace=${NS_VMS} \
	--docker-server=https://download.aipix.ai:8443 \
	--docker-username=${DOCKER_USERNAME} \
	--docker-password=${DOCKER_PASSWORD}
kubectl create configmap vms-backend-env --namespace=${NS_VMS} --from-env-file=../vms-backend/environments/.env
kubectl create configmap vms-fcm-json --namespace=${NS_VMS} --from-file=../vms-backend/certificates/fcm.json
kubectl create configmap vms-voip-p8 --namespace=${NS_VMS} --from-file=../vms-backend/certificates/voip.p8
kubectl create configmap vms-frontend-env --namespace=${NS_VMS} --from-env-file=../vms-frontend/admin.env
kubectl create configmap vms-frontend-admin-nginx --namespace=${NS_VMS} \
	--from-file=nginx.conf=../vms-frontend/nginx-base-admin.conf \
	--from-file=default.conf=../vms-frontend/nginx-server-admin.conf
kubectl create configmap vms-frontend-client-nginx --namespace=${NS_VMS} \
	--from-file=nginx.conf=../vms-frontend/nginx-base-client.conf \
	--from-file=default.conf=../vms-frontend/nginx-server-client.conf
# kubectl create configmap push1st-server --namespace=${NS_VMS} --from-file=server.yml=../push1st/server.yml
kubectl create configmap push1st-cluster --namespace=${NS_VMS} --from-file=cluster.yml=../push1st/cluster.yml
kubectl create configmap push1st-app --namespace=${NS_VMS} --from-file=../push1st/app.yml
kubectl create configmap push1st-devices --namespace=${NS_VMS} --from-file=../push1st/devices.yml

# Generate oauth-private.key, oauth-public.key, file.key and create configmap
openssl genpkey -algorithm RSA -out ../vms-backend/certificates/private_key.pem -pkeyopt rsa_keygen_bits:4096 >/dev/null 2>&1
openssl rsa -in ../vms-backend/certificates/private_key.pem -pubout -out ../vms-backend/certificates/public_key.pem >/dev/null 2>&1
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 300 | head -n 1 | xargs echo -n >../vms-backend/certificates/file.key.tmp
cp -n ../vms-backend/certificates/private_key.pem ../vms-backend/certificates/oauth-private.key
cp -n ../vms-backend/certificates/public_key.pem ../vms-backend/certificates/oauth-public.key
cp -n ../vms-backend/certificates/file.key.tmp ../vms-backend/certificates/file.key
rm ../vms-backend/certificates/private_key.pem
rm ../vms-backend/certificates/public_key.pem
rm ../vms-backend/certificates/file.key.tmp
kubectl create secret generic vms-backend-oauth --namespace=${NS_VMS} \
	--from-file=../vms-backend/certificates/oauth-private.key \
	--from-file=../vms-backend/certificates/oauth-public.key \
	--from-file=../vms-backend/certificates/file.key

if [ ${TYPE} != "prod" ]; then
	kubectl create configmap mysql-server-env --namespace=${NS_VMS} --from-env-file=../mysql-server/mysql-server.env
	kubectl create configmap mysql-cnf --namespace=${NS_VMS} --from-file=../mysql-server/my.cnf
fi

if [ ${VMS_LIC_OFFLINE} == "yes" ]; then
	kubectl create configmap vms-backend-license --namespace=${NS_VMS} --from-file=../vms-backend/license/license.jwt
fi

if [ ${ANALYTICS} == "yes" ]; then
	kubectl create configmap push1st-orchestrator --namespace=${NS_VMS} --from-file=../push1st/orchestrator.yml --dry-run=client -o yaml |
		sed -e "s@http://django:8000/api/events/@http://orchestrator.${NS_A}.svc/api/events/@g" | kubectl apply -f-
fi

# Create CONTROLLER configmaps
kubectl create configmap controller-env --namespace=${NS_VMS} --from-env-file=../controller/environments/.env

#Create PORTAL configmaps
if [ ${PORTAL} == "yes" ]; then
	kubectl create configmap portal-landing-nginx --namespace=${NS_VMS} \
		--from-file=nginx.conf=../portal/nginx-base-landing.conf \
		--from-file=default.conf=../portal/nginx-server-landing.conf
	kubectl create configmap portal-client-nginx --namespace=${NS_VMS} \
		--from-file=nginx.conf=../portal/nginx-base-client.conf \
		--from-file=default.conf=../portal/nginx-server-client.conf
	kubectl create configmap vms-portal-backend-env --namespace=${NS_VMS} --from-env-file=../portal/environments/.env
	kubectl create configmap vms-portal-stub-env --namespace=${NS_VMS} --from-env-file=../portal/environments-stub/.env
fi

#Create WB configmaps
if [ ${WB} == "yes" ]; then
	kubectl create configmap integration-wb-env --namespace=${NS_VMS} --from-env-file=../integration-wb/environments/.env
fi

#Create BLE configmaps
if [ ${BLE} == "yes" ]; then
	kubectl create configmap ble-service-env --namespace=${NS_VMS} --from-env-file=../ble-service/environments/.env
fi

# Deploying VMS
../kustomize/deployments/${VMS_TEMPLATE}/update-kustomization.sh || exit 1
kubectl apply -k ../kustomize/deployments/${VMS_TEMPLATE}

echo "VMS manifests are applied !"
sleep 10

while true; do
	if ([[ ${TYPE} == "prod" ]] || [[ $(kubectl get deployment mysql-server -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]) &&
		[[ $(kubectl get deployment controller-api -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]] &&
		[[ $(kubectl get deployment controller-schedule -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]] &&
		[[ $(kubectl get deployment backend -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]; then
		[[ $(kubectl get deployment cron -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]; then
		break
	fi
	sleep 5
	echo "Waiting for starting mysql-server, backend and controller containers ..."
done

if [ ${PORTAL} == "yes" ]; then
	while true; do
		if [[ $(kubectl get deployment portal-backend -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]] &&
			[[ $(kubectl get deployment portal-stub -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]; then
			break
		fi
		sleep 5
		echo "Waiting for starting portal-backend and portal-stub containers ..."
	done
fi

if [ ${WB} == "yes" ]; then
	while true; do
		if [[ $(kubectl get deployment integration-wb -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]; then
			break
		fi
		sleep 5
		echo "Waiting for starting integration-wb container ..."
	done
fi

if [ ${BLE} == "yes" ]; then
	while true; do
		if [[ $(kubectl get deployment ble-service -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]; then
			break
		fi
		sleep 5
		echo "Waiting for starting ble-service container ..."
	done
fi

sleep 10
echo -e "\033[32mStart backend migrations\033[0m"
kubectl exec -n ${NS_VMS} deployment.apps/cron -- ./scripts/create_db.sh
kubectl exec -n ${NS_VMS} deployment.apps/cron -- ./scripts/start.sh
kubectl exec -n ${NS_VMS} deployment.apps/cron -- chown www-data:www-data -R storage/logs
echo -e "\033[32mEnd backend migrations\033[0m"

echo -e "\033[32mStart controller migrations\033[0m"
kubectl exec -n ${NS_VMS} deployment.apps/controller-schedule -- ./scripts/create_db.sh
kubectl exec -n ${NS_VMS} deployment.apps/controller-schedule -- ./scripts/start.sh
echo -e "\033[32mEnd controller migrations\033[0m"

if [ ${TYPE} != "prod" ]; then
	echo -e "\033[32mCreate user for mysql-exporter\033[0m"
	CREATE_MONITORING_MYSQL_USER="CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY 'password' WITH MAX_USER_CONNECTIONS 3;"
	GRANT_PRIVILEGES="GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';FLUSH PRIVILEGES;"
	kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysql --protocol=TCP -u root -pmysql --execute="${CREATE_MONITORING_MYSQL_USER}"
	kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysql --protocol=TCP -u root -pmysql --execute="${GRANT_PRIVILEGES}"
	echo -e "\033[32mUser was created\033[0m"
fi

if [ ${PORTAL} == "yes" ]; then
	echo -e "\033[32mStart portal-backend migrations\033[0m"
	kubectl -n ${NS_VMS} exec deployment.apps/portal-backend -- ./scripts/create_db.sh
	kubectl -n ${NS_VMS} exec deployment.apps/portal-backend -- ./scripts/start.sh
	echo -e "\033[32mEnd portal-backend migrations\033[0m"
	echo -e "\033[32mStart portal-stub migrations\033[0m"
	kubectl -n ${NS_VMS} exec deployment.apps/portal-stub -c portal-stub -- ./scripts/create_db.sh
	kubectl -n ${NS_VMS} exec deployment.apps/portal-stub -c portal-stub -- ./scripts/start.sh
	echo -e "\033[32mEnd portal-stub migrations\033[0m"
fi

if [ ${WB} == "yes" ]; then
	echo -e "\033[32mStart WB migrations\033[0m"
	kubectl -n ${NS_VMS} exec deployment.apps/integration-wb -- ./scripts/create_db.sh
	kubectl -n ${NS_VMS} exec deployment.apps/integration-wb -- ./scripts/start.sh
	echo -e "\033[32mEnd WB migrations\033[0m"
fi

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

	kubectl exec -n ${NS_VMS} deployment.apps/cron -- mysql --protocol=TCP -u ${DB_ROOT_USERNAME} -p${DB_ROOT_PASSWORD} -P ${DB_PORT} -h ${DB_HOST} --execute="${CREATE_DATABASE}"
	kubectl exec -n ${NS_VMS} deployment.apps/cron -- mysql --protocol=TCP -u ${DB_ROOT_USERNAME} -p${DB_ROOT_PASSWORD} -P ${DB_PORT} -h ${DB_HOST} --execute="${CREATE_USER}"
	kubectl exec -n ${NS_VMS} deployment.apps/cron -- mysql --protocol=TCP -u ${DB_ROOT_USERNAME} -p${DB_ROOT_PASSWORD} -P ${DB_PORT} -h ${DB_HOST} --execute="${GRANT_PRIVILEGES}"
	echo -e "\033[32mEnd BLE migrations\033[0m"
fi

echo """
VMS deployment script completed successfuly!

List of used images:
"""
../kubernetes/print-image-versions.sh ${NS_VMS}