#!/bin/bash -e

DOC='''
Use the following options to run the script

-i <[verions]>		install cert-manager (enter optional verion like v1.17.1)
-u <verions> 		update cert-manager deployment (enter required verion like v1.17.1)
-c <service>		provide service for which certificate shold be deployed;
available services:
 	vms			for vms service
 	portal-stub 		for portal-stub service
 	minio-console		for minio console service (used in single node installation)
 	minio-console-1		for primary minio console service (used in HA/production installation)
 	minio-console-2 	for secondary minio console service (used in HA/production installation)
	orchestrator		for analytics orchestrator service
	traefik-dashboard 	for traefik dashboard service
-h 			display this help

For example: 
1) to install cert-manager run 
./deploy-certificates.sh -i

2) to upgrade cert-manager run 
./deploy-certificates.sh -u v1.17.1

3) to create certificate for vms sercice run 
./deploy-certificates.sh -c vms

'''

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

CERT_MANAGER_VER=v1.17.1
NS_CERT_MANAGER=cert-manager
OPTSTRING=":iu:c:h"
while getopts ${OPTSTRING} opt; do
	case ${opt} in
		i) CERT_MANAGER_VER=${OPTARG}; DEPLOY_CERT_MANAGER="yes";;
		u) CERT_MANAGER_VER=${OPTARG}; UPDATE_CERT_MANAGER="yes";;
		c) CERT_SERVICE=${OPTARG};;
		h) echo "${DOC}";;
		:)
			echo "Option -${OPTARG} requires an argument." >&2
			exit 1
		;;
		?)
			echo "Invalid option: -${OPTARG}." >&2
			echo "${DOC}"
			exit 1
		;;
	esac
done

