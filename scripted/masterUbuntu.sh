#!/bin/bash

# Initialize Kubernetes Cluster

POD_NETWORK="192.168.0.0/16"

kubeadm init \
  --pod-network-cidr=$POD_NETWORK \
  --cri-socket=unix:///run/containerd/containerd.sock

# Configure kubectl

mkdir -p $HOME/.kube

cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

chown $(id -u):$(id -g) $HOME/.kube/config

# Install Calico Network Plugin

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.3/manifests/calico.yaml

# Generate Join Command

kubeadm token create --print-join-command
