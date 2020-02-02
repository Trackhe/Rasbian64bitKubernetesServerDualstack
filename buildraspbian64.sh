apt install -y debootstrap dosfstools qemu qemu-user-static binfmt-support build-essential git bison flex libssl-dev cmake libncurses-dev parted bc binutils-aarch64-linux-gnu gcc-aarch64-linux-gnu g++-8-aarch64-linux-gnu
ln -sf /usr/bin/aarch64-linux-gnu-g++-8 /usr/bin/aarch64-linux-gnu-g++

BaseWorkDir=$(pwd)/rpi4
mkdir -p $BaseWorkDir
cd $BaseWorkDir
dd if=/dev/zero of=debian-rpi4.img iflag=fullblock bs=1M count=3600

Loop_Dev=$(losetup -f -P --show debian-rpi4.img)
parted $Loop_Dev "mklabel msdos"
parted $Loop_Dev "mkpart p fat32 1 255"
parted $Loop_Dev "mkpart p ext4 255 -1"

mkfs.vfat $(echo $Loop_Dev)p1 || /bin/true
mkfs.ext4 $(echo $Loop_Dev)p2 || /bin/true

mount $(echo $Loop_Dev)p2 /mnt
mkdir /mnt/boot
mount $(echo $Loop_Dev)p1 /mnt/boot
mount -i -o remount,exec,dev /mnt

qemu-debootstrap --arch=arm64 buster /mnt

mount -o bind /sys /mnt/sys
mount -o bind /proc /mnt/proc
mount -o bind /dev /mnt/dev
mount -o bind /dev/pts /mnt/dev/pts

cp /etc/resolv.conf /mnt/etc/resolv.conf

chroot /mnt /bin/bash -x <<'EOF'
echo "deb http://deb.debian.org/debian/ buster main non-free contrib
deb-src http://deb.debian.org/debian/ buster main non-free contrib
deb http://security.debian.org/debian-security buster/updates main contrib non-free
deb-src http://security.debian.org/debian-security buster/updates main contrib non-free
deb http://deb.debian.org/debian/ buster-updates main contrib non-free
deb-src http://deb.debian.org/debian/ buster-updates main contrib non-free" > /etc/apt/sources.list

apt-get update
apt install -y console-setup debconf locales wget sudo ca-certificates dbus dhcpcd5 net-tools ssh openssh-server nano ntp screen htop multitail bc most dnsutils mc autofs wpasupplicant wireless-tools git lua5.1 alsa-utils psmisc initramfs-tools curl binutils parted
apt --fix-broken install

dpkg-reconfigure locales
dpkg-reconfigure keyboard-configuration
dpkg-reconfigure tzdata

echo root:raspberry | chpasswd

adduser pi --gecos "" --disabled-password
echo pi:raspberry | chpasswd

usermod -aG video,audio,redner,sudo pi
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
EOF

cd /
umount /mnt/dev/pts || /bin/true
mount -o remount,ro /mnt/dev || /bin/true
umount /mnt/dev || /bin/true
umount /mnt/proc || /bin/true
umount /mnt/sys || /bin/true

cd /mnt/boot && \
URL="https://github.com/raspberrypi/firmware/raw/master/boot/"
for FILE in fixup4cd.dat fixup4.dat fixup4db.dat fixup4x.dat start4cd.elf start4db.elf start4.elf start4x.elf;\
do wget $URL/$FILE;\
done

mkdir /tmp/firmware
git clone https://github.com/RPi-Distro/firmware-nonfree /tmp/firmware
cp -va /tmp/firmware/* /mnt/lib/firmware

cd $BaseWorkDir

git clone --depth=1 --branch rpi-4.19.y https://github.com/raspberrypi/linux

cd linux
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2711_defconfig

make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- menuconfig

make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
cp arch/arm64/boot/Image /mnt/boot/kernel8.img

make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- INSTALL_MOD_PATH=/mnt modules_install

make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- INSTALL_DTBS_PATH=/mnt/boot dtbs_install
cp /mnt/boot/broadcom/bcm2711-rpi-4-b.dtb /mnt/boot

cd $BaseWorkDir
git clone https://github.com/raspberrypi/tools.git tools
cd tools/armstubs
make -j4 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- armstub8-gic.bin
cp armstub8-gic.bin /mnt/boot

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
" > /mnt/boot/config.txt

echo "root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait\
 snd_bcm2835.enable_headphones=1 snd_bcm2835.enable_hdmi=1 snd_bcm2835.enable_compat_alsa=1" > /mnt/boot/cmdline.txt

cd $BaseWorkDir
apt-install pkg-config
git clone https://github.com/raspberrypi/userland
cd userland
sed s/sudo// -i buildme
./buildme --aarch64 /mnt
echo "/opt/vc/lib" > /mnt/etc/ld.so.conf.d/userland.conf
cp -va build/bin/* /mnt/usr/local/bin

umount /mnt/boot
umount /mnt
losetup –d /dev/loop0

cd $BaseWorkDir
