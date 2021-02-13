#!/bin/bash
set -ex

. /etc/default/grub
sudo -E sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"${GRUB_CMDLINE_LINUX_DEFAULT} default_hugepagesz=1G hugepagesz=1G hugepages=384\"/" /etc/default/grub
sudo update-grub