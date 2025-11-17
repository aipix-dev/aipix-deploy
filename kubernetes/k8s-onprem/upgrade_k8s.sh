#!/bin/bash -e

DOC='''
Use the following options to run the script

-a 	This option download the file from repositoryes to local machine for runc, containerd and calicoctl
	Files can be copyed to the target nodes in /tmp directory to speedup instalation process
-c 	Used to upgrade any control-plane node (must be used with key -f for the first control-plane node)
-f      Used with key -c to upgrade first control-plane node
-w 	Used to upgrade worker node (kubeadm, kubelet, kubectl)
-m 	Used to upgrade kubectl on management node
-k 	Upgrade kubelet and kubectl on any control-plane node (must be used with key -c)
-r 	Upgrade runc on any control-plane and worker node
-d 	Upgrade containerd on ny control-plane and worker node
-n 	Upgrade calico with central operator (run on mgmt node)
-o 	Upgrade calicoctl on control-plane, worker node or mgmt host
-l 	This optin is used with keys -d -r -o if you use local files in /tmp to install containerd, runc or calicoctl
-h 	display this help;

Examples:
1) to upgrade first control-plane node run:
./upgrade_k8s.sh -c -f 

2) to upgrade any other control-plane node run: 
./upgrade_k8s.sh -c 

3) to upgrade kublet, kubectl on control-plane node run:
./upgrade_k8s.sh -c -k 

4) to upgrade kublet, kubectl, containerd, runc, calicoctl on control-plane node run:
./upgrade_k8s.sh -c -k -d -r -o
 
5) to upgrade kubeadm, kubectl, kubelet on worker node run:
./upgrade_k8s.sh -w 

6) to upgrade kubeadm, kubectl, kubelet, containerd, runc, calicoctl on worker node run:
./upgrade_k8s.sh -w -d -r -o 

7) to upgrade containerd, runc, calicoctl on control-plane or worker node run:
./upgrade_k8s.sh -d -r -o

8) to upgrade containerd, runc, calicoctl on control-plane or worker node from local file in /tmp:
./upgrade_k8s.sh -d -r -o -l

9) to download containerd, runc, calicoctl on local machine run:
./upgrade_k8s.sh -a

10) to upgrade kubectl and calicoctl on mgmt host run:
./upgrade_k8s.sh -m -o

11) to upgrade calico with central operator run on mgmt host:
./upgrade_k8s.sh -n

'''

scriptdir="$(dirname "$0")"
cd "$scriptdir"

if [ ! -f "./sources.sh" ]; then
  echo "Using ENV from sources.sh.sample"
  source ./sources.sh.sample
else
  echo "Using ENV from sources.sh"
  source ./sources.sh
  if [ -z "${SRC_K8S_VER}" ]; then
    echo >&2 "ERROR: File sources.sh does not contain K8S version variables. Copy system variables fom sources.sh.sample file."
    exit 2
  fi
fi

K8S_VER=${SRC_K8S_VER}
K8S_VER_PATCH=${SRC_K8S_VER_PATCH}
K8S_VER_BUILD=${SRC_K8S_VER_BUILD}
CONTAINERD_VER=${SRC_CONTAINERD_VER}
RUNC_VER=${SRC_RUNC_VER}
CALICO_VER=${SRC_CALICO_VER}

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export DEBCONF_NOWARNINGS=true
export DEBCONF_DEBUG=5
export NEEDRESTART_MODE=a

