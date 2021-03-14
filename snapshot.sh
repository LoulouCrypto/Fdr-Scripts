#!/bin/bash
# Script done by LoulouCrypto
# https://www.louloucrypto.fr
cd
echo -e "Stoping Node" 
sleep 1
systemctl stop FDReserve
sleep 1
cd .fdreserve
sleep 1
rm snapshot*
sleep 1
echo -e "Downloading SnapShot" 
wget https://fdreserve.com/downloads/snapshot-test.zip
sleep 1
rm -r blocks chainstate db.log debug.log fee_estimates.dat mncache.dat peers.dat 
sleep 1
unzip snapshot-test.zip
sleep 2 
rm snapshot*
systemctl start FDReserve
echo -e "Lunching Node" 
sleep 30
fdreserve-cli getbockcount
sleep 1
fdreserve-cli getmasternodestatus
rm snapshot.sh
# If you want to support me
# fdr wallet : 
# fYWa6E3gthATUF2rThr7TtBaVGa1dm7vR8
