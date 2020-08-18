# Build Bare Metal Kubernetes Dualstack Calico Metallb RaspberryPI 4 Ubuntu Server 64bit. (64bit required!!!)

[![GitHub issues](https://img.shields.io/github/issues/trackhe/Raspberry64bitKubernetesServerDualstack.svg?style=flat-square)](https://GitHub.com/trackhe/Raspberry64bitKubernetesServerDualstack/issues/)
[![GitHub pull-requests](https://img.shields.io/github/issues-pr/trackhe/Raspberry64bitKubernetesServerDualstack?style=flat-square)](https://GitHub.com/trackhe/Raspberry64bitKubernetesServerDualstack/pull/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](https://github.com/Trackhe/Raspberry64bitKubernetesServerDualstack/pulls)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-brightgreen.svg?style=flat-square)](https://GitHub.com/trackhe/Raspberry64bitKubernetesServerDualstack/graphs/commit-activity)

**Required:**
Running RaspberryPI 4 with the Ubuntu Server 64bit from here.

Image: [ubuntu/server64](https://ubuntu.com/download/raspberry-pi/thank-you?version=20.04.1&architecture=arm64+raspi)
new versions can be found here: [ubuntu/server/raspberrypi](https://ubuntu.com/download/raspberry-pi) download the 64bit version. (64bit required!!!)

**copy the image on your SD card with:**
Raspberry Pi Imager for Windows(https://downloads.raspberrypi.org/imager/imager_1.4.exe)
Raspberry Pi Imager for macOS(https://downloads.raspberrypi.org/imager/imager_1.4.dmg)
Raspberry Pi Imager for Ubuntu(https://downloads.raspberrypi.org/imager/imager_1.4_amd64.deb)
new versions can be found here: [raspberry/downloads](https://www.raspberrypi.org/downloads/)

Before you start your pi copy the "ssh" file on the SDCard.
download: [ssh/file](https://raw.githubusercontent.com/Trackhe/Raspberry64bitKubernetesServerDualstack/master/ssh)

[Another Guide for installing Ubuntu Server arm64 on Pi (and connect with W-Lan)](https://linuxize.com/post/how-to-install-ubuntu-on-raspberry-pi/)


--- First Steps after boot Pi. ---
Connect with an SSH client to your Pi/'s

login with username `ubuntu` and password `ubuntu`.
```
sudo apt update && sudo apt -y dist-upgrade
```

install your dependencies and tools.
```
sudo apt -y install net-tools dphys-swapfile git
```

change your timezone. you can see your actually time on the rpi with `timedatectl` and set with
```
sudo dpkg-reconfigure tzdata
```
if you want to use it in your script automaticly use   `timedatectl set-timezone 'Europe/Berlin'` here is a list [timezone/list](https://gist.github.com/adamgen/3f2c30361296bbb45ada43d83c1ac4e5)


configure `gpu_mem`.
```
cat <<EOF | sudo tee -a /boot/firmware/usercfg.txt
gpu_mem=16
EOF
```

enable `cgroup_memory` for kubernetes.
```
sudo sh -c 'echo $(cat /boot/firmware/cmdline.txt) "cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1" > /boot/firmware/cmdline.txt'
```

Prepare OS.
```
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF
```
and apply it.
```
sudo sysctl --system
```

change the hostname before we begin with kubernetes.
you need to edit the hosts file with
```
sudo nano /etc/hosts
```
and in the hostname file.
```
sudo nano /etc/hostname
```

so you finished now then reboot.
```
sudo reboot
```

--- Install Kubernetes Dualstack ---

Install Docker:
```
curl -fSLs https://get.docker.com | sudo sh
```

Give Docker User root:
```
sudo usermod -aG docker ubuntu
```

Add the Docker apt repository:
```
sudo add-apt-repository \
  "deb [arch=arm64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"
```

Set up the Docker daemon for autostart:
```
sudo sh -c 'cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF'
```
```
sudo mkdir -p /etc/systemd/system/docker.service.d && \
sudo systemctl enable docker
```

Disable SWAP:
```
sudo swapoff -a
sudo dphys-swapfile swapoff && \
sudo dphys-swapfile uninstall && \
sudo systemctl disable dphys-swapfile
```

Disable the Firewall if you have a Dedicated FW.
```
sudo ufw disable
```

First Step Install packages.cloud.google kubernetes.list:
```
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - && \
sudo sh -c 'echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list'
```

You will install these packages on all of your machines:
* kubeadm: the command to bootstrap the cluster.
* kubelet: the component that runs on all of the machines in your cluster and does things like starting pods and containers.
* kubectl: the command line util to talk to your cluster.

```
sudo apt-get update && sudo apt-get install -y kubelet kubeadm kubectl
```

Soo you can use:
```
cat >> kubeadm.yaml << EOF
apiVersion: kubeadm.k8s.io/v1beta2
featureGates:
  IPv6DualStack: true
kind: ClusterConfiguration
networking:
  podSubnet: 192.168.0.0/16
EOF
```
init master.
```
sudo kubeadm init --config kubeadm.yaml
```

Configure Kubectl:
```
mkdir -p $HOME/.kube && \
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && \
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

So you need to deploy a Network Pod.
```
wget https://docs.projectcalico.org/v3.14/manifests/calico.yaml && \
kubectl apply -f calico.yaml
```

Be sure `kubectl get pods --all-namespaces` result:

```
NAMESPACE     NAME                                       READY   STATUS    RESTARTS   AGE
kube-system   calico-kube-controllers-number             1/1     Running   0          100s
kube-system   calico-node-number                         1/1     Running   0          95s
kube-system   coredns-number                             1/1     Running   0          100s
kube-system   coredns-number                             1/1     Running   0          100s
kube-system   etcd-hostname                              1/1     Running   0          120s
kube-system   kube-apiserver-hostname                    1/1     Running   0          120s
kube-system   kube-controller-manager-hostname           1/1     Running   1          120s
kube-system   kube-proxy-number                          1/1     Running   0          100s
kube-system   kube-scheduler-hostname                    1/1     Running   1          120s
```

Modifying Calico to support IPv6
We need to make the following changes to the calico.yaml file:

The ipam part (the ConfigMap) should look as follows:
```
"ipam": {
        "type": "calico-ipam",
        "assign_ipv4": "true",
        "assign_ipv6": "true"
},
```
Pay very close attention to the indentation here (even in the JSON part)

Add the following environment variables to the calico-node container (environment variables start at about line 633):
```
env:
 - name: IP6
    value: "autodetect"
 - name: FELIX_IPV6SUPPORT
    value: "true"
```
Apply the file now to patch the existing deployment:

```
kubectl apply -f calico.yaml
```
Again, wait until all the Calico pods are running and have passed the readiness probes.

You need to untain your node to run pods on master Node:
```
kubectl taint nodes --all node-role.kubernetes.io/master-
```

Install Calicoctl:

```
kubectl apply -f https://docs.projectcalico.org/manifests/calicoctl.yaml
```

wait a second to create the container and do

```
alias calicoctl="kubectl exec -i -n kube-system calicoctl -- /calicoctl"
```
now you can use Calicoctl.

```
cat >> calicoip6.yaml << EOF
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: default-ipv6-ippool
spec:
  cidr: fd7a:cccc:dddd::/48
  natOutgoing: true
EOF
```

```
calicoctl create -f - < calicoip6.yaml
```

Install Dashboard:

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.3/aio/deploy/recommended.yaml
```
and Metrics Server
```
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.7/components.yaml
```

Download dashboard user, ClusterRoleBinding, deploy and get the login token.

```
wget https://raw.githubusercontent.com/Trackhe/Rasbian64bitKubernetesServerDualstack/master/deployment/admin-user.yaml && \
kubectl apply -f admin-user.yaml && \
wget https://raw.githubusercontent.com/Trackhe/Rasbian64bitKubernetesServerDualstack/master/deployment/admin-cluster-role-binding.yaml && \
kubectl apply -f admin-cluster-role-binding.yaml && \
kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')
```

Now you can connect to the server with a terminal via `ssh -L 8001:localhost:8001 pi@piipaddresse` -> `su` -> `raspberry` or the password -> run `kubectl proxy --address='0.0.0.0' --accept-hosts='^*$'`
and reach the Dashboard via `http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/overview?namespace=_all`

For Mac terminal: `ssh -L 8001:localhost:8001 pi@piipaddresse`
Linux Like Ubuntu : Unknown pls use google
Windows PShell : Unknown pls use google


You need to edit the Deployment of Metrics Server.
```
- --kubelet-preferred-address-types=InternalIP
- --kubelet-insecure-tls
```

A Part, to add Metallb as LoadBalancer and Longhorn for Cluster Storage, follows soon.

A Part to make the Dashboard on the LAN Reachable follows soon.

... Coming soon...

I hope you enjoy. Best Regards.

[![Paypal Donate Button](https://raw.githubusercontent.com/Trackhe/Rasbian64bitKubernetesServerDualstack/master/paypal-donate-button-.png)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=QY8TN4B4L87F4&source=url)

Feel free to make improvements. and share it with us.
