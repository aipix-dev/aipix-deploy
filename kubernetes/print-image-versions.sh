#!/bin/bash -e

scriptdir="$(dirname "$0")"
cd "$scriptdir"

source ./sources.sh

print_images() {
    local namespace="$1"

    echo
    echo -e "\033[32mNamespace: ${namespace}\033[0m"
    printf "%-70s %s\n" "IMAGE" "TAG"
    printf "%-70s %s\n" "----------------------------------------------------------------------" "----------------"

    kubectl get pods -n "${namespace}" \
      -o jsonpath='{range .items[*]}{range .spec.initContainers[*]}{.image}{"\n"}{end}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' \
    | sort -u \
    | while read -r image; do
        [[ -z "$image" ]] && continue

        if [[ "$image" == *:* ]]; then
            tag="${image##*:}"
            image_name="${image%:*}"
        else
            tag="latest"
            image_name="$image"
        fi

        printf "%-70s %s\n" "$image_name" "$tag"
    done
}

if [[ $# -gt 0 ]]; then
    namespaces=("$1")
else
    namespaces=("${NS_VMS}")

    if [[ "${ANALYTICS:-no}" == "yes" ]]; then
        namespaces+=("${NS_A}")
    fi

    if kubectl get namespace "${NS_MS}" >/dev/null 2>&1; then
        namespaces+=("${NS_MS}")
    fi

    if [[ "${MONITORING:-no}" == "yes" ]]; then
        namespaces+=("${NS_MONITORING}")
    fi
fi

for ns in "${namespaces[@]}"; do
    print_images "${ns}"
done