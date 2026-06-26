#!/bin/bash
# ubuntu

# Disable Swap
swapoff -a

# Disable Firewall
#systemctl disable --now ufw

#open ports

systemctl enable --now firewalld

firewall-cmd --permanent --add-port=6443/tcp
firewall-cmd --permanent --add-port=2379-2380/tcp
firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=10257/tcp
firewall-cmd --permanent --add-port=10259/tcp

firewall-cmd --reload

# Enable Bridge Networking
modprobe br_netfilter
echo br_netfilter | tee /etc/modules-load.d/br_netfilter.conf

cat <<EOF >/etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system


# Install Required Packages
apt update
apt install -y apt-transport-https ca-certificates curl gpg

# Add Kubernetes Repository
mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key \
| gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' \
| tee /etc/apt/sources.list.d/kubernetes.list


apt update

# Install Kubernetes
apt install -y kubelet kubeadm kubectl

apt-mark hold kubelet kubeadm kubectl

# Install Containerd
apt install -y containerd

mkdir -p /etc/containerd

containerd config default > /etc/containerd/config.toml

sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl enable --now containerd

systemctl restart containerd

systemctl enable --now kubelet

