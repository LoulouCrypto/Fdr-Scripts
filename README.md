Theses folowing scripts are use to install French Digital Reserve MasterNodes

To learn more about the project : 
https://www.fdreserve.com/

You can use thes to install on or multiple Masternodes on your Server.

-For X86 First install : 
You must be logged as root user and use this :

wget https://github.com/LoulouCrypto/Fdr-Scripts/blob/master/fdr-mn-install.sh && bash fdr-mn-install.sh

-For Arm32 First install :

wget https://github.com/LoulouCrypto/Fdr-Scripts/blob/master/fdr-arm32-install.sh && bash fdr-arm32-install.sh

-To install a Mn by compiling source code : 

wget https://github.com/LoulouCrypto/Fdr-Scripts/blob/master/fdr-mn-compile.sh && bash fdr-mn-compile.sh

-For Multi-Masternode install: 
You have to have already installed the first Masternode and then, create a new sudo user and run : 

sudo wget https://github.com/LoulouCrypto/Fdr-Scripts/blob/master/fdr-multi-install.sh && bash fdr-multi-install.sh
