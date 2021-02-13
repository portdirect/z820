#!/bin/bash
set -ex

sudo tee /etc/hosts <<EOF
127.0.0.1       localhost
127.0.1.1       singapore.localdomain      singapore

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouter
EOF

sudo hostnamectl set-hostname singapore