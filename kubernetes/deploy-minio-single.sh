#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh
source ./k8s-onprem/sources.sh

export PATH=$PATH:$HOME/minio-binaries/
kubectl create ns ${NS_MINIO}

kubectl create secret generic minio-secret -n ${NS_MINIO} --from-literal="username=${MINIO_USR}" --from-literal="password=${MINIO_PSW}"

# Deploying Minio s3
../kustomize/deployments/${MINIO_TEMPLATE}/update-kustomization.sh || exit 1
kubectl apply -k ../kustomize/deployments/${MINIO_TEMPLATE}

echo "Minio manifests are applied !"
sleep 10

# Waiting for starting containers
wait_period=0
until [[ $(kubectl get deployments.apps minio -n ${NS_MINIO} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]; do
	echo "Waiting for starting minio container ..."
	sleep 10
	wait_period=$(($wait_period+10))
	if [ $wait_period -gt 300 ];then
		echo "The script ran for 5 minutes to start containers, exiting now.."
		exit 1
	fi
done

# export MINIO_IP=$(kubectl -n ${NS_MINIO} get service/minio -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
export MINIO_IP=${K8S_API_ENDPOINT}
# MINIO_IP=$(kubectl -n ${TRAEFIK_NAMESPACE} get services/traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# MINIO_IP =$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}') # for GKE

mc alias set local http://${MINIO_IP}:30900 ${MINIO_USR} ${MINIO_PSW}


create_minio_bucket () {
	local OPTIND
	local OPTSTRING=":m:b:a:s:pve:d:"
	while getopts ${OPTSTRING} opt; do
		case ${opt} in
			m) local MINIO_ALIAS=${OPTARG};;
			b) local BUCKET_NAME=${OPTARG};;
			a) local BUCKET_ACCESS_KEY=${OPTARG};;
			s) local BUCKET_SECRET_KEY=${OPTARG};;
			p) local PUBLIC="public";;
			v) local VERSIONING="enabled";;
			e) local EXPIRE=${OPTARG};;
			d) local BUCKET_PATH1=${OPTARG};;
			:)
				echo "Option -${OPTARG} in create_minio_bucket function requires an argument." >&2
				exit 1
				;;
			?)
				echo "Invalid option in create_minio_bucket function: -${OPTARG}." >&2
				exit 1
				;;
		esac
	done

	if [[ $(mc ls ${MINIO_ALIAS} | grep ${BUCKET_NAME}/) ]]; then
		echo "Bucket ${BUCKET_NAME} already exists"
		return
	fi
	mc mb -p ${MINIO_ALIAS}/${BUCKET_NAME}
	cat <<EOF > /tmp/${BUCKET_NAME}-policy.json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": [
				"s3:*"
			],
			"Resource": [
				"arn:aws:s3:::${BUCKET_NAME}/*"
			]
		}
	]
}
EOF
	mc admin policy create ${MINIO_ALIAS} ${BUCKET_NAME}-policy /tmp/${BUCKET_NAME}-policy.json
	mc admin user add ${MINIO_ALIAS} ${BUCKET_NAME}-user ${MINIO_PSW}
	mc admin user svcacct add ${MINIO_ALIAS} ${BUCKET_NAME}-user --access-key ${BUCKET_ACCESS_KEY} --secret-key ${BUCKET_SECRET_KEY}
	mc admin policy attach ${MINIO_ALIAS} ${BUCKET_NAME}-policy --user ${BUCKET_NAME}-user
	if [[ ${PUBLIC} == "public" ]]; then
		cat <<EOF > /tmp/${BUCKET_NAME}-anonymous-policy.json
{
 "Statement": [
  {
   "Action": [
    "s3:GetBucketLocation"
   ],
   "Effect": "Allow",
   "Principal": {
    "AWS": [
     "*"
    ]
   },
   "Resource": [
    "arn:aws:s3:::${BUCKET_NAME}"
   ]
  },
  {
   "Action": [
    "s3:GetObject"
   ],
   "Effect": "Allow",
   "Principal": {
    "AWS": [
     "*"
    ]
   },
   "Resource": [
    "arn:aws:s3:::${BUCKET_NAME}/*"
   ]
  }
 ],
 "Version": "2012-10-17"
}
EOF
		mc anonymous set-json /tmp/${BUCKET_NAME}-anonymous-policy.json ${MINIO_ALIAS}/${BUCKET_NAME}
	fi
	if [[ ${VERSIONING} == "enabled" ]]; then
		mc version enable ${MINIO_ALIAS}/${BUCKET_NAME}
		mc ilm rule add ${MINIO_ALIAS}/${BUCKET_NAME} --noncurrent-expire-days "1" --expire-delete-marker
	fi

	if [[ -n ${EXPIRE} ]]; then
		if [[ -z ${BUCKET_PATH1} ]]; then
			mc ilm rule add ${MINIO_ALIAS}/${BUCKET_NAME} --expire-days "${EXPIRE}"
		else
			mc ilm rule add ${MINIO_ALIAS}/${BUCKET_NAME}/${BUCKET_PATH1} --expire-days "${EXPIRE}"
		fi
	fi
}


create_minio_bucket -m local -b ${MINIO_BACKEND_BUCKET_NAME} -a ${MINIO_BACKEND_ACCESS_KEY} -s ${MINIO_BACKEND_SECRET_KEY} -p -e 1 -d archive
create_minio_bucket -m local -b ${MINIO_BACKEND_BUCKET_NAME_PRIV} -a ${MINIO_BACKEND_ACCESS_KEY_PRIV} -s ${MINIO_BACKEND_SECRET_KEY_PRIV} -e 14 -d database_backups
create_minio_bucket -m local -b ${MINIO_PORTAL_BUCKET_NAME} -a ${MINIO_PORTAL_ACCESS_KEY} -s ${MINIO_PORTAL_SECRET_KEY} -p
create_minio_bucket -m local -b ${MINIO_PORTAL_BUCKET_NAME_PRIV} -a ${MINIO_PORTAL_ACCESS_KEY_PRIV} -s ${MINIO_PORTAL_SECRET_KEY_PRIV}
create_minio_bucket -m local -b ${MINIO_ANALYTICS_BUCKET_NAME} -a ${MINIO_ANALYTICS_ACCESS_KEY} -s ${MINIO_ANALYTICS_SECRET_KEY} -p -e 14
create_minio_bucket -m local -b ${MINIO_LOGS_BUCKET_NAME} -a ${MINIO_LOGS_ACCESS_KEY} -s ${MINIO_LOGS_SECRET_KEY} -e 3
create_minio_bucket -m local -b ${MINIO_GRAFANA_BUCKET_NAME} -a ${MINIO_GRAFANA_ACCESS_KEY} -s ${MINIO_GRAFANA_SECRET_KEY} -p

echo """
Minio-single deployment script completed successfuly!

Minio console can be reached with the following URL:
http://${K8S_API_ENDPOINT}:30090
https://${MINIO_CONSOLE_DOMAIN} (${MINIO_CONSOLE_DOMAIN} should be resolved on DNS-server)
"""
