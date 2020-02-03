# Build Bare Metal Kubernetes Dualstack Calico Metallb RaspberryPI 4 Rasbian Server 64bit.

[![GitHub issues](https://img.shields.io/github/issues/trackhe/Rasbian64bitKubernetesServerDualstack.svg)](https://GitHub.com/trackhe/Rasbian64bitKubernetesServerDualstack/issues/)
[![GitHub pull-requests](https://img.shields.io/github/issues-pr/trackhe/Rasbian64bitKubernetesServerDualstack)](https://GitHub.com/trackhe/Rasbian64bitKubernetesServerDualstack/pull/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://GitHub.com/trackhe/Rasbian64bitKubernetesServerDualstack/graphs/commit-activity)

**Required:**
Running RaspberryPI 4 with the Rasbian Buster 64bit from here.
*(im working on an automated build server.)*

Download or Create a Raspian-Image for your MicroSDcard.

Download: [Here.img](http://cdn.trackhe.info/raspbian/debian-rpi4.img) ca[3.77GB]
Download: [Here.img.zip](http://cdn.trackhe.info/raspbian/debian-rpi4.img.zip) ca[504,2mb]

or:
<details>
  <summary>Create:</summary>

#Orginal Instrucktions Page: [create tilmun/rasberry-pi-4-debian-buster-64bit](https://www.tilmun.de/1-raspberry-pi-4-debian-buster-64-bit-system-und-kernel-selbst-erstellen.html).
My version is only for Server. and useable for Kubernetes.

#I use the stable Kernel Version 4.19 because on v5.5 some like (cggroup memmory amd reboot/shutdown) are replaced.
#(but the basic system runns with kernel 5.5 i have try that)
#build the Kernel faster with "make -j4 ARCH... -j(prozessor thread count).

Required: Debian Buster. Runn as root `sudo -i` or `su`

```
apt install -y debootstrap dosfstools qemu qemu-user-static binfmt-support build-essential git bison flex libssl-dev cmake libncurses-dev parted bc binutils-aarch64-linux-gnu gcc-aarch64-linux-gnu g++-8-aarch64-linux-gnu && \
ln -sf /usr/bin/aarch64-linux-gnu-g++-8 /usr/bin/aarch64-linux-gnu-g++ && \

BaseWorkDir=$(pwd)/rpi4 && \
mkdir -p $BaseWorkDir && \
cd $BaseWorkDir && \
dd if=/dev/zero of=debian-rpi4.img iflag=fullblock bs=1M count=3600 && \

Loop_Dev=$(losetup -f -P --show debian-rpi4.img) && \
parted $Loop_Dev "mklabel msdos" && \
parted $Loop_Dev "mkpart p fat32 1 255" && \
parted $Loop_Dev "mkpart p ext4 255 -1" && \

mkfs.vfat $(echo $Loop_Dev)p1 && \
mkfs.ext4 $(echo $Loop_Dev)p2 && \

mount $(echo $Loop_Dev)p2 /mnt && \
mkdir /mnt/boot && \
mount $(echo $Loop_Dev)p1 /mnt/boot && \
mount -i -o remount,exec,dev /mnt && \

qemu-debootstrap --arch=arm64 buster /mnt && \

mount -o bind /sys /mnt/sys && \
mount -o bind /proc /mnt/proc && \
mount -o bind /dev /mnt/dev && \
mount -o bind /dev/pts /mnt/dev/pts && \

cp /etc/resolv.conf /mnt/etc/resolv.conf && \

chroot /mnt /bin/bash -x <<'EOF'
echo "deb http://deb.debian.org/debian/ buster main non-free contrib
deb-src http://deb.debian.org/debian/ buster main non-free contrib
deb http://security.debian.org/debian-security buster/updates main contrib non-free
deb-src http://security.debian.org/debian-security buster/updates main contrib non-free
deb http://deb.debian.org/debian/ buster-updates main contrib non-free
deb-src http://deb.debian.org/debian/ buster-updates main contrib non-free" > /etc/apt/sources.list

apt-get update
apt install -y console-setup debconf locales wget sudo ca-certificates dbus dhcpcd5 net-tools ssh openssh-server nano ntp screen htop multitail bc most dnsutils mc autofs wpasupplicant wireless-tools git lua5.1 alsa-utils psmisc initramfs-tools curl binutils parted dphys-swapfile
apt --fix-broken install

dpkg-reconfigure locales          
dpkg-reconfigure keyboard-configuration
dpkg-reconfigure tzdata

echo root:raspberry | chpasswd

adduser pi --gecos "" --disabled-password
echo pi:raspberry | chpasswd

usermod -aG video,audio,redner,sudo pi

echo 'pi      ALL=(ALL:ALL) ALL' >> /etc/sudoers

echo 'SUBSYSTEM=="vchiq",GROUP="video",MODE="0660"' > /etc/udev/rules.d/10-vchiq-permissions.rules

service dbus restart
echo "raspberrypinew" > /etc/hostname

echo "
/dev/mmcblk0p1 /boot   vfat    noatime,nodiratime                   0  2
/dev/mmcblk0p2 /       ext4    noatime,nodiratime,errors=remount-ro 0  1
tmpfs          /tmp    tmpfs   nosuid                               0  0
" > /etc/fstab

systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service
systenctl enable ssh

echo "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=DE"  > /etc/wpa_supplicant/wpa_supplicant.conf

cd /tmp && \
git clone https://git.kernel.org/pub/scm/linux/kernel/git/sforshee/wireless-regdb.git
cd wireless-regdb
mkdir -p /lib/firmware/brcm
cp regulatory.db.p7s regulatory.db /lib/firmware
cd /lib/firmware/brcm
ln -s brcmfmac43455-sdio.bin brcmfmac43455-sdio.raspberrypi,4-model-b.bin
ln -s brcmfmac43455-sdio.clm_blob brcmfmac43455-sdio.raspberrypi,4-model-b.clm_blob
ln -s brcmfmac43455-sdio.txt brcmfmac43455-sdio.raspberrypi,4-model-b.txt

cd /tmp
mkdir toolsrcu && cd toolsrcu
wget https://archive.raspberrypi.org/debian/pool/main/r/raspi-config/raspi-config_20200120_all.deb
wget https://archive.raspberrypi.org/debian/pool/main/r/rpi-update/rpi-update_20140705_all.deb

dpkg -i raspi-config_20200120_all.deb
dpkg -i rpi-update_20140705_all.deb
EOF && \

cd / && \
umount -l /mnt/dev/pts || /bin/true && \
mount -o remount,ro /mnt/dev || /bin/true && \
umount -l /mnt/dev || /bin/true  && \
umount -l /mnt/proc || /bin/true  && \
umount -l  /mnt/sys || /bin/true  && \

cd /mnt/boot && \
URL="https://github.com/raspberrypi/firmware/raw/master/boot/" && \
for FILE in fixup4cd.dat fixup4.dat fixup4db.dat fixup4x.dat start4cd.elf start4db.elf start4.elf start4x.elf;\
do wget $URL/$FILE;\
done && \

mkdir /tmp/firmware && \
git clone https://github.com/RPi-Distro/firmware-nonfree /tmp/firmware && \
cp -va /tmp/firmware/* /mnt/lib/firmware && \

cd $BaseWorkDir && \

git clone --depth=1 --branch rpi-4.19.y https://github.com/raspberrypi/linux && \

cd linux && \
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2711_defconfig && \

make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- && \
cp arch/arm64/boot/Image /mnt/boot/kernel8.img && \

make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- INSTALL_MOD_PATH=/mnt modules_install && \

make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- INSTALL_DTBS_PATH=/mnt/boot dtbs_install && \
cp /mnt/boot/broadcom/bcm2711-rpi-4-b.dtb /mnt/boot && \

cd $BaseWorkDir && \
git clone https://github.com/raspberrypi/tools.git tools && \
cd tools/armstubs && \
make -j4 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- armstub8-gic.bin && \
cp armstub8-gic.bin /mnt/boot && \

echo "[HDMI:0]
hdmi_force_hotplug=1
gpu_mem=16
dtoverlay=vc4-fkms-v3d
max_framebuffers=2
armstub=armstub8-gic.bin
enable_gic=1
arm_64bit=1
# Auskommentieren um wifi deaktivieren
#dtoverlay=disable-wifi
" > /mnt/boot/config.txt && \

echo "root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait\
 snd_bcm2835.enable_headphones=1 snd_bcm2835.enable_hdmi=1 snd_bcm2835.enable_compat_alsa=1" > /mnt/boot/cmdline.txt && \

cd $BaseWorkDir && \
apt install pkg-config && \
git clone https://github.com/raspberrypi/userland && \
cd userland && \
sed s/sudo// -i buildme && \
./buildme --aarch64 /mnt && \
mkdir -p /mnt/etc/ld.so.conf.d && \
echo "/opt/vc/lib" > /mnt/etc/ld.so.conf.d/userland.conf && \
mkdir -p /mnt/usr/local/bin && \
cp -va build/bin/* /mnt/usr/local/bin && \

umount -l /mnt/boot || /bin/true  && \
umount -l /mnt || /bin/true  && \
losetup –d /dev/loop0 && \

cd $BaseWorkDir
EOF
```
</details>

**copy the image on your SD card with:**
Tool: [balena.io/etcher](https://www.balena.io/etcher/)

First of all be sure that you run it on the raspberry:
```sudo -i```
```
apt install parted
parted /dev/mmcblk0 "resizepart 2 -1"
resize2fs /dev/mmcblk0p2
```

Configure it before you start with this Manuell:
```
sudo raspi-config
```

Run all at Root:
```
sudo -i
```

Install Docker:
```
curl -fSLs https://get.docker.com | sudo sh
```

Give Docker User root:
```
sudo usermod -aG docker pi
```

Disable SWAP:
```
sudo dphys-swapfile swapoff && \
sudo dphys-swapfile uninstall && \
sudo systemctl disable dphys-swapfile
```
When you gett dphys-swapfile not found `sudo apt-get install dphys-swapfile`

First Step Install packages.cloud.google kubernetes.list:
```
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
```

You will install these packages on all of your machines:
* kubeadm: the command to bootstrap the cluster.
* kubelet: the component that runs on all of the machines in your cluster and does things like starting pods and containers.
* kubectl: the command line util to talk to your cluster.

```
apt-get update && apt-get install -y kubelet kubeadm kubectl
```

Recommended but optional: ```apt-mark hold kubelet kubeadm kubectl```

[WARNING IsDockerSystemdCheck]: detected "cgroupfs" as the Docker cgroup driver. The recommended driver is "systemd". Please follow the guide at https://kubernetes.io/docs/setup/cri/

Soo you can use:
```
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```
or  ```sudo kubeadm join``` with the required extra arguments. You get it after "kubeadm init" on Master.

##Idont know why but you need `sudo` if you get command not found.

Configure Kubectl:
```
mkdir -p $HOME/.kube && \
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && \
chown $(id -u):$(id -g) $HOME/.kube/config
```

So you need to deploy a Network Pod.
```
kubectl apply -f https://docs.projectcalico.org/v3.11/manifests/calico.yaml
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
Install Dashboard:

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-rc3/aio/deploy/recommended.yaml
```

To run Metrics Pod you need to untain your node:
```
kubectl taint nodes --all node-role.kubernetes.io/master-
```

Clone Metrics Server:
```
apt-get install git && \
git clone https://github.com/kubernetes-sigs/metrics-server.git && \
cd metrics-server && \
sed -i s/amd64/arm64/g deploy/1.8+/metrics-server-deployment.yaml && \
nano deploy/1.8+/metrics-server-deployment.yaml
```

Edit from:
```
containers:
- name: metrics-server
  image: k8s.gcr.io/metrics-server-arm64:v0.3.6
  args:
    - --cert-dir=/tmp
    - --secure-port=4443
```
to:
```
containers:
  - name: metrics-server
    image: k8s.gcr.io/metrics-server-arm64:v0.3.6
    args:
      - --cert-dir=/tmp
      - --secure-port=4443
      - --kubelet-insecure-tls
      - --kubelet-preferred-address-types=InternalIP
```
and deploy:
```
kubectl create -f deploy/1.8+/
```

Go back `cd ..` and download dashboard user, ClusterRoleBinding, deploy and get the login token.

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
Linux Like Ubuntu : Unknown pls google
Windows PShell : Unknown pls google

A Part to make the Dashboard on the LAN Reachable follows soon.

... Coming soon...

I hope you enjoy. Best Regards.

[![Paypal Donate Button](https://raw.githubusercontent.com/Trackhe/Rasbian64bitKubernetesServerDualstack/master/paypal-donate-button-.png)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=QY8TN4B4L87F4&source=url)

Feel free to make improvements. and share it with us.
