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
    echo >&2  "ERROR: Mediaserver IP address is not defined"
    exit 2
fi

#Creating base configs for mediaserver
if [ -z "${CONFIGURE}" ]; then
	cp -n ./sources.sh.sample ./sources.sh
    cp -n ../mediaserver/key.pem.sample ../mediaserver/key.pem
    cp -n ../mediaserver/cert.pem.sample ../mediaserver/cert.pem
	cp -n ../mediaserver/public.key.sample ../mediaserver/public.key
	cp -n ../mediaserver/license.json.sample ../mediaserver/license.json
	cp -n ../mediaserver/media-server.ini.sample ../mediaserver/media-server.ini.${MS}.${MS_TYPE}
	sed -i "s@\(node-host.*=\).*@\1 ${MS}@g" ../mediaserver/media-server.ini.${MS}.${MS_TYPE}
	sed -i "s@\(cluster-controller.*=\).*@\1 http://controller-api.${NS_VMS}.svc/controller/api/v1/mediaserver/callback@g" ../mediaserver/media-server.ini.${MS}.${MS_TYPE}
	cp -n ../mediaserver/media-server.nodes.sample ../mediaserver/media-server.nodes.${MS}.${MS_TYPE}
	cp -n ../mediaserver/env.sample ../mediaserver/.env.${MS}.${MS_TYPE}
	# sed -i "s@^\(LICENSE_SOURCE=\).*@\1/etc/${BRAND}/media-server@g" ../mediaserver/.env.${MS}.${MS_TYPE}
fi

if [[ ${CONFIGURE} == "configure" ]]; then
	ssh -p ${PORT} ${SSH_OPTIONS} ${USERNAME}@${MS} sudo mkdir -p /opt/${MS_TYPE}/mediaserver/licenses
	ssh -p ${PORT} ${SSH_OPTIONS} ${USERNAME}@${MS} sudo mkdir -p /opt/${MS_TYPE}/mediaserver/streams
	ssh -p ${PORT} ${SSH_OPTIONS} ${USERNAME}@${MS} sudo mkdir -p /opt/${MS_TYPE}/mediaserver/configs
	rsync -e "ssh -p ${PORT} ${SSH_OPTIONS}" --rsync-path="sudo rsync" ../mediaserver/media-server.ini.${MS}.${MS_TYPE} ${USERNAME}@${MS}:/opt/${MS_TYPE}/mediaserver/configs/media-server.ini
	rsync -e "ssh -p ${PORT} ${SSH_OPTIONS}" --rsync-path="sudo rsync" ../mediaserver/media-server.nodes.${MS}.${MS_TYPE} ${USERNAME}@${MS}:/opt/${MS_TYPE}/mediaserver/configs/media-server.nodes
	rsync -e "ssh -p ${PORT} ${SSH_OPTIONS}" --rsync-path="sudo rsync" ../mediaserver/.env.${MS}.${MS_TYPE} ${USERNAME}@${MS}:/opt/${MS_TYPE}/mediaserver/configs/.env
	rsync -e "ssh -p ${PORT} ${SSH_OPTIONS}" --rsync-path="sudo rsync" ../mediaserver/license.json ${USERNAME}@${MS}:/opt/${MS_TYPE}/mediaserver/licenses/license.json || true
	rsync -e "ssh -p ${PORT} ${SSH_OPTIONS}" --rsync-path="sudo rsync" ../mediaserver/public.key ${USERNAME}@${MS}:/opt/${MS_TYPE}/mediaserver/licenses/public.key || true

	echo """

	Configuration script is finished successfuly!

	"""
fi
