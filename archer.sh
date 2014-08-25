#!/bin/bash
# Simple arch installer for usb sticks and sd cards
# use with samsung arm chromebook
#set -v
which cgpt || exit
which parted || exit 
which mkfs.vfat || exit 
which mkfs.ext2 || exit 
which mkfs.ext4 || exit 
which wget || exit 
which bunzip2 || exit 
echo "Enter device name (eg, /dev/sda)"
echo "Note: This will destroy all data. Avoid mixing with alcohol."
read devname
if [ ! -e "$devname" ] ; then
	echo "Sorry, $devname doesn't exist"
	exit
fi
#if it's an mmc device we need a p
echo "$devname" | grep mmc && needp="p"
umount "$devname"*
echo "Partitioning..."
parted $devname mklabel gpt
cgpt create -z $devname
cgpt create $devname
cgpt add -i 1 -t kernel -b 8192 -s 32768 -l U-Boot -S 1 -T 5 -P 10 $devname
cgpt add -i 2 -t data -b 40960 -s 32768 -l Kernel $devname
cgpt add -i 12 -t data -b 73728 -s 32768 -l Script $devname
gptstart="$(cgpt show $devname | grep 'Sec GPT table' | awk '{print $1}')"
cgpt add -i 3 -t data -b 106496 -s `expr $gptstart - 106496` -l Root $devname
partprobe $devname
#cgpt show $devname
kernelpart="$devname""$needp""1"
bootpart="$devname""$needp""2"
rootpart="$devname""$needp3""3"
scriptpart="$devname""$needp""12"
echo "Formatting boot partition ($bootpart) ext2..."
mkfs.ext2 -vF "$bootpart"
echo "Formatting root partition ($rootpart) ext4..."
mkfs.ext4 -vF "$rootpart"
echo "Formatting scripts partition ($scriptpart) vfat..."
mkfs.vfat -v "$scriptpart"
mkdir /tmp/archinstall
cd /tmp/archinstall
mkdir root 
echo "Downloading base image..."
wget -O - http://archlinuxarm.org/os/ArchLinuxARM-chromebook-latest.tar.gz > ArchLinuxARM-chromebook-latest.tar.gz
mount -t ext4 -v "$rootpart" root 
echo "Copying files..."
tar -xf ArchLinuxARM-chromebook-latest.tar.gz -C root
#ls root
mkdir mnt
mount -t ext2 -v "$bootpart" mnt
echo "Copying kernel..."
cp root/boot/vmlinux.uimg mnt
#ls mnt
umount mnt
echo "Copying uboot scripts..."
mount -t vfat "$scriptpart" mnt
mkdir mnt/u-boot
wget http://archlinuxarm.org/os/exynos/boot.scr.uimg 
cp boot.scr.uimg mnt/u-boot
ls mnt
umount mnt
echo "Downloading bootloader..."
wget -O - http://commondatastorage.googleapis.com/chromeos-localmirror/distfiles/nv_uboot-snow.kpart.bz2 | bunzip2 > nv_uboot-snow.kpart
echo "Writing bootloader to kernel partition ($kernelpart)..."
dd if=nv_uboot-snow.kpart of="$kernelpart"
cd /tmp
echo "Syncing disks..."
sync
echo "unmounting $devname*"
umount "$devname"*
echo "removing /tmp/archinstall"
rm -rf /tmp/archinstall
echo "Ok, you should now have a bootable snow arch stick"
echo "If you havn't hit dev mode yet, here's a hint:"
echo "crossystem dev_boot_usb=1 dev_boot_signed_only=0"
echo "Boot with CTRL+u"
echo "On uboot prompt:"
echo "env default -f"
echo "saveenv"
echo "reset"
echo "Then you should be all set to boot with CTRL-u, or not, whatever"
