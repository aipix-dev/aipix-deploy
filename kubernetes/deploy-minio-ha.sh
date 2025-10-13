#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

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
until [[ $(kubectl get deployments.apps minio-1 -n ${NS_MINIO} -o jsonpath='{.status.readyReplicas}') -ge 1 ]] && \
	[[ $(kubectl get deployments.apps minio-2 -n ${NS_MINIO} -o jsonpath='{.status.readyReplicas}') -ge 1 ]]; do
	echo "Waiting for starting minio container ..."
	sleep 10
	wait_period=$(($wait_period+10))
	if [ $wait_period -gt 300 ];then
		echo "The script ran for 5 minutes to start containers, exiting now.."
		exit 1
	fi
done


export MINIO_IP1=$(kubectl -n ${NS_MINIO} get service/minio-1 -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
export MINIO_IP2=$(kubectl -n ${NS_MINIO} get service/minio-2 -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')

mc alias set minio-1 http://${MINIO_IP1}:9000 ${MINIO_USR} ${MINIO_PSW}
mc alias set minio-2 http://${MINIO_IP2}:9000 ${MINIO_USR} ${MINIO_PSW}


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


create_minio_bucket -m minio-1 -b ${MINIO_BACKEND_BUCKET_NAME} -a ${MINIO_BACKEND_ACCESS_KEY} -s ${MINIO_BACKEND_SECRET_KEY} -v -p -e 1 -d archive
create_minio_bucket -m minio-2 -b ${MINIO_BACKEND_BUCKET_NAME} -a ${MINIO_BACKEND_ACCESS_KEY} -s ${MINIO_BACKEND_SECRET_KEY} -v -p -e 1 -d archive
create_minio_bucket -m minio-1 -b ${MINIO_BACKEND_BUCKET_NAME_PRIV} -a ${MINIO_BACKEND_ACCESS_KEY_PRIV} -s ${MINIO_BACKEND_SECRET_KEY_PRIV} -v -e 14 -d database_backups
create_minio_bucket -m minio-2 -b ${MINIO_BACKEND_BUCKET_NAME_PRIV} -a ${MINIO_BACKEND_ACCESS_KEY_PRIV} -s ${MINIO_BACKEND_SECRET_KEY_PRIV} -v -e 14 -d database_backups
create_minio_bucket -m minio-1 -b ${MINIO_PORTAL_BUCKET_NAME} -a ${MINIO_PORTAL_ACCESS_KEY} -s ${MINIO_PORTAL_SECRET_KEY} -v -p
create_minio_bucket -m minio-2 -b ${MINIO_PORTAL_BUCKET_NAME} -a ${MINIO_PORTAL_ACCESS_KEY} -s ${MINIO_PORTAL_SECRET_KEY} -v -p
create_minio_bucket -m minio-1 -b ${MINIO_PORTAL_BUCKET_NAME_PRIV} -a ${MINIO_PORTAL_ACCESS_KEY_PRIV} -s ${MINIO_PORTAL_SECRET_KEY_PRIV} -v
create_minio_bucket -m minio-2 -b ${MINIO_PORTAL_BUCKET_NAME_PRIV} -a ${MINIO_PORTAL_ACCESS_KEY_PRIV} -s ${MINIO_PORTAL_SECRET_KEY_PRIV} -v
create_minio_bucket -m minio-1 -b ${MINIO_ANALYTICS_BUCKET_NAME} -a ${MINIO_ANALYTICS_ACCESS_KEY} -s ${MINIO_ANALYTICS_SECRET_KEY} -v -p -e 14
create_minio_bucket -m minio-2 -b ${MINIO_ANALYTICS_BUCKET_NAME} -a ${MINIO_ANALYTICS_ACCESS_KEY} -s ${MINIO_ANALYTICS_SECRET_KEY} -v -p -e 14
create_minio_bucket -m minio-1 -b ${MINIO_LOGS_BUCKET_NAME} -a ${MINIO_LOGS_ACCESS_KEY} -s ${MINIO_LOGS_SECRET_KEY} -v -e 3
create_minio_bucket -m minio-2 -b ${MINIO_LOGS_BUCKET_NAME} -a ${MINIO_LOGS_ACCESS_KEY} -s ${MINIO_LOGS_SECRET_KEY} -v -e 3
create_minio_bucket -m minio-1 -b ${MINIO_GRAFANA_BUCKET_NAME} -a ${MINIO_GRAFANA_ACCESS_KEY} -s ${MINIO_GRAFANA_SECRET_KEY} -v -p
create_minio_bucket -m minio-2 -b ${MINIO_GRAFANA_BUCKET_NAME} -a ${MINIO_GRAFANA_ACCESS_KEY} -s ${MINIO_GRAFANA_SECRET_KEY} -v -p


#Replication
export MINIO_REPLICATION_USER=replication-user
mc admin user add minio-1 ${MINIO_REPLICATION_USER} ${MINIO_PSW}
mc admin user add minio-2 ${MINIO_REPLICATION_USER} ${MINIO_PSW}
mc admin policy attach minio-1 consoleAdmin --user ${MINIO_REPLICATION_USER}
mc admin policy attach minio-2 consoleAdmin --user ${MINIO_REPLICATION_USER}


replicate_minio_bucket () {
	local OPTIND
	local OPTSTRING=":m:r:b:"
	while getopts ${OPTSTRING} opt; do
		case ${opt} in
			m) local MINIO_ALIAS_1=${OPTARG};;
			r) local MINIO_ALIAS_2=${OPTARG};;
			b) local BUCKET_NAME=${OPTARG};;
			:)
				echo "Option -${OPTARG} in replicate_minio_bucket function requires an argument." >&2
				exit 1
				;;
			?)
				echo "Invalid option in replicate_minio_bucket function: -${OPTARG}." >&2
				exit 1
				;;
		esac
	done
	mc replicate add ${MINIO_ALIAS_1}/${BUCKET_NAME} \
			--remote-bucket "http://${MINIO_REPLICATION_USER}:${MINIO_PSW}@${MINIO_ALIAS_2}:9000/${BUCKET_NAME}" \
			--replicate "delete,delete-marker,existing-objects,metadata-sync"
	mc replicate add ${MINIO_ALIAS_2}/${BUCKET_NAME} \
			--remote-bucket "http://${MINIO_REPLICATION_USER}:${MINIO_PSW}@${MINIO_ALIAS_1}:9000/${BUCKET_NAME}" \
			--replicate "delete,delete-marker,existing-objects,metadata-sync"
}


