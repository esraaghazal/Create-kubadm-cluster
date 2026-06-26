# Kubernetes Cluster Setup with kubeadm (CentOS Stream 9) MANUAL

## Cluster Architecture

<img width="697" height="632" alt="image" src="https://github.com/user-attachments/assets/0bf64ab4-55f9-4a87-95f9-fb1b3054a914" />


| Component | Version |
|-----------|---------|
| OS | CentOS Stream 9 |
| Kubernetes | v1.29 |
| Container Runtime | containerd |
| CNI Plugin | Calico v3.30.2 |
| Storage | local-path-provisioner |

---

## Table of Contents

1. [Pre-flight — All Nodes](#1-pre-flight--all-nodes)
2. [Install kubeadm & containerd — All Nodes](#2-install-kubeadm--containerd--all-nodes)
3. [Initialize the Master](#3-initialize-the-master)
4. [Install Calico CNI](#4-install-calico-cni)
5. [Join Worker Nodes](#5-join-worker-nodes)
6. [Firewall Rules](#6-firewall-rules)
7. [Storage — local-path-provisioner](#7-storage--local-path-provisioner)

---

## 1. Pre-flight — All Nodes

### Set Hostnames
```bash
# on master
hostnamectl hostname master

# on node1
hostnamectl hostname node1

# on node2
hostnamectl hostname node2
```

### Edit `/etc/hosts`
```bash
sudo vim /etc/hosts
```
```
192.168.117.138  master
192.168.117.144  node1
192.168.117.133  node2
```

### Disable Swap & SELinux
```bash
sudo swapoff -a
sed -i '/swap/s/^/#/' /etc/fstab
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
```

### Enable Bridge Networking

For pods to communicate across nodes, traffic must pass through the Linux bridge → iptables.

```bash
modprobe br_netfilter
lsmod | grep br_netfilter

# Persist across reboots
echo br_netfilter > /etc/modules-load.d/br_netfilter.conf

cat <<EOF | tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system
```

> **Why these settings?**
> - `bridge-nf-call-iptables` → lets iptables rules apply to bridged traffic (pod-to-pod communication)
> - `ip_forward` → enables packet forwarding between interfaces (cross-node routing)

---

## 2. Install kubeadm & containerd — All Nodes

### Add Kubernetes Repo
```bash
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF
```

### Install containerd

On CentOS Stream 9, `containerd` is not in the base repos. We add the Docker CE repo to get it:

```bash
yum install -y yum-utils
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y containerd.io
```

> **Why containerd and not Docker Engine?**  
> Kubernetes uses the **CRI (Container Runtime Interface)** to talk to container runtimes. Docker Engine doesn't implement CRI directly — `containerd` does, and it's what Docker itself uses under the hood.

### Install kubeadm & kubelet
```bash
yum install -y kubeadm
```

| Tool | Role |
|------|------|
| `kubeadm` | Bootstraps the cluster (init + join) |
| `kubelet` | Agent on every node; executes pod specs from the API Server |

### Configure containerd with SystemdCgroup
```bash
containerd config default > /etc/containerd/config.toml

vim /etc/containerd/config.toml
# Find and set:
#   SystemdCgroup = true
```

> CentOS Stream 9 uses `systemd` as the cgroup driver, so containerd must match.

### Enable Services
```bash
systemctl enable --now kubelet
systemctl enable --now containerd
systemctl restart containerd
systemctl status containerd
```

---

## 3. Initialize the Master

Run on the **master node only**.

```bash
kubeadm init
```

This creates the full control plane:
- **API Server** — entry point for all `kubectl` commands
- **Controller Manager** — maintains desired cluster state
- **Scheduler** — assigns pods to nodes
- **etcd** — key-value store for all cluster data

### Setup kubeconfig
```bash
mkdir -p $HOME/.kube
cp /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

---

## 4. Install Calico CNI

Run on the **master node**.

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/calico.yaml
```

> **Why Calico?**  
> Kubernetes itself does **not** handle pod networking — it delegates to a CNI plugin. Calico provides:
> - Pod-to-Pod networking across nodes
> - Routing between node networks
> - Network Policy support (security rules between pods)

Verify all Calico pods are running:
```bash
kubectl get pods -n kube-system
```

---

## 5. Join Worker Nodes

### Get the join command (on master)
```bash
kubeadm token create --print-join-command
```

> Tokens expire after 24 hours. Run the above to regenerate anytime.

### Run on each worker
```bash
kubeadm join 192.168.117.138:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

### Verify from master
```bash
kubectl get nodes
```

Expected output:
```
NAME     STATUS   ROLES           AGE   VERSION
master   Ready    control-plane   10m   v1.29.x
node1    Ready    <none>          2m    v1.29.x
node2    Ready    <none>          1m    v1.29.x
```

---

## 6. Firewall Rules

### Master Node
```bash
firewall-cmd --permanent --add-port=6443/tcp        # API Server
firewall-cmd --permanent --add-port=2379-2380/tcp   # etcd
firewall-cmd --permanent --add-port=10250/tcp       # kubelet
firewall-cmd --permanent --add-port=10257/tcp       # controller-manager
firewall-cmd --permanent --add-port=10259/tcp       # scheduler
firewall-cmd --reload
```

### Worker Nodes
```bash
firewall-cmd --permanent --add-port=10250/tcp           # kubelet
firewall-cmd --permanent --add-port=30000-32767/tcp     # NodePort services
firewall-cmd --permanent --add-port=179/tcp             # Calico BGP
firewall-cmd --permanent --zone=trusted --add-interface=cali+
firewall-cmd --permanent --zone=trusted --add-interface=tunl+
firewall-cmd --reload
```

| Port | Purpose |
|------|---------|
| 6443 | Kubernetes API Server |
| 2379-2380 | etcd server/client API |
| 10250 | kubelet API |
| 10257 | kube-controller-manager |
| 10259 | kube-scheduler |
| 30000-32767 | NodePort service range |
| 179 | Calico BGP peering |
| cali+ / tunl+ | Calico virtual/tunnel interfaces |

---

## 7. Storage — local-path-provisioner

Run on the **master node**.

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

kubectl get pods -n local-path-storage
kubectl get storageclass
```

Output:
```
NAME                   PROVISIONER              RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION
local-path (default)   rancher.io/local-path    Delete          WaitForFirstConsumer   false
```

| Field | Value | Meaning |
|-------|-------|---------|
| PROVISIONER | rancher.io/local-path | Creates PV on the node's local disk |
| RECLAIMPOLICY | Delete | PV is deleted when PVC is deleted |
| VOLUMEBINDINGMODE | WaitForFirstConsumer | Volume is created only when a Pod uses the PVC |
| ALLOWVOLUMEEXPANSION | false | Cannot resize volume after creation |

> **Why `WaitForFirstConsumer`?**  
> In a multi-node cluster, local storage is tied to a specific node. The provisioner waits until a Pod is scheduled, then creates the volume on **that same node** — preventing a mismatch between where the volume lives and where the Pod runs.

### Example PVC
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
```

<img width="1666" height="567" alt="image" src="https://github.com/user-attachments/assets/637681aa-df39-4419-8867-2af94861bae4" />

