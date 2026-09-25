#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"

UPDATE_MODE=$1   #If passed "full" script will rollout restart all of services

source ./sources.sh

# Delete registry secrets
kubectl delete secret download-aipix-ai --namespace=${NS_VMS} || true

# Delete VMS configmaps
kubectl delete secret vms-backend-oauth --namespace=${NS_VMS} || true
kubectl delete configmap vms-backend-env --namespace=${NS_VMS} || true
kubectl delete configmap vms-fcm-json --namespace=${NS_VMS} || true
kubectl delete configmap vms-voip-p8 --namespace=${NS_VMS} || true
kubectl delete configmap vms-frontend-env --namespace=${NS_VMS} || true
kubectl delete configmap vms-frontend-admin-nginx --namespace=${NS_VMS} || true
kubectl delete configmap vms-frontend-client-nginx --namespace=${NS_VMS} || true
#kubectl delete configmap push1st-server --namespace=${NS_VMS} || true
kubectl delete configmap push1st-cluster --namespace=${NS_VMS} || true
kubectl delete configmap push1st-app --namespace=${NS_VMS} || true
kubectl delete configmap push1st-devices --namespace=${NS_VMS} || true

if [ ${TYPE} != "prod" ]; then
	kubectl delete configmap mysql-server-env --namespace=${NS_VMS} || true
	kubectl delete configmap mysql-cnf --namespace=${NS_VMS} || true
fi

# Delete CONTROLLER configmaps
kubectl delete configmap controller-env --namespace=${NS_VMS} || true

# Delete PORTAL configmaps
if [ ${PORTAL} == "yes" ]; then
	kubectl delete configmap portal-landing-nginx --namespace=${NS_VMS} || true
	kubectl delete configmap portal-client-nginx --namespace=${NS_VMS} || true
	kubectl delete configmap vms-portal-backend-env --namespace=${NS_VMS} || true
	kubectl delete configmap vms-portal-stub-env --namespace=${NS_VMS} || true
fi

# Delete WB configmaps
if [ ${WB} == "yes" ]; then
	kubectl delete configmap integration-wb-env --namespace=${NS_VMS} || true
fi

# Delete BLE configmaps
if [ ${BLE} == "yes" ]; then
	kubectl delete configmap ble-service-env --namespace=${NS_VMS} || true
fi

# Create registry secrets
kubectl create secret docker-registry download-aipix-ai --namespace=${NS_VMS} \
	--docker-server=https://download.aipix.ai:8443 \
	--docker-username=${DOCKER_USERNAME} \
	--docker-password=${DOCKER_PASSWORD}

# Create VMS configmaps
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
	kubectl delete configmap vms-backend-license --namespace=${NS_VMS} || true
	kubectl create configmap vms-backend-license --namespace=${NS_VMS} --from-file=../vms-backend/license/license.jwt
fi

# Create CONTROLLER configmaps
kubectl create configmap controller-env --namespace=${NS_VMS} --from-env-file=../controller/environments/.env

# Create PORTAL configmaps
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

#Reapplying vms manifests
../kustomize/deployments/${VMS_TEMPLATE}/update-kustomization.sh || exit 1
kubectl apply -k ../kustomize/deployments/${VMS_TEMPLATE}

sleep 5

#Waiting for containers are started
wait_period=0
for deployment in $(kubectl -n ${NS_VMS} get deployment | awk 'NR>1 { print $1 }'); do
	wait_period=$(($wait_period + 10))
	if [ $wait_period -gt 500 ]; then
		echo "The script ran for 8 minutes to start containers, exiting now.."
		break
	fi
	replicas=$(kubectl get deployment $deployment -n ${NS_VMS} -o jsonpath='{.status.replicas}')
	ready_replicas=$(kubectl get deployment $deployment -n ${NS_VMS} -o jsonpath='{.status.availableReplicas}')
	while [[ ${replicas} != ${ready_replicas} ]]; do
		echo "Waiting for updating containers ..."
		sleep 5
		replicas=$(kubectl get deployment $deployment -n ${NS_VMS} -o jsonpath='{.status.replicas}')
		ready_replicas=$(kubectl get deployment $deployment -n ${NS_VMS} -o jsonpath='{.status.availableReplicas}')
	done
done
echo -e "\033[32mManifests were successfully aplied\033[0m"

