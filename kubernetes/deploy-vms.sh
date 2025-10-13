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
kubectl create configmap push1st-server --namespace=${NS_VMS} --from-file=server.yml=../push1st/server.yml
kubectl create configmap push1st-app --namespace=${NS_VMS} --from-file=../push1st/app.yml
kubectl create configmap push1st-devices --namespace=${NS_VMS} --from-file=../push1st/devices.yml

# Generate oauth-private.key, oauth-public.key, file.key and create configmap
openssl genpkey -algorithm RSA -out ../vms-backend/certificates/private_key.pem -pkeyopt rsa_keygen_bits:4096 > /dev/null 2>&1
openssl rsa -in ../vms-backend/certificates/private_key.pem -pubout -out ../vms-backend/certificates/public_key.pem > /dev/null 2>&1
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 300 | head -n 1 | xargs echo -n > ../vms-backend/certificates/file.key.tmp
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
	kubectl create configmap vms-backend-license --namespace=${NS_VMS} --from-file=../vms-backend/license/license.json
fi

if [ ${ANALYTICS} == "yes" ]; then
	kubectl create configmap push1st-orchestrator --namespace=${NS_VMS} --from-file=../push1st/orchestrator.yml --dry-run=client -o yaml | \
	sed -e "s@http://django:8000/api/events/@http://orchestrator.${NS_A}.svc/api/events/@g" | kubectl apply -f-
fi

# Create CONTROLLER configmsps
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

# Deploying VMS
../kustomize/deployments/${VMS_TEMPLATE}/update-kustomization.sh || exit 1
kubectl apply -k ../kustomize/deployments/${VMS_TEMPLATE}

echo "VMS manifests are applied !"
sleep 10

while true
do
	if ([[ ${TYPE} == "prod" ]] || [[ $(kubectl get deployment mysql-server -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]) && \
		[[ $(kubectl get deployment controller-api -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]] && \
		[[ $(kubectl get deployment backend -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]
	then break
	fi
	sleep 5
	echo "Waiting for starting backend and controller containers ..."
done

if [ ${PORTAL} == "yes" ]; then
	while true
	do
		if [[ $(kubectl get deployment portal-backend -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]] && \
			[[ $(kubectl get deployment portal-stub -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]
		then break
		fi
		sleep 5
		echo "Waiting for starting portal-backend and portal-stub containers ..."
	done
fi

if [ ${WB} == "yes" ]; then
	while true
	do
		if [[ $(kubectl get deployment integration-wb -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]
		then break
		fi
		sleep 5
		echo "Waiting for starting integration-wb container ..."
	done
fi

sleep 10
echo -e "\033[32mStart backend migrations\033[0m"
kubectl exec -n ${NS_VMS} deployment.apps/backend -- ./scripts/create_db.sh
kubectl exec -n ${NS_VMS} deployment.apps/backend -- ./scripts/start.sh
kubectl exec -n ${NS_VMS} deployment.apps/backend -- chown www-data:www-data -R storage/logs
echo -e "\033[32mEnd backend migrations\033[0m"

echo -e "\033[32mStart controller migrations\033[0m"
kubectl exec -n ${NS_VMS} deployment.apps/controller-api -- ./scripts/create_db.sh
kubectl exec -n ${NS_VMS} deployment.apps/controller-api -- ./scripts/start.sh
echo -e "\033[32mEnd controller migrations\033[0m"

if [ ${TYPE} != "prod" ]; then
	CREATE_MONITORING_MYSQL_USER="CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY 'password' WITH MAX_USER_CONNECTIONS 3;"
	GRANT_PRIVILEGES="GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';FLUSH PRIVILEGES;"
	kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysql --protocol=TCP -u root -pmysql --execute="${CREATE_MONITORING_MYSQL_USER}"
	kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysql --protocol=TCP -u root -pmysql --execute="${GRANT_PRIVILEGES}"
fi

if [ ${PORTAL} == "yes" ]; then
	echo -e "\033[32mStart portal migrations\033[0m"
	kubectl -n ${NS_VMS} exec deployment.apps/portal-backend -- ./scripts/create_db.sh
	kubectl -n ${NS_VMS} exec deployment.apps/portal-stub -- ./scripts/create_db.sh
	kubectl -n ${NS_VMS} exec deployment.apps/portal-backend -- ./scripts/start.sh
	kubectl -n ${NS_VMS} exec deployment.apps/portal-stub -- ./scripts/start.sh
	echo -e "\033[32mEnd portal migrations\033[0m"
fi

if [ ${WB} == "yes" ]; then
	echo -e "\033[32mStart WB migrations\033[0m"
	kubectl -n ${NS_VMS} exec deployment.apps/integration-wb -- ./scripts/create_db.sh
	kubectl -n ${NS_VMS} exec deployment.apps/integration-wb -- ./scripts/start.sh
	echo -e "\033[32mEnd WB migrations\033[0m"
fi

VMS_IP=$(kubectl -n ${TRAEFIK_NAMESPACE} get services/traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo """

VMS deployment script completed successfuly!

Access your VMS with the following URL:
http://${VMS_IP}/admin
https://${VMS_DOMAIN}/admin (${VMS_DOMAIN} should be resolved on DNS-server)
"""
