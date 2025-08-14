#!/bin/bash

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ../kubernetes/sources.sh
source ../kubernetes/k8s-onprem/sources.sh

### Backup MySQL databases
kubectl exec -n ${NS_VMS} deployment.apps/cron -- ./db_dump.sh
../kubernetes/db-dump.sh

### Update Minio
../kubernetes/deploy-minio-single.sh

### Update VMS
# Update VGW
if [[ $(kubectl -n ${NS_VMS} get statefulsets.apps vgw) ]]; then
    ../kubernetes/update-vgw.sh
else
    echo "VGW is not installed, continue update"
fi

# Configure VMS
../kubernetes/configure-vms.sh

# Delete MAP_CLUSTER_ITEMS env from ../vms-backend/environments/.env file
sed -i '/^MAP_CLUSTER_ITEMS=/d' ../vms-backend/environments/.env

# Add permissions to VMS_DB_DATABASE for user controller
IFS="=" read name VMS_DB_DATABASE <<<$(cat ../controller/environments/.env | grep -e "^VMS_DB_DATABASE" | tr -d "'\'")
GRANT_PRIVILEGES="GRANT SELECT, UPDATE ON ${VMS_DB_DATABASE}.* TO 'controller'@'%';FLUSH PRIVILEGES;"
kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysql --protocol=TCP -u root -pmysql --execute="${GRANT_PRIVILEGES}"

# Update VMS
../kubernetes/update-vms-25-06.sh
kubectl -n ${NS_VMS} delete deployments.apps set-configs || true
if [ ${TYPE} != "prod" ]; then
	CREATE_MONITORING_MYSQL_USER="CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY 'password' WITH MAX_USER_CONNECTIONS 3;"
	GRANT_PRIVILEGES="GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';FLUSH PRIVILEGES;"
	kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysql --protocol=TCP -u root -pmysql --execute="${CREATE_MONITORING_MYSQL_USER}"
	kubectl exec -n ${NS_VMS} deployment.apps/mysql-server -- mysql --protocol=TCP -u root -pmysql --execute="${GRANT_PRIVILEGES}"
fi

### Update MSE
if [[ $(kubectl get ns | grep ${NS_MS}) ]]; then
    MS_TYPE="vsaas"
    cp ../mse/server.json.${MS1_IP}.${MS_TYPE} ../mse/server.json.${MS1_IP}.${MS_TYPE}.backup
    jq '.log = {
        "#stdout": {
        "tag": "media-server",
        "verbose": 5,
        "pattern": "[%AppId] [%Timestamp] [%Verbose] %Message"
        },
        "file": {
        "tag": "media-server",
        "verbose": 4,
        "pattern": "[%Timestamp] [%AppId] [%Verbose] %Message",
        "path": "/var/log/vsaas/media-server.log",
        "rotate": 20000000,
        "number": 5
        },
        "#remote": {
        "tag": "media-server",
        "verbose": 3,
        "pattern": "{\"tag\":\"%Tag\",\"verbose\":\"%Verbose\",\"timestamp\":\"%Timestamp\",\"app_id\":\"%AppId\",\"message\":\"%EscMessage\"}",
        "url": "udp://company.com:8109"
        },
        "#syslog": {
        "tag": "media-server",
        "verbose": 5,
        "pattern": "[%Timestamp] [%AppId] [%Verbose] %Message",
        "facility": "user"
        }
    }' ../mse/server.json.${MS1_IP}.${MS_TYPE} > ../mse/server.json.tmp

    jq '.["#coroutine"] = {"once": 8, "periodic": 4}' ../mse/server.json.tmp > ../mse/server.json.${MS1_IP}.${MS_TYPE}

    jq 'del(.["#storage"]?, .storage?) |
        .storage = {
            "localfs": {
            "max-io-events": 4096
            }
        }' ../mse/server.json.${MS1_IP}.${MS_TYPE} > ../mse/server.json.tmp

    jq 'del(.["max-io-events"])' ../mse/server.json.tmp > ../mse/server.json.${MS1_IP}.${MS_TYPE}

    # cp ../mse/server.json.tmp ../mse/server.json.${MS1_IP}.${MS_TYPE}
    rm ../mse/server.json.tmp
    ../kubernetes/update-mse.sh
else
    echo "MSE is not installed in k8s, continue update"
fi

### Update Analytics
if [ ${ANALYTICS} == "yes" ]; then
    ../kubernetes/configure-analytics.sh
    ../kubernetes/update-analytics.sh
else
    echo "Analytics is not installed, continue update"
fi

### Update monitoring
if [ ${MONITORING} == "yes" ]; then
    echo "Delete resources from monitoring namespace"
    kubectl --namespace=monitoring delete all --all > /dev/null
    kubectl delete namespace monitoring
    ../kubernetes/configure-monitoring.sh
    ../kubernetes/deploy-monitoring.sh
else
    echo "Monitoring is not installed, continue update"
fi

echo """
Upgrade script completed successfuly!

"""