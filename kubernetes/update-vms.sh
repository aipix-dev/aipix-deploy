#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

# Delete registry secrets
kubectl delete secret download-aipix-ai --namespace=${NS_VMS} || true

# Delete VMS configs
kubectl delete secret vms-nginx-cert --namespace=${NS_VMS} || true   #delete in 25.03
kubectl delete secret vms-backend-oauth --namespace=${NS_VMS} || true
kubectl delete configmap vms-nginx-conf --namespace=${NS_VMS} || true  #delete in 25.03
kubectl delete configmap vms-nginx-base-conf --namespace=${NS_VMS} || true   #delete in 25.03
kubectl delete configmap vms-backend-nginx-conf --namespace=${NS_VMS} || true  #delete in 25.03
kubectl delete configmap vms-backend-nginx-server-conf --namespace=${NS_VMS} || true  #delete in 25.03
kubectl delete configmap vms-backend-env --namespace=${NS_VMS} || true
kubectl delete configmap vms-fcm-json  --namespace=${NS_VMS} || true
kubectl delete configmap vms-voip-p8 --namespace=${NS_VMS} || true
kubectl delete configmap vms-frontend-env --namespace=${NS_VMS} || true
kubectl delete configmap push1st-server --namespace=${NS_VMS} || true
kubectl delete configmap push1st-app --namespace=${NS_VMS} || true
kubectl delete configmap push1st-devices --namespace=${NS_VMS} || true

if [ ${TYPE} != "prod" ]; then
	kubectl delete configmap mysql-server-env --namespace=${NS_VMS} || true
	kubectl delete configmap mysql-cnf --namespace=${NS_VMS} || true
else
	kubectl delete configmap overrides-php-ini --namespace=${NS_VMS} || true
	kubectl delete configmap overrides-php-pool-www-conf --namespace=${NS_VMS} || true
fi

# Delete CONTROLLER configmsps
kubectl delete configmap controller-env --namespace=${NS_VMS} || true
kubectl delete configmap controller-nginx-conf --namespace=${NS_VMS} || true   #delete in 25.03
kubectl delete configmap controller-nginx-server-conf --namespace=${NS_VMS} || true   #delete in 25.03

# Delete PORTAL configmsps
if [ ${PORTAL} == "yes" ]; then
  kubectl delete configmap vms-portal-backend-env --namespace=${NS_VMS} || true
  kubectl delete configmap vms-portal-stub-env --namespace=${NS_VMS} || true
fi

# Create registry secrets
kubectl create secret docker-registry download-aipix-ai --namespace=${NS_VMS} \
                                                        --docker-server=https://download.aipix.ai:8443 \
                                                        --docker-username=${DOCKER_USERNAME} \
                                                        --docker-password=${DOCKER_PASSWORD}

# Create VMS configmsps
# kubectl create secret tls vms-nginx-cert --namespace=${NS_VMS} \
#   --cert=../nginx/ssl/tls.crt \
#   --key=../nginx/ssl/tls.key

# kubectl create configmap vms-nginx-conf --namespace=${NS_VMS} --from-file=../nginx/nginx.conf
# kubectl create configmap vms-nginx-base-conf --namespace=${NS_VMS} --from-file=../nginx/nginx-base.conf
# kubectl create configmap vms-backend-nginx-conf --namespace=${NS_VMS} --from-file=../nginx/vms-backend-nginx.conf
# kubectl create configmap vms-backend-nginx-server-conf --namespace=${NS_VMS} --from-file=../nginx/vms-backend-nginx-server.conf
kubectl create configmap vms-backend-env --namespace=${NS_VMS} --from-env-file=../vms-backend/environments/.env
kubectl create configmap vms-fcm-json  --namespace=${NS_VMS} --from-file=../vms-backend/certificates/fcm.json
kubectl create configmap vms-voip-p8 --namespace=${NS_VMS} --from-file=../vms-backend/certificates/voip.p8
kubectl create configmap vms-frontend-env --namespace=${NS_VMS} --from-env-file=../vms-frontend/admin.env
kubectl create configmap push1st-server --namespace=${NS_VMS} --from-file=server.yml=../push1st/server.yml
kubectl create configmap push1st-app --namespace=${NS_VMS} --from-file=../push1st/app.yml
kubectl create configmap push1st-devices --namespace=${NS_VMS} --from-file=../push1st/devices.yml

# Generate oauth-private.key, oauth-public.key, file.key and create configmap
openssl genpkey -algorithm RSA -out ../vms-backend/certificates/private_key.pem -pkeyopt rsa_keygen_bits:4096 > /dev/null 2>&1
openssl rsa -in ../vms-backend/certificates/private_key.pem  -pubout -out ../vms-backend/certificates/public_key.pem > /dev/null 2>&1
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
else
    kubectl create configmap overrides-php-ini --namespace=${NS_VMS} --from-file=../vms-backend/99-overrides-php.ini
    kubectl create configmap overrides-php-pool-www-conf --namespace=${NS_VMS} --from-file=z-overrides-www.conf=../vms-backend/z-overrides-pool-www.conf
