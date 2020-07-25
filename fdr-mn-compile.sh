#!/bin/bash

CONFIG_FILE='fdreserve.conf'
CONFIGFOLDER='/root/.fdreserve'
COIN_PATH='/usr/local/bin/'
#64 bit only
COIN_TGZ='https://github.com/fdreserve/fdr-blockchain/releases/download/v2.1.3/fdr-v2.1.3-linux64.tar.gz'
COIN_REPO='https://github.com/fdreserve/fdr-blockchain/archive/v2.1.3.tar.gz'
BOOTSTRAP_TGZ='http://bootstraps.louloucrypto.fr/fdr/bootstrap.tar.gz'
COIN_PATHPART='fdr-v2.1.3-linux/bin'
COIN_DAEMON="fdreserved"
COIN_CLI="fdreserve-cli"
COIN_NAME='FDReserve'
COIN_PORT=12474

NODEIP=$(curl -s4 icanhazip.com)

RED='\033[0;31m'
GREEN='\033[0;32m'
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

function compile_node() {
  cd ~ >/dev/null
  echo -e "${GREEN}Prepare to download $COIN_NAME${NC}"
  TMP_FOLDER=$(mktemp -d)
  cd $TMP_FOLDER
  echo -e "${GREEN}Cloning Git${NC}"
  git clone https://github.com/fdreserve/fdr-blockchain.git >/dev/null 2>&1
  cd fdr-blockchain
  echo -e " ${RED}Compiling, it take times. Depending of your cpu.${NC}"
  ./autogen.sh >/dev/null 2>&1
  ./configure >/dev/null 2>&1
  make
  cd src
  strip $COIN_DAEMON $COIN_CLI
  chmod +x $COIN_DAEMON $COIN_CLI
  cp -p $COIN_DAEMON $COIN_CLI $COIN_PATH
  cd ~ >/dev/null
  rm -rf $TMP_FOLDER >/dev/null 2>&1
  clear
}

function configure_systemd() {
  cat << EOF > /etc/systemd/system/$COIN_NAME.service
[Unit]
Description=$COIN_NAME service
After=network.target
[Service]
User=root
Group=root
Type=forking
#PIDFile=$CONFIGFOLDER/$COIN_NAME.pid
ExecStart=$COIN_PATH/$COIN_DAEMON -daemon -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER
ExecStop=-$COIN_PATH/$COIN_CLI -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER stop
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $COIN_NAME.service
  systemctl enable $COIN_NAME.service >/dev/null 2>&1

  if [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON)" ]]; then
    echo -e "${RED}$COIN_NAME is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $COIN_NAME.service"
    echo -e "systemctl status $COIN_NAME.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}

function configure_startup() {
  cat << EOF > /etc/init.d/$COIN_NAME
#! /bin/bash
### BEGIN INIT INFO
# Provides: $COIN_NAME
# Required-Start: $remote_fs $syslog
# Required-Stop: $remote_fs $syslog
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: $COIN_NAME
# Description: This file starts and stops $COIN_NAME MN server
#
### END INIT INFO
case "\$1" in
 start)
   $COIN_PATH/$COIN_DAEMON -daemon -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER
   sleep 5
   ;;
 stop)
   $COIN_PATH/$COIN_CLI -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER stop
   ;;
 restart)
   $COIN_CLI stop
   sleep 10
   $COIN_PATH/$COIN_DAEMON -daemon -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER
   ;;
 *)
   echo "Usage: $COIN_NAME {start|stop|restart}" >&2
   exit 3
   ;;
esac
EOF
chmod +x /etc/init.d/$COIN_NAME >/dev/null 2>&1
update-rc.d $COIN_NAME defaults >/dev/null 2>&1
/etc/init.d/$COIN_NAME start >/dev/null 2>&1
if [ "$?" -gt "0" ]; then
 sleep 5
 /etc/init.d/$COIN_NAME start >/dev/null 2>&1
fi
}


function create_config() {
  mkdir $CONFIGFOLDER >/dev/null 2>&1
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
  cat << EOF > $CONFIGFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
port=$COIN_PORT
EOF
}

function create_key() {
  echo -e "Enter your ${RED}$COIN_NAME Masternode Private Key${NC}.\nLeave it blank to generate a new ${RED}$COIN_NAME Masternode Private Key${NC} for you:"
  read -e COINKEY
  if [[ -z "$COINKEY" ]]; then
    $COIN_PATH/$COIN_DAEMON -daemon
    sleep 30
    if [ -z "$(ps axo cmd:100 | grep $COIN_DAEMON)" ]; then
      echo -e "${RED}$COIN_NAME server couldn't not start. Check /var/log/syslog for errors.{$NC}"
      exit 1
    fi
    COINKEY=$($COIN_PATH/$COIN_CLI masternode genkey)
    if [ "$?" -gt "0" ];
      then
      echo -e "${RED}Wallet not fully loaded. Let us wait for 30s and try again to generate the Private Key${NC}"
      sleep 30
      COINKEY=$($COIN_PATH/$COIN_CLI masternode genkey)
      if [ "$?" -gt "0" ];
      then
        echo -e "${RED}Wallet not fully loaded. Let us wait for another 30s and try again to generate the Private Key${NC}"
        sleep 30
        COINKEY=$($COIN_PATH/$COIN_CLI masternode genkey)
      fi
    fi
  $COIN_PATH/$COIN_CLI stop
fi
clear
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $CONFIGFOLDER/$CONFIG_FILE
  cat << EOF >> $CONFIGFOLDER/$CONFIG_FILE
logintimestamps=1
maxconnections=256
#bind=$NODEIP
staking=0
masternode=1
externalip=$NODEIP
masternodeaddr=$NODEIP:$COIN_PORT
masternodeprivkey=$COINKEY
addnode=62.171.143.119:12474 addnode=167.86.118.254:12474 addnode=178.238.237.227:12474 addnode=167.86.108.205:12474 addnode=151.80.43.136:12474 addnode=164.68.100.82:12474 addnode=173.212.211.190:12474 addnode=164.68.96.160:12474 addnode=64.190.204.86:12474 addnode=140.82.54.45:12474 addnode=46.101.223.184:12474 addnode=45.76.47.186:12474 addnode=34.68.199.28:12474 addnode=213.136.77.196:12474 addnode=167.86.75.126:12474 addnode=66.42.114.60:12474 addnode=116.202.165.186:12474 addnode=173.212.206.240:12474 addnode=5.189.144.152:12474 addnode=5.189.186.172:12474 addnode=164.68.115.138:12474 addnode=159.69.251.157:12474 addnode=207.180.203.39:12474 addnode=167.86.114.163:12474 addnode=173.212.192.3:12474 addnode=104.156.252.20:12474 addnode=155.138.237.49:12474 addnode=176.166.187.200:12474
EOF
  cd $CONFIGFOLDER
  rm -rf blocks chainstate peers.dat
  sleep 1
  echo -e "Downloading BootStrap"
  wget --progress=bar:force $BOOTSTRAP_TGZ 2>&1 | progressfilt
  echo -e "Extracting BootStrap"
  tar zxvf bootstrap.tar.gz >/dev/null 2>&1
  rm -f bootstrap.tar.gz
  sleep 2
}

