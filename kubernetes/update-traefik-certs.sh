#Create configs and secrets

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

kubectl -n ${TRAEFIK_NAMESPACE} delete secret certificate >/dev/null || true
kubectl -n ${TRAEFIK_NAMESPACE} create secret tls certificate \
   --cert=../nginx/ssl/tls.crt \
   --key=../nginx/ssl/tls.key >/dev/null

kubectl -n ${TRAEFIK_NAMESPACE} delete ingressroutes.traefik.io traefik-dashboard >/dev/null
helm upgrade -n ${TRAEFIK_NAMESPACE} traefik traefik/traefik -f ../traefik/traefik-helm-values.yaml >/dev/null

echo """
Certificates were successfully updated
"""
