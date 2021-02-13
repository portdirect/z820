#!/bin/bash
set -ex

vfs_per_device=4

sudo tee /etc/systemd/system/sriov-NIC.service <<EOF
[Unit]
Description=Setup SR-IOV VFs on PFs
DefaultDependencies=no

Before=network-pre.target
Wants=network-pre.target

Wants=systemd-modules-load.service local-fs.target
After=systemd-modules-load.service local-fs.target

[Service]
Type=oneshot
EOF
for sriov_device in $(ls /sys/class/net/*/device/sriov_numvfs); do
  dev_name="${sriov_device%/device/sriov_numvfs}"
  dev_name="${dev_name#/sys/class/net/}"
  sudo tee -a /etc/systemd/system/sriov-NIC.service <<EOF
#ExecStart=/usr/bin/bash -c "echo 0 > ${sriov_device}"
ExecStart=/usr/bin/bash -c "echo 4 > ${sriov_device}"
EOF
  for vf in `seq 0 $(( ${vfs_per_device} - 1 ))`; do
    sudo tee -a /etc/systemd/system/sriov-NIC.service <<EOF
ExecStart=-/usr/sbin/ip link set dev ${dev_name} vf ${vf} spoofchk off
ExecStart=-/usr/sbin/ip link set dev ${dev_name} vf ${vf} trust on
EOF
  done
done
sudo tee -a /etc/systemd/system/sriov-NIC.service <<EOF
[Install]
WantedBy=multi-user.target
RequiredBy=libvirtd.service
EOF

sudo systemctl enable --now sriov-NIC.service
