# Kubernetes Cluster Automation with kubeadm

## Overview

This project automates the deployment of a Kubernetes cluster using **kubeadm** and **Bash scripting**.

The automation covers the installation and configuration of Kubernetes components, containerd runtime, cluster initialization, networking, and storage setup.

## Features

* Automated Kubernetes prerequisites installation
* Automatic containerd installation and configuration
* Kubernetes v1.29 installation
* Kubernetes repository configuration
* Swap disabling
* SELinux configuration (RHEL-based systems)
* Kernel parameter configuration
* Kubernetes Master initialization
* Automatic Calico CNI installation
* Local Path Provisioner installation
* Automatic generation of the worker join command


### all(Ubuntu/AL).sh

Executed on **both Master and Worker nodes**.

Responsibilities:

* Disable Swap
* Configure SELinux
* Configure kernel parameters
* Install Kubernetes packages
* Install and configure containerd
* Enable required services

### master.sh

Executed **only on the Master node**.

Responsibilities:

* Initialize the Kubernetes cluster
* Configure kubectl
* Install Calico CNI
* Install Local Path Provisioner
* Generate the kubeadm join command

## Requirements

* Linux Server

  * Ubuntu 22.04 LTS
  * CentOS Stream 9
* Minimum 2 vCPU
* Minimum 4 GB RAM
* Internet connection
* Root or sudo privileges

## Usage

### Step 1

Run the common script on every node.

```bash
chmod +x allUbuntu.sh
sudo ./allUbuntu.sh

chmod +x allAL.sh
sudo ./allAL.sh
```

### Step 2

Run the master script on the control plane.

```bash
chmod +x masterUbuntu.sh
sudo ./masterUbuntu.sh
```

### Step 3

Copy the generated `kubeadm join` command.

### Step 4

Run the join command on every worker node.

## Verify the Cluster

```bash
kubectl get nodes

kubectl get pods -A
```

## Technologies

* Kubernetes
* kubeadm
* containerd
* Calico
* Local Path Provisioner
* Bash
* Linux

## Author

Esraa