function enable_firewall() {
  echo -e "Installing and setting up firewall to allow ingress on port ${GREEN}$COIN_PORT${NC}"
  ufw allow ssh >/dev/null 2>&1
  ufw allow $COIN_PORT >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
}

function get_ip() {
  declare -a NODE_IPS
  for ips in $(netstat -i | awk '!/Kernel|Iface|lo/ {print $1," "}')
  do
    NODE_IPS+=($(curl --interface $ips --connect-timeout 2 -s4 icanhazip.com))
  done

  if [ ${#NODE_IPS[@]} -gt 1 ]
    then
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

function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $COIN_NAME. Please investigate.${NC}"
  exit 1
fi
}

function detect_ubuntu() {
 if [[ $(lsb_release -d) == *18.04* ]]; then
   UBUNTU_VERSION=18
 elif [[ $(lsb_release -d) == *16.04* ]]; then
   UBUNTU_VERSION=16
 elif [[ $(lsb_release -d) == *14.04* ]]; then
   UBUNTU_VERSION=14
else
   echo -e "${RED}You are not running Ubuntu 14.04, 16.04 or 18.04 Installation is cancelled.${NC}"
   exit 1
fi
}

function checks() {
 detect_ubuntu
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi
}

function prepare_system_for_compile() {
figlet -f slant "FDReserve"
echo -e "Prepare the system to install ${GREEN}$COIN_NAME${NC} master node."
apt-get update >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1
echo -e "${GREEN}Adding bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update >/dev/null 2>&1
apt-get install -y make software-properties-common \
build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget curl libdb4.8-dev bsdmainutils libdb4.8++-dev \
libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev systemd figlet\
libzmq3-dev >/dev/null 2>&1
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git curl libdb4.8-dev \
bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev sytemd figlet"
 exit 1
fi

clear
}

function create_swap() {
 echo -e "Checking if swap space is needed."
 PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
 SWAP=$(swapon -s)
 if [[ "$PHYMEM" -lt "2"  &&  -z "$SWAP" ]]
  then
    echo -e "${GREEN}Server is running with less than 2G of RAM without SWAP, creating 2G swap file.${NC}"
    SWAPFILE=$(mktemp)
    dd if=/dev/zero of=$SWAPFILE bs=1024 count=2M
    chmod 600 $SWAPFILE
    mkswap $SWAPFILE
    swapon -a $SWAPFILE
 else
  echo -e "${GREEN}The server running with at least 2G of RAM, or a SWAP file is already in place.${NC}"
 fi
 clear
}


function important_information() {
figlet -f slant "FDReserve"
 echo
 echo -e "================================================================================"
 echo -e "$COIN_NAME Masternode is up and running listening on port ${RED}$COIN_PORT${NC}."
 echo -e "Configuration file is: ${RED}$CONFIGFOLDER/$CONFIG_FILE${NC}"
 if (( $UBUNTU_VERSION == 16 || $UBUNTU_VERSION == 18 )); then
   echo -e "Start: ${RED}systemctl start $COIN_NAME.service${NC}"
   echo -e "Stop: ${RED}systemctl stop $COIN_NAME.service${NC}"
   echo -e "Status: ${RED}systemctl status $COIN_NAME.service${NC}"
 else
   echo -e "Start: ${RED}/etc/init.d/$COIN_NAME start${NC}"
   echo -e "Stop: ${RED}/etc/init.d/$COIN_NAME stop${NC}"
   echo -e "Status: ${RED}/etc/init.d/$COIN_NAME status${NC}"
 fi
 echo -e "VPS_IP:PORT ${RED}$NODEIP:$COIN_PORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$COINKEY${NC}"
 echo -e "Check if $COIN_NAME is running by using the following command:\n${RED}ps -ef | grep $COIN_DAEMON | grep -v grep${NC}"
 echo -e "================================================================================"
}

function setup_node() {
  get_ip
  create_config
  create_key
  update_config
  enable_firewall
  important_information
  if (( $UBUNTU_VERSION == 16 || $UBUNTU_VERSION == 18 )); then
    configure_systemd
  else
    configure_startup
  fi
}


##### Main #####
clear

checks
prepare_system_for_compile
compile_node
create_swap
setup_node