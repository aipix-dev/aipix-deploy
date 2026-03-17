#!/bin/bash -e

ONLINE_SERVICE_DOMAIN=$1 #Type of deployment (test1, ios, android ...)

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

# Creating config files for online-service
cp -n ../online-service/environments/env.sample ../online-service/environments/.env
cp -n ../kustomize/apps/vms/online-service/manifests.yaml.template ../kustomize/apps/vms/online-service/manifests.yaml

# Chek ONLINE_SERVICE_DOMAIN variable
if grep -q "example.com" ../kustomize/apps/vms/online-service/manifests.yaml && [ -z "${ONLINE_SERVICE_DOMAIN}" ]; then
	echo >&2 "ERROR: domain for online-service is not defined"
	exit 2
fi

# Create database, user, grant permissions
IFS="=" read name DB_HOST <<<$(cat ../online-service/environments/.env | grep DB_HOST)
IFS="=" read name DB_PORT <<<$(cat ../online-service/environments/.env | grep -i DB_PORT)
IFS="=" read name DB_NAME <<<$(cat ../online-service/environments/.env | grep -i DB_NAME)
IFS="=" read name DB_USER <<<$(cat ../online-service/environments/.env | grep -i DB_USER)
IFS="=" read name DB_PASSWORD <<<$(cat ../online-service/environments/.env | grep -i DB_PASSWORD)

CREATE_DATABASE="CREATE DATABASE IF NOT EXISTS ${DB_NAME} character set 'utf8mb4' collate 'utf8mb4_unicode_ci';"
CREATE_USER="CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';"
GRANT_PRIVILEGES="GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';FLUSH PRIVILEGES;"

kubectl exec -n ${NS_VMS} deployment.apps/backend -- mysql --protocol=TCP -u root -pmysql -P ${DB_PORT} -h ${DB_HOST} --execute="${CREATE_DATABASE}"
kubectl exec -n ${NS_VMS} deployment.apps/backend -- mysql --protocol=TCP -u root -pmysql -P ${DB_PORT} -h ${DB_HOST} --execute="${CREATE_USER}"
kubectl exec -n ${NS_VMS} deployment.apps/backend -- mysql --protocol=TCP -u root -pmysql -P ${DB_PORT} -h ${DB_HOST} --execute="${GRANT_PRIVILEGES}"

# Create minio bucket
create_minio_bucket() {
	local OPTIND
	local OPTSTRING=":m:b:a:s:pve:d:"
	while getopts ${OPTSTRING} opt; do
		case ${opt} in
		m) local MINIO_ALIAS=${OPTARG} ;;
		b) local BUCKET_NAME=${OPTARG} ;;
		a) local BUCKET_ACCESS_KEY=${OPTARG} ;;
		s) local BUCKET_SECRET_KEY=${OPTARG} ;;
		p) local PUBLIC="public" ;;
		v) local VERSIONING="enabled" ;;
		e) local EXPIRE=${OPTARG} ;;
		d) local BUCKET_PATH1=${OPTARG} ;;
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
	cat <<EOF >/tmp/${BUCKET_NAME}-policy.json
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
		cat <<EOF >/tmp/${BUCKET_NAME}-anonymous-policy.json
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

if [ ${TYPE} == "prod" ]; then
	S3_PORT_INTERNAL=""
else
	S3_PORT_INTERNAL=":9000"
fi

MINIO_ONLINE_BUCKET_NAME="online-service"
MINIO_ONLINE_ACCESS_KEY=$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 20 | head -n 1 | xargs echo -n)
MINIO_ONLINE_SECRET_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 40 | head -n 1 | xargs echo -n)
JWT_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 | xargs echo -n)

create_minio_bucket -m local -b ${MINIO_ONLINE_BUCKET_NAME} -a ${MINIO_ONLINE_ACCESS_KEY} -s ${MINIO_ONLINE_SECRET_KEY} -p

# Configure online-service envs
grep -q 'MINIO_BUCKET=$' ../online-service/environments/.env && sed -i "s@MINIO_BUCKET=\$@MINIO_BUCKET=${MINIO_ONLINE_BUCKET_NAME}@g" ../online-service/environments/.env
grep -q 'MINIO_ACCESS_KEY=$' ../online-service/environments/.env && sed -i "s@MINIO_ACCESS_KEY=\$@MINIO_ACCESS_KEY=${MINIO_ONLINE_ACCESS_KEY}@g" ../online-service/environments/.env
grep -q 'MINIO_SECRET_KEY=$' ../online-service/environments/.env && sed -i "s@MINIO_SECRET_KEY=\$@MINIO_SECRET_KEY=${MINIO_ONLINE_SECRET_KEY}@g" ../online-service/environments/.env
sed -i "s@MINIO_ENDPOINT=.*@MINIO_ENDPOINT=minio.${NS_MINIO}.svc${S3_PORT_INTERNAL}@g" ../online-service/environments/.env

grep -q 'JWT_SECRET=$' ../online-service/environments/.env && sed -i "s@JWT_SECRET=\$@JWT_SECRET=${JWT_SECRET}@" ../online-service/environments/.env

sed -i "s@example.com@${ONLINE_SERVICE_DOMAIN}@g" ../kustomize/apps/vms/online-service/manifests.yaml

# Recreate configmap
kubectl delete configmap online-env --namespace=${NS_VMS} || true
kubectl create configmap online-env --namespace=${NS_VMS} --from-env-file=../online-service/environments/.env

# kubectl apply
kubectl apply -f ../kustomize/apps/vms/online-service/manifests.yaml

kubectl --namespace=${NS_VMS} rollout restart deployment online-service
kubectl --namespace=${NS_VMS} rollout status deployment online-service

echo """

Online-service deployment script completed successfuly!

"""
