#!/bin/bash
set -ex

sudo apt-get update
sudo systemctl stop unattended-upgrades
sudo apt-get purge -y unattended-upgrades cron rsyslog
sudo apt-get dist-upgrade -y
sudo apt-get autoremove -y
sudo apt-get install --no-install-recommends -y vim