#!/bin/bash

cd /opt/ovs-dpdk-lab/source
apt update
apt install -y net-tools
apt install -y screen

echo
echo "Installing DPDK 18.11.1..."
tar xf dpdk-18.11.1.tar.xz -C /opt
ln -sv /opt/dpdk-stable-18.11.1 /opt/ovs-dpdk-lab/dpdk
/opt/ovs-dpdk-lab/source/compile_dpdk.sh 
echo
echo "Done Installing DPDK 18.11.1"
echo
read -r -p "Check for errors. If all OK, press the ENTER key to continue. Press Ctrl-C to abort the script." key
echo
echo
echo "Installing OVS-2.11.0..."
tar xf openvswitch-2.11.0.tar.gz -C /opt
ln -sv /opt/openvswitch-2.11.0 /opt/ovs-dpdk-lab/ovs
/opt/ovs-dpdk-lab/source/compile_ovs.sh 
echo
echo "Done Installing OVS-2.11.0."
echo
read -r -p "Check for errors. If all OK, press the ENTER key to continue. Press Ctrl-C to abort the script." key
echo
echo
echo "Installing qemu-3.1.0..."
tar xf qemu-3.1.0.tar.xz -C /opt
ln -sv /opt/qemu-3.1.0 /opt/ovs-dpdk-lab/qemu
/opt/ovs-dpdk-lab/source/compile_qemu.sh
echo
echo "Done Installing qemu-3.1.0"
echo
read -r -p "Check for errors. If all OK, press the ENTER key to continue. Press Ctrl-C to abort the script." key
echo
echo
echo "Installing TREX-2.53..."
tar xf trex-v2.53.tgz -C /opt
ln -sv /opt/trex-v2.53 /opt/ovs-dpdk-lab/trex
dpdk_igb_file=/opt/ovs-dpdk-lab/dpdk/x86_64-native-linuxapp-gcc/kmod/igb_uio.ko
trex_igb_dir=/opt/ovs-dpdk-lab/trex/ko/`uname -r`
mkdir $trex_igb_dir
if [ ! -f $dpdk_igb_file ];
then
	echo
	echo The DPDK version of igb_uio.ko is missing. Cannot copy file.
	echo
else
	cp $dpdk_igb_file $trex_igb_dir
	echo
	echo DPDK version of igb_uio.ko copied successfully.
	echo
fi
/opt/ovs-dpdk-lab/source/compile_trex.sh
echo
echo "Done Installing TREX-2.53."
echo
read -r -p "Check for errors. If all OK, press the ENTER key to continue. Press Ctrl-C to abort the script." key
echo
echo
echo "Setting up the Startup Script..."
echo "@reboot root /opt/ovs-dpdk-lab/source/startup-script.sh" >> /etc/crontab
echo
echo "Done Setting up the Startup script"
echo
echo
echo "Setting up the GRUB boot loader"
cp -f /opt/ovs-dpdk-lab/source/grub /etc/default/grub
update-grub
echo
echo "Done Setting up the GRUB boot loader"
echo
echo
echo "You must reboot to complete the changes."
echo "===> Type 'init 6' and press ENTER."
echo