fi

if [ ${VMS_LIC_OFFLINE} == "yes" ]; then
	kubectl delete configmap vms-backend-license --namespace=${NS_VMS} || true
	kubectl create configmap vms-backend-license --namespace=${NS_VMS}  --from-file=../vms-backend/license/license.json
fi

# Create CONTROLLER configmsps
kubectl create configmap controller-env --namespace=${NS_VMS} --from-env-file=../controller/environments/.env
# kubectl create configmap controller-nginx-conf --namespace=${NS_VMS} --from-file=../nginx/controller-nginx.conf
# kubectl create configmap controller-nginx-server-conf --namespace=${NS_VMS} --from-file=../nginx/controller-nginx-server.conf

# Create PORTAL configmsps
if [ ${PORTAL} == "yes" ]; then
	kubectl create configmap vms-portal-backend-env --namespace=${NS_VMS} --from-env-file=../portal/environments/.env
	kubectl create configmap vms-portal-stub-env --namespace=${NS_VMS} --from-env-file=../portal/environments-stub/.env
fi

#Reapplying vms
../kustomize/deployments/${VMS_TEMPLATE}/update-kustomization.sh || exit 1
kubectl apply -k ../kustomize/deployments/${VMS_TEMPLATE}

sleep 5

#Waiting for containers are started
wait_period=0
for deployment in $(kubectl -n ${NS_VMS} get deployment | awk 'NR>1 { print $1 }')
do
	wait_period=$(($wait_period+10))
	if [ $wait_period -gt 500 ];then
    	echo "The script ran for 8 minutes to start containers, exiting now.."
    	break
  	fi
  	replicas=$(kubectl get deployment $deployment -n ${NS_VMS} -o jsonpath='{.status.replicas}')
  	ready_replicas=$(kubectl get deployment $deployment -n ${NS_VMS} -o jsonpath='{.status.availableReplicas}')
  	while [[ ${replicas} != ${ready_replicas} ]]
  	do
    	echo "Waiting for updating containers ..."
    	sleep 5
    	replicas=$(kubectl get deployment $deployment -n ${NS_VMS} -o jsonpath='{.status.replicas}')
    	ready_replicas=$(kubectl get deployment $deployment -n ${NS_VMS} -o jsonpath='{.status.availableReplicas}')
  	done
done
echo "Manifests were successfully aplied"

#Rollout restart
for i in $(kubectl get deployments -n ${NS_VMS} | awk 'NR>1 { print $1 }'); do kubectl rollout restart deployment.apps/$i  -n ${NS_VMS}; done
kubectl -n ${NS_VMS} rollout status deployment backend >/dev/null
kubectl -n ${NS_VMS} rollout status deployment controller-api >/dev/null
if [ ${TYPE} != "prod" ]; then
    kubectl -n ${NS_VMS} rollout status deployment mysql-server >/dev/null
fi

echo "Deployments were successfully restarted"
sleep 15

kubectl -n ${NS_VMS} exec deployment.apps/backend -- ./scripts/update.sh
kubectl -n ${NS_VMS} exec deployment.apps/backend -- chown www-data:www-data -R storage/logs
kubectl -n ${NS_VMS} exec deployment.apps/controller-api -- ./scripts/update.sh

if [ ${PORTAL} == "yes" ]; then
	kubectl -n ${NS_VMS} rollout status deployment portal-backend >/dev/null
	kubectl -n ${NS_VMS} rollout status deployment portal-stub >/dev/null
	kubectl -n ${NS_VMS} exec deployment.apps/portal-backend -- ./scripts/update.sh
	kubectl -n ${NS_VMS} exec deployment.apps/portal-stub -- ./scripts/update.sh
fi

if [[ ${TYPE} == "single" ]] && [[ ${BACKEND_STORAGE_TYPE} == "s3_and_disk" ]]; then
	kubectl --namespace=${NS_VMS} exec deployments/backend -- cat storage/file.key > ../vms-backend/certificates/file.key
	kubectl --namespace=${NS_VMS} exec deployments/backend -- cat storage/oauth-public.key > ../vms-backend/certificates/oauth-public.key
	kubectl --namespace=${NS_VMS} exec deployments/backend -- cat storage/oauth-private.key > ../vms-backend/certificates/oauth-private.key
fi

# VMS_IP=$(kubectl -n ${TRAEFIK_NAMESPACE} get services/traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo """
VMS update script completed successfuly!

Update script completed successfuly!
Access your VMS with the following URL:
https://${VMS_DOMAIN}/admin
"""
