#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

#Creating configs files for traefik
cp -n ../nginx/ssl/self-signed/nginx-selfsigned.crt ../nginx/ssl/tls.crt
cp -n ../nginx/ssl/self-signed/nginx-selfsigned.key ../nginx/ssl/tls.key

#Creating traefik-helm-values file
envsubst < ../traefik/traefik-helm-values.yaml.template > ../traefik/traefik-helm-values.yaml.tmp

if [ ${TYPE} == "prod" ]; then
    cat << EOF >> ../traefik/traefik-helm-values.yaml.tmp
providers:
  file:
    enabled: true
    watch: true
    content: |
      http:
        services:
          minio:
            failover:
              healthCheck: {}
              service: minio-1
              fallback: minio-2
          minio-1:
            loadBalancer:
              servers:
              - url: "http://minio-1.${NS_MINIO}.svc:9000"
              healthCheck:
                scheme: "http"
                interval: 2s
                timeout: 1s
                path: /minio/health/live
          minio-2:
            loadBalancer:
              servers:
              - url: "http://minio-2.${NS_MINIO}.svc:9000"
              healthCheck:
                scheme: http
                interval: 2s
                timeout: 1s
                path: /minio/health/live
EOF
fi

cp -n ../traefik/traefik-helm-values.yaml.tmp ../traefik/traefik-helm-values.yaml
rm -rf ../traefik/traefik-helm-values.yaml.tmp

echo """

Configuration script is finished successfuly!

"""