IS_K8S_FIRST_CP=false
UPGRADE_KUBELET=false
UPGRADE_RUNC=false
UPGRADE_CONTAINERD=false
UPGRADE_CALICO=false
UPGRADE_CALICO_CTL=false
TAR_FILES_LOCAL=false
OPTSTRING=":acwmfkrdnolh"
while getopts ${OPTSTRING} opt; do
        case ${opt} in
                a) DOWNLOAD_UPG_FILES=true; echo "Download files selected for runc, containerd and calico_ctl";;
                c) K8S_NODE_TYPE=control-plane; echo "Control-plane node upgrade selected";;
                w) K8S_NODE_TYPE=worker; echo "Wworker node upgrade selected";;
                m) K8S_NODE_TYPE=management; echo "Management node upgrade selected";;
                f) IS_K8S_FIRST_CP=true; echo "First control-plane node upgrade selected";;
                k) UPGRADE_KUBELET=true; echo "Kubelet and kubectl upgrade selected";;
                r) UPGRADE_RUNC=true; echo "Runc upgrade selected";;
                d) UPGRADE_CONTAINERD=true; echo "Containerd upgrade selected";;
                n) UPGRADE_CALICO=true; echo "Calico operator upgrade selected";;
                o) UPGRADE_CALICO_CTL=true; echo "Calicoctl upgrade selected";;
                l) UPG_FILES_LOCAL=true; echo "Upgrade files on local filesystem in /tmp directory is selected";;
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

download_upg_files () {
        mkdir -p ~/tmp_download_files
        echo "Downloading containerd v${CONTAINERD_VER}"
        curl -L https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VER}/containerd-${CONTAINERD_VER}-linux-amd64.tar.gz -o ~/tmp_download_files/containerd-${CONTAINERD_VER}-linux-amd64.tar.gz
        echo "Downloading runc v${RUNC_VER}"
        curl -L https://github.com/opencontainers/runc/releases/download/v${RUNC_VER}/runc.amd64 -o ~/tmp_download_files/runc.amd64-v${RUNC_VER}
        echo "Downloading calicoctl v${CALICO_VER}"
        curl -L https://github.com/projectcalico/calico/releases/download/v${CALICO_VER}/calicoctl-linux-amd64 -o ~/tmp_download_files/calicoctl-linux-amd64-v${CALICO_VER}
}

configure_k8s_repository () {
        echo "Configuring repository"
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VER}/deb/Release.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VER}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
        sudo -E apt-get update -y
        sudo -E apt-cache madison kubeadm

        read -p "
        ##############################################################################
        Check the latest version of kubeadm.
        Press N if you need to correct K8S version-patch-build in the source.sh file.
        If correct K8S version is set in source.sh file you can continue by pressing Y
        ##############################################################################
        Do you want to continue installation? (y/N): " -n 1 -r

        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]
        then
            echo "Installation cancelled."
            exit 1
        fi
}


first-k8s-cp-upgrade () {
        configure_k8s_repository
        sudo -E  apt-mark unhold kubeadm && \
        sudo -E apt-get update && sudo -E apt-get install -y \
            kubeadm && \
        sudo -E apt-mark hold kubeadm
        kubeadm version

        sudo kubeadm upgrade plan

        read -p "Do you want to continue installation? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]
        then
            echo "Installation cancelled."
            exit 1
        fi
        #Upgrade first control node
        sudo kubeadm upgrade apply v${K8S_VER}.${K8S_VER_PATCH}
}

second-k8s-cp-upgrade () {
        configure_k8s_repository
        sudo -E apt-mark unhold kubeadm && \
        sudo -E apt-get update && sudo -E apt-get install -y \
            kubeadm="${K8S_VER}.${K8S_VER_PATCH}-${K8S_VER_BUILD}" && \
        sudo -E apt-mark hold kubeadm
        kubeadm version

        #Upgrade not first control node
        sudo kubeadm upgrade node
}

kubelet-upgrade-cp () {
        K8S_CP_NODE=$(hostname)
        kubectl drain ${K8S_CP_NODE} --ignore-daemonsets

        sudo -E apt-mark unhold kubelet kubectl && \
        sudo -E apt-get update && sudo -E apt-get install -y \
            kubelet="${K8S_VER}.${K8S_VER_PATCH}-${K8S_VER_BUILD}" \
            kubectl="${K8S_VER}.${K8S_VER_PATCH}-${K8S_VER_BUILD}" && \
        sudo -E apt-mark hold kubelet kubectl
        sudo systemctl daemon-reload
        sudo systemctl restart kubelet
        kubectl uncordon ${K8S_CP_NODE}
}

