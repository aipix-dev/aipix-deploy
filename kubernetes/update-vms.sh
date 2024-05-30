#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

# Delete registry secrets
kubectl delete secret download-aipix-ai --namespace=${NS_VMS} || true

# Delete VMS configs
kubectl delete secret vms-nginx-cert --namespace=${NS_VMS} || true
kubectl delete configmap vms-nginx-conf --namespace=${NS_VMS} || true
kubectl delete configmap vms-nginx-base-conf --namespace=${NS_VMS} || true
kubectl delete configmap vms-backend-nginx-conf --namespace=${NS_VMS} || true
kubectl delete configmap vms-backend-nginx-server-conf --namespace=${NS_VMS} || true
kubectl delete configmap vms-backend-env --namespace=${NS_VMS} || true
kubectl delete configmap vms-fcm-json  --namespace=${NS_VMS} || true
kubectl delete configmap vms-voip-p8 --namespace=${NS_VMS} || true
kubectl delete configmap vms-frontend-env --namespace=${NS_VMS} || true
kubectl delete configmap mysql-server-env --namespace=${NS_VMS} || true
kubectl delete configmap mysql-cnf --namespace=${NS_VMS} || true
kubectl delete configmap push1st-server --namespace=${NS_VMS} || true
kubectl delete configmap push1st-app --namespace=${NS_VMS} || true

# Delete CONTROLLER configmsps
kubectl delete configmap controller-env --namespace=${NS_VMS} || true
kubectl delete configmap controller-nginx-conf --namespace=${NS_VMS} || true
kubectl delete configmap controller-nginx-server-conf --namespace=${NS_VMS} || true

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
kubectl create configmap mysql-server-env --namespace=${NS_VMS} --from-env-file=../mysql-server/mysql-server.env
kubectl create configmap mysql-cnf --namespace=${NS_VMS} --from-file=../mysql-server/my.cnf
kubectl create configmap push1st-server --namespace=${NS_VMS} --from-file=server.yml=../push1st/server.yml
kubectl create configmap push1st-app --namespace=${NS_VMS} --from-file=../push1st/app.yml

if [ ${VMS_LIC_OFFLINE} == "yes" ]; then
  kubectl delete configmap vms-backend-license --namespace=${NS_VMS}
  kubectl create configmap vms-backend-license --namespace=${NS_VMS}  --from-file=../vms-backend/license/license.json
fi

# Create CONTROLLER configmsps
kubectl create configmap controller-env --namespace=${NS_VMS} --from-env-file=../controller/environments/.env
kubectl create configmap controller-nginx-conf --namespace=${NS_VMS} --from-file=../nginx/controller-nginx.conf
kubectl create configmap controller-nginx-server-conf --namespace=${NS_VMS} --from-file=../nginx/controller-nginx-server.conf

# Create PORTAL configmsps
if [ ${PORTAL} == "yes" ]; then
  kubectl create configmap vms-portal-backend-env --namespace=${NS_VMS} --from-env-file=../portal/environments/.env
  kubectl create configmap vms-portal-stub-env --namespace=${NS_VMS} --from-env-file=../portal/environments-stub/.env
fi

#Rollout restart
for i in $(kubectl get deployments -n ${NS_VMS} | awk 'NR>1 { print $1 }'); do kubectl rollout restart  deployment.apps/$i  -n ${NS_VMS}; done

#Reapplying vms
../kustomize/deployments/${VMS_TEMPLATE}/update-kustomization.sh || exit 1
kubectl apply -k ../kustomize/deployments/${VMS_TEMPLATE}

#Waiting for containers are started
while true
do
  if [[ $(kubectl get deployment mysql-server -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]] && \
      [[ $(kubectl get deployment backend -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]
      [[ $(kubectl get deployment controller -n ${NS_VMS} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]
  then break
  fi
  sleep 5
  echo "Waiting for updating containers ..."
done

sleep 10

kubectl -n ${NS_VMS} exec deployment.apps/backend -- ./scripts/update.sh
kubectl -n ${NS_VMS} exec deployment.apps/backend -- chown www-data:www-data -R storage/logs
kubectl -n ${NS_VMS} exec deployment.apps/controller -- ./scripts/update.sh

if [ ${PORTAL} == "yes" ]; then
  kubectl -n ${NS_VMS} exec deployment.apps/portal-backend -- ./scripts/update.sh
  kubectl -n ${NS_VMS} exec deployment.apps/portal-stub -- ./scripts/update.sh
fi

VMS_IP=$(kubectl -n ${TRAEFIK_NAMESPACE} get services/traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "
Your containers are updated successfully!

Update script completed successfuly!
Access your VMS with the following URL:
https://${VMS_IP}/admin
https://${VMS_DOMAIN}/admin
"
