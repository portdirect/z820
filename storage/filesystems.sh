#!/bin/bash
set -ex

sudo -E apt-get update
sudo -E apt-get install -y --no-install-recommends mdadm xfsprogs gdisk
sudo -E mdadm -V

sudo -E mdadm --create /dev/md0 --level=stripe --raid-devices=2 /dev/sdb /dev/sdc
sudo -E mdadm --detail /dev/md0
dev_name=md0
sudo -E mkfs.xfs -f -L nova /dev/${dev_name}
eval `sudo -E blkid /dev/${dev_name} -o export`
mountpoint=/var/lib/nova
sudo -E mkdir -p ${mountpoint}
sudo -E tee -a /etc/fstab <<EOF
# This is ${DEVNAME} mounted at ${mountpoint}
/dev/disk/by-uuid/${UUID} ${mountpoint} ${TYPE} defaults 0 2
EOF
sudo -E mount -a


dev_name=md1

sudo -E mdadm --create /dev/${dev_name} --level=stripe --raid-devices=2 /dev/nvme0n1 /dev/nvme1n1

sudo -E sgdisk /dev/${dev_name} --zap-all
sudo -E sgdisk /dev/${dev_name} -o
sectors=$(sudo -E blockdev --getsz /dev/${dev_name})
sudo -E sgdisk /dev/${dev_name} --new=1:0:$(( sectors / 3 ))
sudo -E sgdisk /dev/${dev_name} --new=2::+$(( sectors / 8 ))
sudo -E sgdisk /dev/${dev_name} --new=3::+$(( sectors / 16 ))
sudo -E sgdisk /dev/${dev_name} --largest-new=4

sudo -E mkfs.xfs -L containerd /dev/${dev_name}p1
sudo -E mkfs.xfs -L kubelet /dev/${dev_name}p2
sudo -E mkfs.xfs -L etcd /dev/${dev_name}p3
sudo -E mkfs.xfs -L srv /dev/${dev_name}p4


eval `sudo -E blkid /dev/${dev_name}p1 -o export`
mountpoint=/var/lib/containerd
sudo -E mkdir -p ${mountpoint}
sudo -E tee -a /etc/fstab <<EOF
# This is ${DEVNAME} mounted at ${mountpoint}
/dev/disk/by-uuid/${UUID} ${mountpoint} ${TYPE} defaults 0 2
EOF

eval `sudo -E blkid /dev/${dev_name}p2 -o export`
mountpoint=/var/lib/kubelet
sudo -E mkdir -p ${mountpoint}
sudo -E tee -a /etc/fstab <<EOF
# This is ${DEVNAME} mounted at ${mountpoint}
/dev/disk/by-uuid/${UUID} ${mountpoint} ${TYPE} defaults 0 2
EOF

eval `sudo -E blkid /dev/${dev_name}p3 -o export`
mountpoint=/var/lib/etcd
sudo -E mkdir -p ${mountpoint}
sudo -E tee -a /etc/fstab <<EOF
# This is ${DEVNAME} mounted at ${mountpoint}
/dev/disk/by-uuid/${UUID} ${mountpoint} ${TYPE} defaults 0 2
EOF

eval `sudo -E blkid /dev/${dev_name}p4 -o export`
mountpoint=/srv
sudo -E mkdir -p ${mountpoint}
sudo -E tee -a /etc/fstab <<EOF
# This is ${DEVNAME} mounted at ${mountpoint}
/dev/disk/by-uuid/${UUID} ${mountpoint} ${TYPE} defaults 0 2
EOF

sudo -E mount -a