#Rollout restart
if [[ "${UPDATE_MODE:-}" == "full" ]]; then
	echo -e "\033[32mUPDATE_MODE = 'full', restarting all deployments and statefulsets\033[0m"
	for i in $(kubectl get deployments -n ${NS_VMS} | awk 'NR>1 { print $1 }'); do 
		kubectl -n ${NS_VMS} rollout restart deployment $i
	done
	kubectl -n ${NS_VMS} rollout restart statefulset push1st
else
	echo -e "\033[32mUPDATE_MODE = ' ', restarting all deployments and statefulsets except mysql-server, redis-server, beanstalkd and push1st\033[0m"
	for i in $(kubectl -n ${NS_VMS} get deployments | awk 'NR>1 { print $1 }'); do
		if [[ $i != "redis-server" ]] && [[ $i != "beanstalkd" ]] && [[ $i != "mysql-server" ]]; then
			kubectl -n ${NS_VMS} rollout restart deployment $i
		fi
	done
fi
kubectl -n ${NS_VMS} rollout status deployment backend >/dev/null
kubectl -n ${NS_VMS} rollout status deployment cron >/dev/null
kubectl -n ${NS_VMS} rollout status deployment controller-api >/dev/null
kubectl -n ${NS_VMS} rollout status deployment controller-schedule >/dev/null
kubectl -n ${NS_VMS} rollout status deployment redis-server >/dev/null
kubectl -n ${NS_VMS} rollout status deployment beanstalkd >/dev/null
if [ ${TYPE} != "prod" ]; then
	kubectl -n ${NS_VMS} rollout status deployment mysql-server >/dev/null
fi

echo -e "\033[32mDeployments were successfully restarted\033[0m"
# sleep 15 - comment due to rediness and liveness probes integration

echo -e "\033[32mStart controller migrations\033[0m"
kubectl -n ${NS_VMS} exec deployment.apps/controller-schedule -- ./scripts/update.sh
if [ $? == 0 ]; then 
	echo -e "\033[32mСontroller migrations completed successfully\033[0m"
else
	echo -e "\033[31mСontroller migrations failed\033[0m"
fi

echo -e "\033[32mStart backend migrations\033[0m"
kubectl -n ${NS_VMS} exec deployment.apps/cron -- ./scripts/update.sh
if [ $? == 0 ]; then 
	echo -e "\033[32mBackend migrations completed successfully\033[0m"
else
	echo -e "\033[31mBackend migrations failed\033[0m"
fi

# kubectl -n ${NS_VMS} exec deployment.apps/backend -- chown www-data:www-data -R storage/logs

if [ ${PORTAL} == "yes" ]; then
	echo -e "\033[32mStart portal migrations\033[0m"
	kubectl -n ${NS_VMS} rollout status deployment portal-schedule >/dev/null
	kubectl -n ${NS_VMS} rollout status deployment portal-stub >/dev/null
	kubectl -n ${NS_VMS} exec deployment.apps/portal-schedule -- ./scripts/update.sh
	if [ $? == 0 ]; then 
		echo -e "\033[32mPortal-backend migrations completed successfully\033[0m"
	else
		echo -e "\033[31mPortal-backend migrations failed\033[0m"
	fi
	kubectl -n ${NS_VMS} exec deployment.apps/portal-stub  -c portal-stub -- ./scripts/update.sh
	if [ $? == 0 ]; then 
		echo -e "\033[32mPortal-stub migrations completed successfully\033[0m"
	else
		echo -e "\033[31mPortal-stub migrations failed\033[0m"
	fi
fi

if [ ${WB} == "yes" ]; then
	echo -e "\033[32mStart WB migrations\033[0m"
	kubectl -n ${NS_VMS} rollout status deployment integration-wb >/dev/null
	kubectl -n ${NS_VMS} exec deployment.apps/integration-wb -- ./scripts/update.sh
	if [ $? == 0 ]; then 
		echo -e "\033[32mIntegration-wb migrations completed successfully\033[0m"
	else
		echo -e "\033[31mIntegration-wb migrations failed\033[0m"
	fi
fi

if [ ${BLE} == "yes" ]; then
	echo -e "\033[32mStart BLE migrations\033[0m"
	kubectl -n ${NS_VMS} rollout status deployment ble-service >/dev/null
	echo -e "\033[32mEnd BLE migrations\033[0m"
fi

echo """
VMS update script completed successfuly!

List of used images:
"""
../kubernetes/print-image-versions.sh ${NS_VMS}