k8s-worker-upgrade () {
        configure_k8s_repository
        sudo -E apt-mark unhold kubeadm kubelet kubectl && \
        sudo -E apt-get update && sudo -E apt-get install -y \
            kubeadm="${K8S_VER}.${K8S_VER_PATCH}-${K8S_VER_BUILD}" \
            kubelet="${K8S_VER}.${K8S_VER_PATCH}-${K8S_VER_BUILD}" \
            kubectl="${K8S_VER}.${K8S_VER_PATCH}-${K8S_VER_BUILD}" && \
        sudo -E apt-mark hold kubeadm kubelet kubectl
        sudo kubeadm upgrade node
        sudo systemctl daemon-reload
        sudo systemctl restart kubelet
}

k8s-management-upgrade () {
        configure_k8s_repository
        sudo -E apt-mark unhold kubectl && \
        sudo -E apt-get update && sudo apt-get install -y \
            kubectl="${K8S_VER}.${K8S_VER_PATCH}-${K8S_VER_BUILD}" && \
        sudo -E apt-mark hold kubectl
}


runc_upgrade () {
        echo "Starting runc v${RUNC_VER} upgrade"
        if [[ ${UPG_FILES_LOCAL} != "true" ]]; then
                sudo curl -L https://github.com/opencontainers/runc/releases/download/v${RUNC_VER}/runc.amd64 -o /tmp/runc.amd64-v${RUNC_VER}
        fi
        sudo install -m 755 /tmp/runc.amd64-v${RUNC_VER} /usr/local/sbin/runc
        sudo rm /tmp/runc.amd64-v${RUNC_VER}
        echo "Runc v${RUNC_VER} installed"
}

containerd_upgrade () {
        echo "Starting containerd v${CONTAINERD_VER} upgrade"
        if [[ ${UPG_FILES_LOCAL} != "true" ]]; then
                sudo curl -L https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VER}/containerd-${CONTAINERD_VER}-linux-amd64.tar.gz -o /tmp/containerd-${CONTAINERD_VER}-linux-amd64.tar.gz
        fi
        sudo tar Cxzvf /usr/local /tmp/containerd-${CONTAINERD_VER}-linux-amd64.tar.gz
        sudo rm /tmp/containerd-${CONTAINERD_VER}-linux-amd64.tar.gz

        CONFIG_FILE="/etc/containerd/config.toml"
        TARGET_LINE_1="\[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options\]"
        TARGET_LINE_2="\[plugins.'io.containerd.grpc.v1.cri'\]"

        sudo mkdir -p /etc/containerd/certs.d
        sudo cp ${CONFIG_FILE} ${CONFIG_FILE}.backup.$(date +%F_%H-%M) || true
        sudo sh -c "containerd config default > ${CONFIG_FILE}"

        if sudo grep  "SystemdCgroup =" $CONFIG_FILE >/dev/null 2>&1; then
            echo "Seting existing SystemdCgroup in /etc/containerd/config.toml to true"
            sudo sed -i 's/SystemdCgroup =.*/SystemdCgroup = true/' ${CONFIG_FILE}
        elif
            sudo grep -q "$TARGET_LINE_1" $CONFIG_FILE >/dev/null 2>&1 ; then
            echo "Adding SystemdCgroup in /etc/containerd/config.toml and seting to true"
            sudo sed -i "/${TARGET_LINE_1}/a\            SystemdCgroup = true" ${CONFIG_FILE}
        else
            echo "Error: Unable to configure SystemdCgroup in /etc/containerd/config.toml: Target line not found"
            exit 2
        fi

        if sudo grep  "sandbox_image =" $CONFIG_FILE >/dev/null 2>&1; then
            echo "Seting existing sandbox_image in /etc/containerd/config.toml to new value"
            sudo sed -i "s/sandbox_image =.*/sandbox_image = 'registry.k8s.io\/pause:3.10'/" ${CONFIG_FILE}
        elif
            sudo grep -q "$TARGET_LINE_2" $CONFIG_FILE >/dev/null 2>&1 ; then
            echo "Adding sandbox_image in /etc/containerd/config.toml and seting value"
            sudo sed -i "/${TARGET_LINE_2}/a\    sandbox_image = 'registry.k8s.io/pause:3.10'" ${CONFIG_FILE}
        else
            echo "Error: Unable to configure sandbox_image in /etc/containerd/config.toml: Target line not found"
            exit 2
        fi
        #Replace config_path
        if sudo grep '\[plugins\."io\.containerd\.grpc\.v1\.cri"\.registry\]' ${CONFIG_FILE} >/dev/null 2>&1; then
            sudo sed -i '/\[plugins\."io\.containerd\.grpc\.v1\.cri"\.registry\]/,/^$/s|config_path = ".*"|config_path = "/etc/containerd/certs.d"|' ${CONFIG_FILE}
        elif
            sudo grep "\[plugins\.'io.containerd.cri.v1.images'\.registry\]" ${CONFIG_FILE} >/dev/null 2>&1; then
            sudo sed -i "/\[plugins\.'io.containerd.cri.v1.images'\.registry\]/,/^$/s|config_path = '.*'|config_path = '/etc/containerd/certs.d'|" ${CONFIG_FILE}
        else
            echo "Error: Unable to configure config_path in /etc/containerd/config.toml: Target line not found"
            exit 2
        fi
        #Update containerd.service file
        sudo curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /usr/lib/systemd/system/containerd.service
        sudo mkdir -p /usr/lib/systemd/system/containerd.service.d
        cat <<EOF | sudo tee /usr/lib/systemd/system/containerd.service.d/limits.conf
