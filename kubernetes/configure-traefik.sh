#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

#Creating configs files for traefik
cp -n ../nginx/ssl/self-signed/nginx-selfsigned.crt ../nginx/ssl/tls.crt
cp -n ../nginx/ssl/self-signed/nginx-selfsigned.key ../nginx/ssl/tls.key

#Creating traefik-helm-values file
envsubst < ../traefik/traefik-helm-values.yaml.template > ../traefik/traefik-helm-values.yaml.tmp
cp -n ../traefik/traefik-helm-values.yaml.tmp ../traefik/traefik-helm-values.yaml

echo """

Configuration script is finished successfuly!

"""
