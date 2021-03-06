#!/bin/bash

# Load the custom global environment variables
source /etc/0-ovs-dpdk-global-variables.sh


# Bind OVS to the second NUMA node. All device IDs are 80 or higher.
python $DPDK_DIR/usertools/dpdk-devbind.py --bind=igb_uio ${PCI_ADDR_NIC4}
python $DPDK_DIR/usertools/dpdk-devbind.py --bind=igb_uio ${PCI_ADDR_NIC5}
python $DPDK_DIR/usertools/dpdk-devbind.py --bind=igb_uio ${PCI_ADDR_NIC6}
python $DPDK_DIR/usertools/dpdk-devbind.py --bind=igb_uio ${PCI_ADDR_NIC7}

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
$OVS_DIR/ovsdb/ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
	--remote=db:Open_vSwitch,Open_vSwitch,manager_options \
	--pidfile --detach

#As both TRex and OvS-DPDK create hugepages via DPDK, they need to change from the default hugepage-backed filenames
$OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-extra=”--file-prefix=ovs”

#initialize OVS database
$OVS_DIR/utilities/ovs-vsctl --no-wait init

# Configure OVS with the CPU cores and RAM for the SECOND NUMA node
$OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true 
$OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask=${cpu_ovs_lcpu_mask}  	# This is core 21, the second core in the second NUMA node
$OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="0,2048" 		# This assigns 2GB of RAM to the second NUMA node, and none to the first
$OVS_DIR/vswitchd/ovs-vswitchd unix:/usr/local/var/run/openvswitch/db.sock \
	--pidfile \
	--detach  \
	--log-file=/usr/local/var/log/openvswitch/ovs-vswitchd.log
$OVS_DIR/utilities/ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask=${cpu_ovs_pmd_mask}
$OVS_DIR/utilities/ovs-vsctl set Open_vSwitch . other_config:max-idle=30000


#create OVS DPDK Bridge and add the four physical NICs
$OVS_DIR/utilities/ovs-vsctl add-br br0 -- set bridge br0 datapath_type=netdev
ifconfig br0 0 up
$OVS_DIR/utilities/ovs-vsctl add-port br0 dpdk0 -- set Interface dpdk0 type=dpdk options:dpdk-devargs=0000:${PCI_ADDR_NIC4} other_config:pmd-rxq-affinity="0:${cpu_ovs_dpdk0}"
$OVS_DIR/utilities/ovs-vsctl add-port br0 dpdk1 -- set Interface dpdk1 type=dpdk options:dpdk-devargs=0000:${PCI_ADDR_NIC5} other_config:pmd-rxq-affinity="0:${cpu_ovs_dpdk1}"
$OVS_DIR/utilities/ovs-vsctl add-port br0 dpdk2 -- set Interface dpdk2 type=dpdk options:dpdk-devargs=0000:${PCI_ADDR_NIC6} other_config:pmd-rxq-affinity="0:${cpu_ovs_dpdk2}"
$OVS_DIR/utilities/ovs-vsctl add-port br0 dpdk3 -- set Interface dpdk3 type=dpdk options:dpdk-devargs=0000:${PCI_ADDR_NIC7} other_config:pmd-rxq-affinity="0:${cpu_ovs_dpdk3}"

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
