#!/bin/bash
set -ex

sudo apt-get update
sudo apt-get install -y --no-install-recommends netplan.io

sudo tee /etc/netplan/netplan.yaml <<EOF
# This network config over-wites the one set up by the ubuntu installer
# note that ethernets need to come first for wifi to work:
# https://bugs.launchpad.net/ubuntu/+source/netplan.io/+bug/1809994
network:
  ethernets:
    eno1: {}
    enp1s0: {}
    ens2f0:
      dhcp4: false
      link-local: []
    ens2f1:
      dhcp4: false
      link-local: []
    ens2f2:
      dhcp4: false
      link-local: []
    ens2f3:
      dhcp4: false
      link-local: []
    ens3f0:
      dhcp4: false
      link-local: []
    ens3f1:
      dhcp4: false
      link-local: []
    ens3f2:
      dhcp4: false
      link-local: []
    ens3f3:
      dhcp4: false
      link-local: []
  bonds:
    bond0:
      dhcp4: true
      dhcp4-overrides:
        route-metric: 100
        hostname: singapore
        send-hostname: true
      interfaces:
      - eno1
      - enp1s0
      parameters:
        lacp-rate: slow
        mode: 802.3ad
        transmit-hash-policy: layer2
  wifis:
    wls5:
      dhcp4: true
      dhcp4-overrides:
        route-metric: 200
        hostname: singapore-wifi
        send-hostname: true
      access-points:
        portdirect:
          password: "password"
  version: 2
EOF

sudo mkdir -p /etc/systemd/system/systemd-networkd-wait-online.service.d
sudo tee /etc/systemd/system/systemd-networkd-wait-online.service.d/10-wls5.conf <<EOF
[Service]
ExecStart=
ExecStart=/lib/systemd/systemd-networkd-wait-online --interface=wls5
EOF
sudo systemctl daemon-reload

(
sudo systemctl disable --now networking
sudo apt-get purge -y ifupdown
sudo systemctl enable --now systemd-networkd
sudo netplan apply
)


