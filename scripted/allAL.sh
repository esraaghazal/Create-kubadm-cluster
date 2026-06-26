#!/bin/bash

#amazon linux 2023 script

# to stop the script if there are errors
set -e

#Disable swap 
swapoff -a

#firewall config
systemctl enable --now firewalld

firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=30000-32767/tcp

firewall-cmd --reload

#Disable selinux
setenforce 0 2>/dev/null || true

sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

systemctl disable --now firewalld 2>/dev/null || true


#Enable Bridge Networking
modprobe br_netfilter || true
echo br_netfilter > /etc/modules-load.d/br_netfilter.conf


cat <<EOF >/etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

#Setup Kubernetes Repo
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF

#Install Kubernetes & containerd
dnf install -y kubelet kubeadm kubectl

dnf install -y containerd

systemctl enable --now kubelet
systemctl enable --now containerd

mkdir -p /etc/containerd

containerd config default > /etc/containerd/config.toml

sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl enable --now containerd

systemctl restart containerd

systemctl enable --now kubelet



