#!/bin/bash
# Script done by LoulouCrypto
# https://www.louloucrypto.fr

CONFIG_FILE='fdreserve.conf'
CONFIGFOLDER='/home/$USER/.fdreserve'
COIN_PATH='/usr/local/bin/'
#64 bit only
COIN_TGZ='https://github.com/fdreserve/fdr-blockchain/releases/download/V2.3.0/2021-03-15_FDReserve_V230_Linux64.zip'
BOOTSTRAP_TGZ='https://fdreserve.com/downloads/snapshot.zip'
COIN_DAEMON="fdreserved"
COIN_CLI="fdreserve-cli"
COIN_NAME='FDReserve'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

progressfilt () {
  local flag=false c count cr=$'\r' nl=$'\n'
  while IFS='' read -d '' -rn 1 c
  do
    if $flag
    then
      printf '%c' "$c"
    else
      if [[ $c != $cr && $c != $nl ]]
      then
        count=0
      else
        ((count++))
        if ((count > 1))
        then
          flag=true
        fi
      fi
    fi
  done
}

function configure_systemd() {
cd ~/

sudo cat << EOF > $COIN_NAME-$USER.service
[Unit]
Description=$COIN_NAME-$USER service
After=network.target
[Service]
User=$USER
Type=forking
#PIDFile=/home/$USER/.fdreserve/$COIN_NAME.pid
TimeoutStartSec=infinity
ExecStartPost=/bin/sleep $TIMER
ExecStart=$COIN_PATH/$COIN_DAEMON -daemon -conf=/home/$USER/.fdreserve/$CONFIG_FILE -datadir=/home/$USER/.fdreserve
ExecStop=-$COIN_PATH/$COIN_CLI -conf=/home/$USER/.fdreserve/$CONFIG_FILE -datadir=/home/$USER/.fdreserve stop
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF
sudo mv $COIN_NAME-$USER.service /etc/systemd/system/

  sudo systemctl daemon-reload
  sleep 3
  sudo systemctl start $COIN_NAME-$USER.service
  sudo systemctl enable $COIN_NAME-$USER.service >/dev/null 2>&1
  
  if [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON)" ]]; then
    echo -e "${RED}$COIN_NAME is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $COIN_NAME-$USER.service"
    echo -e "systemctl status $COIN_NAME-$USER.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}


function create_config() {
  cd ~/
  mkdir .fdreserve >/dev/null 2>&1
  sleep 2
  cd .fdreserve
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
  cat << EOF > fdreserve.conf
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
listen=1
server=1
daemon=0
txindex=1
rpcport=$RPC_PORT
port=$COIN_PORT
EOF
cd ~/
}

function create_key() {
  echo -e "Enter your ${RED}$COIN_NAME Masternode Private Key${NC}.\nLeave it blank to generate a new ${RED}$COIN_NAME Masternode Private Key${NC} for you:"
  read -e COINKEY
  echo -e "Enter your ${RED}$COIN_NAME TX_OUTPUT${NC}.\nLeave it blank if you want to put it manualy"
  read -e TX_OUTPUT
  echo -e "Enter your ${RED}$COIN_NAME TX_INDEX${NC}.\nLeave it blank if you want to put it manualy"
  read -e TX_INDEX
  sleep 2
  if [[ -z "$COINKEY" ]]; then
	$COIN_DAEMON -daemon
      sleep 30
    COINKEY=$($COIN_CLI -conf=/home/$USER/.fdreserve/fdreserve.conf -datadir=/home/$USER/.fdreserve masternode genkey)
    if [ "$?" -gt "0" ];
      then
      echo -e "${RED}Wallet not fully loaded. Let us wait for 30s and try again to generate the Private Key${NC}"
      sleep 30
      COINKEY=$($COIN_CLI -conf=/home/$USER/.fdreserve/fdreserve.conf -datadir=/home/$USER/.fdreserve masternode genkey)
      if [ "$?" -gt "0" ];
      then
        echo -e "${RED}Wallet not fully loaded. Let us wait for another 30s and try again to generate the Private Key${NC}"
        sleep 30
        COINKEY=$($COIN_CLI -conf=/home/$USER/.fdreserve/fdreserve.conf -datadir=/home/$USER/.fdreserve masternode genkey)
      fi
    fi
  $COIN_CLI stop
fi
clear
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' /home/$USER/.fdreserve/fdreserve.conf
  cat << EOF >> /home/$USER/.fdreserve/fdreserve.conf
logintimestamps=1
maxconnections=256
#bind=
staking=0
masternode=1
externalip=[$NODEIP]
masternodeaddr=[$NODEIP]:12474
masternodeprivkey=$COINKEY

# Seed Nodes
addnode=161.97.167.197
addnode=161.97.167.201
addnode=144.91.95.43
addnode=144.91.95.44
addnode=167.86.119.223
addnode=164.68.96.160
addnode=167.86.124.134
addnode=[2a02:c207:2027:2245::1]
addnode=[2a02:c207:2027:5644::1]
addnode=[2a02:c207:2027:9123::1]
addnode=[2a02:c207:2051:9094::1]
addnode=[2a02:c207:2051:9093::1]
addnode=[2a02:c206:2051:9083::1]
addnode=[2a02:c206:2051:9077::1]

#User : $USER
# $USER [$NODEIP]:12474 $COINKEY  $TX_OUTPUT $TX_INDEX
EOF
sleep 1
  cd /home/$USER/.fdreserve
  killall fdreserved
  rm -rf blocks chainstate peers.dat
  sleep 1
  echo -e "Downloading BootStrap"
  wget --progress=bar:force $BOOTSTRAP_TGZ 2>&1 | progressfilt
  unzip snapshot.zip
  sleep 2
  rm -f snapshot.zip
  cd ~
  sleep 2
}

function enable_firewall() {
  echo -e "Installing and setting up firewall to allow ingress on port ${GREEN} $COIN_PORT ${NC}"
  sudo ufw allow ssh >/dev/null 2>&1
  sudo ufw allow $COIN_PORT >/dev/null 2>&1
  sudo ufw default allow outgoing >/dev/null 2>&1
  echo "y" | sudo ufw enable >/dev/null 2>&1
  sudo ufw reload
}

function get_ip() {
  declare -a NODE_IPS
  for ips in $(curl --interface $ips --connect-timeout 2 hostname --all-ip-addresses || hostname -i)
  do
    NODE_IPS+=($(/sbin/ip -o addr show scope global | awk '{gsub(/\/.*/,"",$4); print $4}'))
    #NODE_IPS+=($(curl --interface $ips --connect-timeout 2 -s4 icanhazip.com && curl --interface $ips --connect-timeout 2 -6 icanhazip.com))
  done
clear
  if [ ${#NODE_IPS[@]} -gt 1 ]
    then
	echo -e "${YELLOW}"
      echo -e "${GREEN}More than one IP. Please type 0 to use the first IP, 1 for the second and so on...${NC}"
      INDEX=0
      for ip in "${NODE_IPS[@]}"
      do
        echo ${INDEX} $ip
        let INDEX=${INDEX}+1
      done
      read -e choose_ip
      NODEIP=${NODE_IPS[$choose_ip]}
  else
    NODEIP=${NODE_IPS[0]}
  fi
}


function detect_ubuntu() {
 if [[ $(lsb_release -sr) > 20 ]]; then
   UBUNTU_VERSION=20
 elif [[ $(lsb_release -sr) > 18 ]]; then
   UBUNTU_VERSION=18
 elif [[ $(lsb_release -sr) > 16 ]]; then
   UBUNTU_VERSION=16
 elif [[ $(lsb_release -sr) == 14.04 ]]; then
   UBUNTU_VERSION=14
else
   echo -e "${RED}You are not running Ubuntu 14.04, 16.04, 18.04 or 20.04 Installation is cancelled.${NC}"
   exit 1
fi
}

function create_swap() {
 echo -e "Checking if swap space is needed."
 PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
 SWAP=$(swapon -s)
 if [[ "$PHYMEM" -lt "2"  &&  -z "$SWAP" ]]
  then
    echo -e "${GREEN}Server is running with less than 2G of RAM without SWAP, creating 6G swap file.${NC}"
    SWAPFILE=$(mktemp)
    sudo dd if=/dev/zero of=$SWAPFILE bs=1024 count=6M
    sudo chmod 600 $SWAPFILE
    sudo mkswap $SWAPFILE
    sudo swapon -a $SWAPFILE
 else
  echo -e "${GREEN}The server running with at least 2G of RAM, or a SWAP file is already in place.${NC}"
 fi
 clear
}


function important_information() {
 echo
 echo -e "================================================================================"
 echo -e "$COIN_NAME Masternode is up and running listening on port ${RED}$COIN_PORT${NC}."
 echo -e "Configuration file is: ${RED}$CONFIGFOLDER/$CONFIG_FILE${NC}"
 if (( $UBUNTU_VERSION == 16 || $UBUNTU_VERSION == 18 )); then
   echo -e "Start: ${RED}systemctl start $COIN_NAME-$USER.service${NC}"
   echo -e "Stop: ${RED}systemctl stop $COIN_NAME-$USER.service${NC}"
   echo -e "Status: ${RED}systemctl status $COIN_NAME-$USER.service${NC}"
 else
   echo -e "Start: ${RED}/etc/init.d/$COIN_NAME_$USER start${NC}"
   echo -e "Stop: ${RED}/etc/init.d/$COIN_NAME_$USER stop${NC}"
   echo -e "Status: ${RED}/etc/init.d/$COIN_NAME_$USER status${NC}"
 fi
 echo -e "VPS_IP:PORT ${RED}[$NODEIP]:12474${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$COINKEY${NC}"
 echo -e "Check if $COIN_NAME is running by using the following command:\n${RED}ps -ef | grep $COIN_DAEMON | grep -v grep${NC}"
  echo -e "copy to your masternode.conf wallet: ${RED}Your_Alias [$NODEIP]:12474 $COINKEY $TX_OUTPUT $TX_INDEX ${NC}"
 echo -e "================================================================================"
 echo -e "Lunching ${RED}FDReserve Masternode${NC}, it may take some time due to the${RED} $TIMER Sec Start Delay.${NC}"
}

function nbr_nodes() {
 NBR_DAEMON=$(ps -C fdreserved -o pid= | wc -l)
 figlet -f slant "FDReserve"
 echo -e "${RED}How many running $COIN_NAME nodes on this server ? $NBR_DAEMON ? ${NC}"
 read -e NBR_NODES
 COIN_PORT=$(expr 12476 + $NBR_NODES '*' 2)
 RPC_PORT=$(expr $COIN_PORT + 1)
 TIMER=$(($NBR_NODES * 30))
}

function prepare_system_for_download() {
echo -e "Prepare the system to install ${GREEN}$COIN_NAME${NC} master node."
sudo apt-get update >/dev/null 2>&1
#echo -e "Upgrading System, it may take some time.${NC}"
#sudo apt-get upgrade -y >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
sudo apt-get install -y curl systemd figlet >/dev/null 2>&1
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt install -y curl sytemd figlet"
 exit 1
fi

clear
}

function setup_node() {
  nbr_nodes
  get_ip
  create_config
  create_key
  update_config
  enable_firewall
  important_information
  if (( $UBUNTU_VERSION == 16 || $UBUNTU_VERSION == 20 )); then
    configure_systemd
  else
    configure_startup
  fi
}


##### Main #####
clear
cd ~/
detect_ubuntu
create_swap
prepare_system_for_download
setup_node
cd ~/
rm -f fdr-multi-install.sh

# If you want to support me
# fdr wallet : 
# fYWa6E3gthATUF2rThr7TtBaVGa1dm7vR8