replicate_minio_bucket -m minio-1 -r minio-2 -b ${MINIO_BACKEND_BUCKET_NAME}
replicate_minio_bucket -m minio-1 -r minio-2 -b ${MINIO_BACKEND_BUCKET_NAME_PRIV}
replicate_minio_bucket -m minio-1 -r minio-2 -b ${MINIO_PORTAL_BUCKET_NAME}
replicate_minio_bucket -m minio-1 -r minio-2 -b ${MINIO_PORTAL_BUCKET_NAME_PRIV}
replicate_minio_bucket -m minio-1 -r minio-2 -b ${MINIO_ANALYTICS_BUCKET_NAME}
replicate_minio_bucket -m minio-1 -r minio-2 -b ${MINIO_LOGS_BUCKET_NAME}
replicate_minio_bucket -m minio-1 -r minio-2 -b ${MINIO_GRAFANA_BUCKET_NAME}


echo """
Minio-HA deployment script completed successfuly!

Minio console can be reached with the following URL:
http://${MINIO_IP1}:9090
http://${MINIO_IP2}:9090
https://${MINIO_CONSOLE_DOMAIN_1}
https://${MINIO_CONSOLE_DOMAIN_2}
${MINIO_CONSOLE_DOMAIN_1} and ${MINIO_CONSOLE_DOMAIN_2} should be resolved with DNS-server
"""
