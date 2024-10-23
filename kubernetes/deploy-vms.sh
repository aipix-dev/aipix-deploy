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
kubectl create secret tls vms-nginx-cert --namespace=${NS_VMS} \
                                        --cert=../nginx/ssl/tls.crt \
                                        --key=../nginx/ssl/tls.key
kubectl create configmap vms-nginx-conf --namespace=${NS_VMS} --from-file=../nginx/nginx.conf
kubectl create configmap vms-nginx-base-conf --namespace=${NS_VMS} --from-file=../nginx/nginx-base.conf
kubectl create configmap vms-backend-nginx-conf --namespace=${NS_VMS} --from-file=../nginx/vms-backend-nginx.conf
kubectl create configmap vms-backend-nginx-server-conf --namespace=${NS_VMS} --from-file=../nginx/vms-backend-nginx-server.conf
kubectl create configmap vms-backend-env --namespace=${NS_VMS} --from-env-file=../vms-backend/environments/.env
kubectl create configmap vms-fcm-json  --namespace=${NS_VMS} --from-file=../vms-backend/certificates/fcm.json
kubectl create configmap vms-voip-p8 --namespace=${NS_VMS} --from-file=../vms-backend/certificates/voip.p8
kubectl create configmap vms-frontend-env --namespace=${NS_VMS} \
                                          --from-env-file=../vms-frontend/admin.env \
                                          --from-env-file=../vms-frontend/client.env
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
	kubectl create configmap vms-backend-license --namespace=${NS_VMS} --from-file=../vms-backend/license/license.json
fi

if [ ${ANALYTICS} == "yes" ]; then
	kubectl create configmap push1st-orchestrator --namespace=${NS_VMS} --from-file=../push1st/orchestrator.yml --dry-run=client -o yaml | \
	sed -e "s@http://django:8000/api/events/@http://orchestrator.${NS_A}.svc/api/events/@g" | kubectl apply -f-
fi


# Create CONTROLLER configmsps
kubectl create configmap controller-env --namespace=${NS_VMS} --from-env-file=../controller/environments/.env
kubectl create configmap controller-nginx-conf --namespace=${NS_VMS} --from-file=../nginx/controller-nginx.conf
kubectl create configmap controller-nginx-server-conf --namespace=${NS_VMS} --from-file=../nginx/controller-nginx-server.conf


#Create PORTAL configmaps
if [ ${PORTAL} == "yes" ]; then
    kubectl create configmap vms-portal-backend-env --namespace=${NS_VMS} --from-env-file=../portal/environments/.env
    kubectl create configmap vms-portal-stub-env --namespace=${NS_VMS} --from-env-file=../portal/environments-stub/.env
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
        [[ $(kubectl get deployment cron -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]] && \
        [[ $(kubectl get deployment backend -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]        
    then break
    fi
    sleep 5
    echo "Waiting for starting containers ..."
done
sleep 10

kubectl exec -n ${NS_VMS} deployment.apps/backend -- ./scripts/create_db.sh
kubectl exec -n ${NS_VMS} deployment.apps/backend -- ./scripts/start.sh
kubectl exec -n ${NS_VMS} deployment.apps/backend  -- chown www-data:www-data -R storage/logs

kubectl exec -n ${NS_VMS} deployment.apps/controller-api -- ./scripts/create_db.sh
kubectl exec -n ${NS_VMS} deployment.apps/controller-api -- ./scripts/start.sh

if [ ${PORTAL} == "yes" ]; then
    kubectl -n ${NS_VMS} exec deployment.apps/portal-backend -- ./scripts/create_db.sh
    kubectl -n ${NS_VMS} exec deployment.apps/portal-stub -- ./scripts/create_db.sh
    kubectl -n ${NS_VMS} exec deployment.apps/portal-backend -- ./scripts/start.sh
    kubectl -n ${NS_VMS} exec deployment.apps/portal-stub -- ./scripts/start.sh
fi

# VMS_IP=$(kubectl get service/nginx -n ${NS_VMS} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
VMS_IP=$(kubectl -n ${TRAEFIK_NAMESPACE} get services/traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo """
Deployment script completed successfuly!

Access your VMS with the following URL:
http://${VMS_IP}/admin
https://${VMS_DOMAIN}/admin (${VMS_DOMAIN} should be resolved on DNS-server)
"""
