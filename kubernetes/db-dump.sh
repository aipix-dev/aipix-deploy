#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

BACKUP_PATH="../mysql-backups/$(date +%Y-%m-%d)"
mkdir -p ${BACKUP_PATH}

if [ ${TYPE} != "prod" ]; then
	kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysqldump -uroot -pmysql --no-data --single-transaction --no-tablespaces vms > ${BACKUP_PATH}/vms-schema-backup.sql
	kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysqldump -uroot -pmysql --single-transaction vms > ${BACKUP_PATH}/vms-backup.sql
	kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysqldump -uroot -pmysql --no-data --single-transaction --no-tablespaces controller > ${BACKUP_PATH}/controller-schema-backup.sql
	kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysqldump -uroot -pmysql --single-transaction controller > ${BACKUP_PATH}/controller-backup.sql
	if [ ${ANALYTICS} == "yes" ]; then
		kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysqldump -uroot -pmysql --no-data --single-transaction --no-tablespaces analytics > ${BACKUP_PATH}/analytics-schema-backup.sql
		kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysqldump -uroot -pmysql --single-transaction analytics > ${BACKUP_PATH}/analytics-backup.sql
	fi
	if [ ${PORTAL} == "yes" ]; then
		kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysqldump -uroot -pmysql --no-data --single-transaction --no-tablespaces portal > ${BACKUP_PATH}/portal-schema-backup.sql
		kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysqldump -uroot -pmysql --single-transaction portal > ${BACKUP_PATH}/portal-backup.sql
		kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysqldump -uroot -pmysql --no-data --single-transaction --no-tablespaces portal_stub > ${BACKUP_PATH}/portal_stub-schema-backup.sql
		kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysqldump -uroot -pmysql --single-transaction portal_stub > ${BACKUP_PATH}/portal_stub-backup.sql
	fi
	if [ ${WB} == "yes" ]; then
		kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysqldump -uroot -pmysql --no-data --single-transaction --no-tablespaces wb > ${BACKUP_PATH}/wb-schema-backup.sql
		kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysqldump -uroot -pmysql --single-transaction wb > ${BACKUP_PATH}/wb-backup.sql
	fi
fi

echo """

Databases were backuped successfuly into folder $BACKUP_PATH!

"""