if [[ $# == "0" ]]; then
	echo "You must provide available options" >&2
	echo "${DOC}"
	exit 1
fi

if [[ ${DEPLOY_CERT_MANAGER} == "yes" ]]; then
	helm repo add jetstack https://charts.jetstack.io --force-update
	echo "Wait a few minutes to deply cert-manager..."
	helm install cert-manager jetstack/cert-manager \
			--namespace ${NS_CERT_MANAGER} \
			--create-namespace \
			--version "${CERT_MANAGER_VER}" \
			--set crds.enabled=true 
	kubectl apply -f - <<EOF
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
 name: acme
spec:
 acme:
   email: cert@${VMS_DOMAIN#*.}
   # staging: https://acme-staging-v02.api.letsencrypt.org/directory
   # production: https://acme-v02.api.letsencrypt.org/directory
   server: https://acme-v02.api.letsencrypt.org/directory
   privateKeySecretRef:
     # if not existing, it will register a new account and stores it
     name: cluster-issuer-account-key
   solvers:
     - http01:
         # The ingressClass used to create the necessary ingress routes
         ingress:
           ingressClassName: traefik
           ingressTemplate:
             metadata:
               labels:
                 app.kubernetes.io/instance: traefik-traefik-v2
EOF
fi

if [[ ${UPDATE_CERT_MANAGER} == "yes" ]]; then
	helm upgrade cert-manager jetstack/cert-manager \
			--namespace ${NS_CERT_MANAGER} \
			--reset-then-reuse-values \
			--version "${CERT_MANAGER_VER}" 
	kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
 name: acme
spec:
 acme:
   email: cert@${VMS_DOMAIN#*.}
   # staging: https://acme-staging-v02.api.letsencrypt.org/directory
   # production: https://acme-v02.api.letsencrypt.org/directory
   server: https://acme-v02.api.letsencrypt.org/directory
   privateKeySecretRef:
     # if not existing, it will register a new account and stores it
     name: cluster-issuer-account-key
   solvers:
     - http01:
         # The ingressClass used to create the necessary ingress routes
         ingress:
           ingressClassName: traefik
           ingressTemplate:
             metadata:
               labels:
                 app.kubernetes.io/instance: traefik-traefik-v2
EOF
fi

if [[ ${CERT_SERVICE} == "traefik-dashboard" ]]; then
	kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: traefik-dashboard
  namespace: ${TRAEFIK_NAMESPACE}
spec:
  secretName: traefik-dashboard-cert
  dnsNames:
    - "${TRAEFIK_DOMAIN}"
  issuerRef:
    name: acme
    kind: ClusterIssuer
EOF
	sed -i 's/secretName: .*/secretName: traefik-dashboard-cert/g' ../traefik/traefik-helm-values.yaml
	helm upgrade -n ${TRAEFIK_NAMESPACE} traefik traefik/traefik -f ../traefik/traefik-helm-values.yaml >/dev/null
fi


if [[ ${CERT_SERVICE} == "vms" ]]; then
	kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: vms
  namespace: ${NS_VMS}
spec:
  secretName: vms-cert
  dnsNames:
    - "${VMS_DOMAIN}"
  issuerRef:
    name: acme
    kind: ClusterIssuer
EOF
	IS_PATCH_EXIST=$(cat ../kustomize/deployments/${VMS_TEMPLATE}/custom-patches.d/custom-patches.yaml 2>/dev/null | grep "secretName: *vms-cert$" | wc -l || echo 0)
	if [[ ${IS_PATCH_EXIST} == "0" ]]; then
		cat << EOF >> ../kustomize/deployments/${VMS_TEMPLATE}/custom-patches.d/custom-patches.yaml 
- target:
    group: traefik.io
    version: v1alpha1
    kind: IngressRoute
    name: frontend-client
  patch: |-
    - op: replace
      path: /spec/tls
      value:
        secretName: vms-cert
EOF
		../kustomize/deployments/${VMS_TEMPLATE}/update-kustomization.sh || exit 1
		kubectl apply -k ../kustomize/deployments/${VMS_TEMPLATE}
	fi
fi


if [[ ${CERT_SERVICE} == "portal-stub" ]]; then
	if [ ${PORTAL} != "yes" ]; then echo "Error: Portal is not deployed"; exit 1; fi
	kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: portal-stub
  namespace: ${NS_VMS}
spec:
  secretName: portal-stub-cert
  dnsNames:
    - "${PORTAL_STUB_DOMAIN}"
  issuerRef:
    name: acme
    kind: ClusterIssuer
EOF
	IS_PATCH_EXIST=$(cat ../kustomize/deployments/${VMS_TEMPLATE}/custom-patches.d/custom-patches.yaml 2>/dev/null | grep "secretName: *portal-stub-cert$" | wc -l || echo 0)
	if [[ ${IS_PATCH_EXIST} == "0" ]]; then
		cat << EOF >> ../kustomize/deployments/${VMS_TEMPLATE}/custom-patches.d/custom-patches.yaml
- target:
    group: traefik.io
    version: v1alpha1
    kind: IngressRoute
    name: portal-stub
  patch: |-
    - op: replace
      path: /spec/tls
      value:
        secretName: portal-stub-cert
EOF
		../kustomize/deployments/${VMS_TEMPLATE}/update-kustomization.sh || exit 1
		kubectl apply -k ../kustomize/deployments/${VMS_TEMPLATE}
	fi
fi


if [[ ${CERT_SERVICE} == "minio-console" ]]; then
	if [ ${TYPE} != "single" ]; then echo "Error: This service is for single node deployment only"; exit 1; fi
	kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: minio-console
  namespace: ${NS_MINIO}
spec:
  secretName: minio-console-cert
  dnsNames:
    - "${MINIO_CONSOLE_DOMAIN}"
  issuerRef:
    name: acme
    kind: ClusterIssuer
EOF
	IS_PATCH_EXIST=$(cat ../kustomize/deployments/${MINIO_TEMPLATE}/custom-patches.d/custom-patches.yaml 2>/dev/null | grep "secretName: *minio-console-cert$" | wc -l || echo 0)
	if [[ ${IS_PATCH_EXIST} == "0" ]]; then
		cat << EOF >> ../kustomize/deployments/${MINIO_TEMPLATE}/custom-patches.d/custom-patches.yaml
- target:
    group: traefik.io
    version: v1alpha1
    kind: IngressRoute
    name: minio-console
  patch: |-
    - op: replace
      path: /spec/tls
      value:
        secretName: minio-console-cert
EOF
		../kustomize/deployments/${MINIO_TEMPLATE}/update-kustomization.sh || exit 1
		kubectl apply -k ../kustomize/deployments/${MINIO_TEMPLATE}
	fi
fi


if [[ ${CERT_SERVICE} == "minio-console-1" ]]; then
	if [ ${TYPE} != "prod" ]; then echo "Error: This service is for production deployment only"; exit 1; fi
	kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: minio-console-1
  namespace: ${NS_MINIO}
spec:
  secretName: minio-console-1-cert
  dnsNames:
    - "${MINIO_CONSOLE_DOMAIN_1}"
  issuerRef:
    name: acme
    kind: ClusterIssuer
EOF
	IS_PATCH_EXIST=$(cat ../kustomize/deployments/${MINIO_TEMPLATE}/custom-patches.d/custom-patches.yaml 2>/dev/null | grep "secretName: *minio-console-1-cert$" | wc -l || echo 0)
	if [[ ${IS_PATCH_EXIST} == "0" ]]; then
		cat << EOF >> ../kustomize/deployments/${MINIO_TEMPLATE}/custom-patches.d/custom-patches.yaml
- target:
    group: traefik.io
    version: v1alpha1
    kind: IngressRoute
    name: minio-console-1
  patch: |-
    - op: replace
      path: /spec/tls
      value:
        secretName: minio-console-1-cert
EOF
		../kustomize/deployments/${MINIO_TEMPLATE}/update-kustomization.sh || exit 1
		kubectl apply -k ../kustomize/deployments/${MINIO_TEMPLATE}
	fi
fi

if [[ ${CERT_SERVICE} == "minio-console-2" ]]; then
	if [ ${TYPE} != "prod" ]; then echo "Error: This service is for production deployment only"; exit 1; fi
	kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: minio-console-2
  namespace: ${NS_MINIO}
spec:
  secretName: minio-console-1-cert
  dnsNames:
    - "${MINIO_CONSOLE_DOMAIN_2}"
  issuerRef:
    name: acme
    kind: ClusterIssuer
EOF
	IS_PATCH_EXIST=$(cat ../kustomize/deployments/${MINIO_TEMPLATE}/custom-patches.d/custom-patches.yaml 2>/dev/null | grep "secretName: *minio-console-2-cert$" | wc -l || echo 0)
	if [[ ${IS_PATCH_EXIST} == "0" ]]; then
		cat << EOF >> ../kustomize/deployments/${MINIO_TEMPLATE}/custom-patches.d/custom-patches.yaml
- target:
    group: traefik.io
    version: v1alpha1
    kind: IngressRoute
    name: minio-console-2
  patch: |-
    - op: replace
      path: /spec/tls
      value:
        secretName: minio-console-2-cert
EOF
		../kustomize/deployments/${MINIO_TEMPLATE}/update-kustomization.sh || exit 1
		kubectl apply -k ../kustomize/deployments/${MINIO_TEMPLATE}
	fi
fi


if [[ ${CERT_SERVICE} == "orchestrator" ]]; then
	if [ ${ANALYTICS} != "yes" ]; then echo "Error: Analytics is not deployed"; exit 1; fi
	kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: orchestrator
  namespace: ${NS_A}
spec:
  secretName: orchestrator-cert
  dnsNames:
    - "${ANALYTICS_DOMAIN}"
  issuerRef:
    name: acme
    kind: ClusterIssuer
EOF
	IS_PATCH_EXIST=$(cat ../kustomize/deployments/${A_TEMPLATE}/custom-patches.d/custom-patches.yaml 2>/dev/null | grep "secretName: *orchestrator-cert$" | wc -l || echo 0)
	if [[ ${IS_PATCH_EXIST} == "0" ]]; then
		cat << EOF >> ../kustomize/deployments/${A_TEMPLATE}/custom-patches.d/custom-patches.yaml
- target:
    group: traefik.io
    version: v1alpha1
    kind: IngressRoute
    name: orchestrator
  patch: |-
    - op: replace
      path: /spec/tls
      value:
        secretName: orchestrator-cert
EOF
		../kustomize/deployments/${A_TEMPLATE}/update-kustomization.sh || exit 1
		kubectl apply -k ../kustomize/deployments/${A_TEMPLATE}
	fi
fi

