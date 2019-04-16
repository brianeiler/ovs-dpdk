#!/bin/sh

export DPDK_DIR=/opt/ovs-dpdk-lab/dpdk
export DPDK_BUILD=$DPDK_DIR/x86_64-native-linuxapp-gcc
export OVS_DIR=/opt/ovs-dpdk-lab/ovs
export DB_SOCK=/usr/local/var/run/openvswitch/db.sock

#modprobe uio > /dev/null
#insmod $DPDK_BUILD/kmod/igb_uio.ko > /dev/null

# Bind OVS to the second NUMA node. All device IDs are 80 or higher.
python $DPDK_DIR/usertools/dpdk-devbind.py --bind=igb_uio af:00.0
python $DPDK_DIR/usertools/dpdk-devbind.py --bind=igb_uio af:00.1
python $DPDK_DIR/usertools/dpdk-devbind.py --bind=igb_uio b1:00.0
python $DPDK_DIR/usertools/dpdk-devbind.py --bind=igb_uio b1:00.1

# terminate OVS
pkill -9 ovs
rm -rf /usr/local/var/run/openvswitch
rm -rf /usr/local/etc/openvswitch/
rm -rf /usr/local/var/log/openvswitch
rm -f /tmp/conf.db

mkdir -p /usr/local/etc/openvswitch
mkdir -p /usr/local/var/run/openvswitch
mkdir -p /usr/local/var/log/openvswitch

# initialize new OVS database
cd $OVS_DIR
$OVS_DIR/ovsdb/ovsdb-tool create /usr/local/etc/openvswitch/conf.db $OVS_DIR/vswitchd/vswitch.ovsschema

#start database server
$OVS_DIR/ovsdb/ovsdb-server --remote=punix:$DB_SOCK \
	--remote=db:Open_vSwitch,Open_vSwitch,manager_options \
	--pidfile --detach

#As both TRex and OvS-DPDK create hugepages via DPDK, they need to change from the default hugepage-backed filenames
$OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-extra=”--file-prefix=ovs”

#initialize OVS database
$OVS_DIR/utilities/ovs-vsctl --no-wait init

# Configure OVS with the CPU cores and RAM for the SECOND NUMA node
$OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true 
$OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask=0x200000  	# This is core 21, the second core in the second NUMA node
$OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="0,2048"		# This assigns 2GB of RAM to the second NUMA node, and none to the first
$OVS_DIR/vswitchd/ovs-vswitchd unix:$DB_SOCK \
	--pidfile \
	--detach  \
	--log-file=/usr/local/var/log/openvswitch/ovs-vswitchd.log
$OVS_DIR/utilities/ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask=0xC000000000C000000   #4C8T -- uses CPUs 26,27,66,67
$OVS_DIR/utilities/ovs-vsctl set Open_vSwitch . other_config:max-idle=30000


#create OVS DPDK Bridge and add the four physical NICs
$OVS_DIR/utilities/ovs-vsctl add-br br0 -- set bridge br0 datapath_type=netdev
ifconfig br0 0 up
$OVS_DIR/utilities/ovs-vsctl add-port br0 dpdk0 -- set Interface dpdk0 type=dpdk options:dpdk-devargs=0000:af:00.0 other_config:pmd-rxq-affinity="0:26"
$OVS_DIR/utilities/ovs-vsctl add-port br0 dpdk1 -- set Interface dpdk1 type=dpdk options:dpdk-devargs=0000:af:00.1 other_config:pmd-rxq-affinity="0:27"
$OVS_DIR/utilities/ovs-vsctl add-port br0 dpdk2 -- set Interface dpdk2 type=dpdk options:dpdk-devargs=0000:b1:00.0 other_config:pmd-rxq-affinity="0:66"
$OVS_DIR/utilities/ovs-vsctl add-port br0 dpdk3 -- set Interface dpdk3 type=dpdk options:dpdk-devargs=0000:b1:00.1 other_config:pmd-rxq-affinity="0:67"

$OVS_DIR/utilities/ovs-vsctl show
$OVS_DIR/utilities/ovs-appctl dpif-netdev/pmd-rxq-show

$OVS_DIR/utilities/ovs-ofctl add-flow br0 in_port=1,action=output:2
$OVS_DIR/utilities/ovs-ofctl add-flow br0 in_port=2,action=output:1
$OVS_DIR/utilities/ovs-ofctl add-flow br0 in_port=3,action=output:4
$OVS_DIR/utilities/ovs-ofctl add-flow br0 in_port=4,action=output:3

$OVS_DIR/utilities/ovs-ofctl dump-flows br0


echo
echo "Done"
echo