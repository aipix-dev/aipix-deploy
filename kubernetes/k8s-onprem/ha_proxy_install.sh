#!/bin/bash

sudo apt-get update && sudo apt-get install -y haproxy net-tools

sudo mv /etc/haproxy/haproxy.cfg{,.back}
sudo sh -c 'cat << EOF > /etc/haproxy/haproxy.cfg
global
    user haproxy
    group haproxy
defaults
    mode http
    log global
    retries 2
    timeout connect 3000ms
    timeout server 5000ms
    timeout client 5000ms
frontend kubernetes
    bind 192.168.205.12:6443
    option tcplog
    mode tcp
    default_backend kubernetes-master-nodes
backend kubernetes-master-nodes
    mode tcp
    balance roundrobin
    option tcp-check
    server k8s-master-1 192.168.205.146:6443 check fall 3 rise 2
    server k8s-master-2 192.168.205.147:6443 check fall 3 rise 2
    server k8s-master-3 192.168.205.148:6443 check fall 3 rise 2
EOF'

sudo apt install -y keepalived
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sh -c 'echo "net.ipv4.ip_nonlocal_bind = 1" >> /etc/sysctl.conf'
sudo sysctl -p

sudo sh -c 'cat << EOF > /etc/keepalived/keepalived.conf
vrrp_instance VI_1 {
    interface ens160
    state BACKUP
    virtual_router_id 146
    priority 100  # set priority
    advert_int 2
    authentication {
        auth_type PASS
        auth_pass monkey146
    }
    virtual_ipaddress {
        192.168.205.12 dev ens160 label ens160:vip
    }
}
EOF'

sudo systemctl enable --now keepalived
sudo systemctl restart keepalived
sudo systemctl restart haproxy
sleep 5
sudo netstat -ntlp
sudo systemctl status haproxy
sudo systemctl status keepalived

