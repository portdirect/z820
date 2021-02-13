#!/bin/bash
set -ex

sudo apt-get update
sudo apt-get install --no-install-recommends -y numactl

host_cpus=16
number_of_nodes="$(numactl --hardware | awk '/^available/ { print $2; exit }')"


function generate_core_list() {
for numa_node in `seq 0 $(( ${number_of_nodes} - 1 ))`; do
  cores_in_node=$(numactl --hardware | awk -F "node ${numa_node} cpus:" "/^node ${numa_node} cpus: / { print \$2; exit }")
  cores_wanted_per_node="$(( host_cpus / number_of_nodes ))"
  echo $cores_in_node | awk "{ for( i=1; i<=${cores_wanted_per_node}; i++ ) { print \$i } }"
done
}

host_cores="$(generate_core_list | awk '{printf NR==1?$0:" "$0}')"


. /etc/default/grub
sudo -E sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\'${GRUB_CMDLINE_LINUX_DEFAULT} systemd.cpu_affinity=\"${host_cores}\"\'/" /etc/default/grub
sudo update-grub


sudo sed -i "s/[#]CPUAffinity.*/CPUAffinity=${host_cores}/" /etc/systemd/system.conf