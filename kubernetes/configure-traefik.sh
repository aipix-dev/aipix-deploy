#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

#Creating configs files for traefik
cp -n ../nginx/ssl/self-signed/nginx-selfsigned.crt ../nginx/ssl/tls.crt
cp -n ../nginx/ssl/self-signed/nginx-selfsigned.key ../nginx/ssl/tls.key

echo """

Configuration script is finished successfuly!

"""
