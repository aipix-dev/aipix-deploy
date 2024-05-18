#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

MS=$1 			# Media server ip address #
USERNAME=$2
CONFIGURE=$3
PORT=22
SSH_OPTIONS="-o StrictHostKeyChecking=no"
MS_TYPE="vsaas"
BRAND="aipix"

if [ -z "${MS}" ]; then
    echo >&2  "ERROR: MSE IP address is not defined"
    exit 2
fi

#Creating base configs for MSE
if [ -z "${CONFIGURE}" ]; then
	cp -n ./sources.sh.sample ./sources.sh
    cp -n ../mse/key.pem.sample ../mse/key.pem
    cp -n ../mse/cert.pem.sample ../mse/cert.pem
	cp -n ../mse/public.key.sample ../mse/public.key
	cp -n ../mse/license.json.sample ../mse/license.json
	cp -n ../mse/server.json.sample ../mse/server.json.${MS}.${MS_TYPE}
	cp -n ../mse/streams.json.sample ../mse/streams.json.${MS}.${MS_TYPE}
	sed -i 's@\("hostname":\).*@\1 '\"${MS}\"',@g' ../mse/server.json.${MS}.${MS_TYPE}
	sed -i 's@\("webhook":\).*@\1 '\"http://controller-api.${NS_VMS}.svc/controller/api/v1/mse/callback\"',@g' ../mse/server.json.${MS}.${MS_TYPE}
fi

if [[ ${CONFIGURE} == "configure" ]]; then
	ssh -p ${PORT} ${SSH_OPTIONS} ${USERNAME}@${MS} sudo mkdir -p /opt/${MS_TYPE}/mse/licenses
	ssh -p ${PORT} ${SSH_OPTIONS} ${USERNAME}@${MS} sudo mkdir -p /opt/${MS_TYPE}/mse/streams
	ssh -p ${PORT} ${SSH_OPTIONS} ${USERNAME}@${MS} sudo mkdir -p /opt/${MS_TYPE}/mse/configs
	rsync -e "ssh -p ${PORT} ${SSH_OPTIONS}" --rsync-path="sudo rsync" ../mse/server.json.${MS}.${MS_TYPE} ${USERNAME}@${MS}:/opt/${MS_TYPE}/mse/configs/server.json
	rsync -e "ssh -p ${PORT} ${SSH_OPTIONS}" --rsync-path="sudo rsync" ../mse/streams.json.${MS}.${MS_TYPE} ${USERNAME}@${MS}:/opt/${MS_TYPE}/mse/streams/streams.json
	rsync -e "ssh -p ${PORT} ${SSH_OPTIONS}" --rsync-path="sudo rsync" ../mse/license.json ${USERNAME}@${MS}:/opt/${MS_TYPE}/mse/licenses/license.json || true
	rsync -e "ssh -p ${PORT} ${SSH_OPTIONS}" --rsync-path="sudo rsync" ../mse/public.key ${USERNAME}@${MS}:/opt/${MS_TYPE}/mse/licenses/public.key || true

	echo """

	Configuration script is finished successfuly!

	"""
fi
