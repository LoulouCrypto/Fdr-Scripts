#!/bin/bash
cd ~
rm fdr*
killall fdreserved
sleep 2
rm -rf .fdreserve
sleep 2
rm -f /usr/local/bin/fdres*
sleep 2 
systemctl disable FDReserve
rm /etc/systemd/system/FDReserve.service