[Service]
LimitNOFILE=infinity
EOF
        sudo systemctl daemon-reload
        sudo systemctl stop containerd
        sleep 3
        sudo systemctl start containerd
        sudo systemctl restart kubelet
        echo "Containerd v${CONTAINERD_VER} installed"
}

calico_upgrade () {
        echo "Starting calico operator v${CALICO_VER} upgrade"
        curl https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VER}/manifests/tigera-operator.yaml -O
        kubectl apply --server-side --force-conflicts -f tigera-operator.yaml
        rm -rf tigera-operator.yaml
        echo "Calico operator v${CALICO_VER} installed. Wait for calico-node is restarted on all hosts"
}

calico_ctl_upgrade () {
        echo "Starting calicoctl v${CALICO_VER} upgrade"
        if [[ ${UPG_FILES_LOCAL} != "true" ]]; then
                sudo curl -L https://github.com/projectcalico/calico/releases/download/v${CALICO_VER}/calicoctl-linux-amd64 -o /usr/local/bin/calicoctl
        else
                sudo mv /tmp/calicoctl-linux-amd64-v${CALICO_VER} /usr/local/bin/calicoctl
        fi
        sudo chown root:root /usr/local/bin/calicoctl
        sudo chmod +x /usr/local/bin/calicoctl
        echo "Calicoctl v${CALICO_VER} installed"
}

if [[ ${DOWNLOAD_UPG_FILES} == "true" ]]; then download_upg_files; fi

if [[ $K8S_NODE_TYPE == "control-plane" ]] && [[ $IS_K8S_FIRST_CP == "true" ]] && [[ $UPGRADE_KUBELET == "false" ]]; then
        first-k8s-cp-upgrade
fi
if [[ $K8S_NODE_TYPE == "control-plane" ]] && [[ $IS_K8S_FIRST_CP == "false" ]] && [[ $UPGRADE_KUBELET == "false" ]]; then
        second-k8s-cp-upgrade
fi
if [[ $K8S_NODE_TYPE == "control-plane" ]] && [[ $UPGRADE_KUBELET == "true" ]]; then
        kubelet-upgrade-cp
fi
if [[ $K8S_NODE_TYPE == "worker" ]]; then k8s-worker-upgrade; fi
if [[ $K8S_NODE_TYPE == "management" ]]; then k8s-management-upgrade; fi
if [[ $UPGRADE_RUNC == "true" ]]; then runc_upgrade; fi
if [[ $UPGRADE_CONTAINERD == "true" ]]; then containerd_upgrade; fi
if [[ $UPGRADE_CALICO == "true" ]]; then calico_upgrade; fi
if [[ $UPGRADE_CALICO_CTL == "true" ]]; then calico_ctl_upgrade; fi

