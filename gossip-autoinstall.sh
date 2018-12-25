#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE='gossipcoin.conf'
CONFIGFOLDER='/root/.gossipcoin'
COIN_DAEMON='gossipcoind'
COIN_CLI='gossipcoin-cli'
COIN_PATH='/usr/local/bin/'
COIN_TGZ='https://github.com/g0ssipcoin/GossipCoinCore/releases/download/v1.1.0.0/Linux-gossipcoin.zip'
COIN_ZIP=$(echo $COIN_TGZ | awk -F'/' '{print $NF}')
COIN_NAME='GOSSIP'
COIN_PORT=22123
RPC_PORT=22122

NODEIP=$(curl -s4 icanhazip.com)

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function delete_old_installation() {
  echo -e "${GREEN}Searching and removing old $COIN_NAME files and configurations${NC}"
  killall $COIN_DAEMON > /dev/null 2>&1
  ufw delete allow $COIN_PORT/tcp > /dev/null 2>&1
	rm -r .goss* > /dev/null 2>&1
	rm -r linux > /dev/null 2>&1 
	rm gos* > /dev/null 2>&1
  rm $COIN_CLI $COIN_DAEMON > /dev/null 2>&1
  if [ -d "~/.$COIN_NAME" ]; then
  sudo rm -rf ~/.$COIN_NAME > /dev/null 2>&1
  fi
  cd /usr/local/bin && sudo rm $COIN_CLI $COIN_DAEMON > /dev/null 2>&1 && cd
  echo -e "${GREEN}* Done${NONE}";
}

function download_node() {
  echo -e "Prepare to download ${GREEN}$COIN_NAME${NC}"
  cd /root >/dev/null 2>&1
  wget -q $COIN_TGZ && wget https://github.com/g0ssipcoin/GOSSIP-masternode-autoinstall/raw/master/gos-control.sh && chmod +x gos-control.sh
  unzip $COIN_ZIP >/dev/null 2>&1
  chmod +x $COIN_DAEMON
  chmod +x $COIN_CLI
  cp $COIN_DAEMON $COIN_PATH
  cp $COIN_CLI $COIN_PATH
  cd ~ >/dev/null 2>&1
  rm $COIN_ZIP >/dev/null 2>&1
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

ExecStart=$COIN_PATH$COIN_DAEMON -daemon -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER
ExecStop=-$COIN_PATH$COIN_CLI -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER stop

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
  sleep 4
  systemctl start $COIN_NAME.service
  systemctl enable $COIN_NAME.service >/dev/null 2>&1

  if [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON)" ]]; then
    echo -e "------------------------------------------------------------------------------------------------------------------------"
    echo -e "${RED}$COIN_NAME is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "systemctl start $COIN_NAME"
    echo -e "systemctl status $COIN_NAME"
    echo -e "less /var/log/syslog"
    echo -e "------------------------------------------------------------------------------------------------------------------------"
    exit 1
  fi
}

function create_config() {
  mkdir $CONFIGFOLDER >/dev/null 2>&1
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w15 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w25 | head -n1)
  cat << EOF > $CONFIGFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcport=$RPC_PORT
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
addnode=80.211.195.49:22123
addnode=80.211.42.218:22123
addnode=80.211.194.112:22123
addnode=80.211.50.155:22123
addnode=80.211.199.96:22123
addnode=80.211.138.174:22123
addnode=80.211.79.10:22123
port=$COIN_PORT
EOF
}

function create_key() {
  echo -e "Enter your ${RED}$COIN_NAME Masternode Private Key${NC} and press Enter:"
  read -e COINKEY
clear
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $CONFIGFOLDER/$CONFIG_FILE
  cat << EOF >> $CONFIGFOLDER/$CONFIG_FILE
logintimestamps=1
maxconnections=256
masternode=1
externalip=$NODEIP:$COIN_PORT
masternodeprivkey=$COINKEY
EOF
}

function enable_firewall() {
  echo -e "------------------------------------------------------------------"
  echo -e "${GREEN}Installing and setting up firewall${NC}"
  echo -e "------------------------------------------------------------------"
  ufw allow $COIN_PORT/tcp comment "$COIN_NAME MN port" >/dev/null
  ufw allow $RPC_PORT/tcp comment "$COIN_NAME MN RPC port" >/dev/null
  ufw allow ssh comment "SSH" >/dev/null 2>&1
  ufw limit ssh/tcp comment "Limit SSH" >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  ufw logging on >/dev/null 2>&1
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
      echo -e "-----------------------------------------------------------------------------------------------"
      echo -e "${RED}More than one IP. Please type 0 to use the first IP, 1 for the second and so on...${NC}"
      INDEX=0
      for ip in "${NODE_IPS[@]}"
      do
        echo ${INDEX} $ip
      echo -e "-----------------------------------------------------------------------------------------------"  
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
  echo -e "------------------------------------------------------------------"
  echo -e "${RED}Failed to compile $COIN_NAME. Please investigate.${NC}"
  echo -e "------------------------------------------------------------------"
  exit 1
fi
}

function checks() {
 if [[ $(lsb_release -d) == *18.04* ]]; then
   UBUNTU_VERSION=18
 elif [[ $(lsb_release -d) == *16.04* ]]; then
   UBUNTU_VERSION=16
else
   echo -e "${RED}You are not running Ubuntu 16.04 or 18.04 Why? Installation is now cancelled.${NC}"
   exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo -e "------------------------------------------------------------------"
   echo -e "${RED}$0 must be run as root.${NC}"
   echo -e "------------------------------------------------------------------"
   exit 1
fi

if [ -n "$(pidof $COIN_DAEMON)" ] || [ -e "$COIN_DAEMOM" ] ; then
  echo -e "-----------------------------------------------------------------------------------"
  echo -e "${RED}$COIN_NAME masternode is already installed! Installation is cancelled.${NC}"
  echo -e "-----------------------------------------------------------------------------------"
  exit 1
fi
}

function prepare_system() {
echo -e "-----------------------------------------------------------------------"
echo -e "Prepare the system to install ${GREEN}$COIN_NAME${NC} master node"
echo -e "Loading updates for Ubuntu, installing tools..."
echo -e "Please be patient and wait a moment..."
echo -e "-----------------------------------------------------------------------"
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" sudo git wget curl ufw fail2ban nano unzip htop >/dev/null 2>&1
export LC_ALL="en_US.UTF-8" >/dev/null 2>&1
export LC_CTYPE="en_US.UTF-8" >/dev/null 2>&1
locale-gen --purge >/dev/null 2>&1
apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
if [ "$?" -gt "0" ];
  then
    echo -e "----------------------------------------------------------------------------------------------------------------------------------"
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt -y install sudo git wget curl ufw fail2ban nano unzip htop"
    wget https://github.com/GOSSIP-DEV/GOSSIP-masternode-autoinstall/raw/master/gossip-autoinstall.sh && bash gossip-autoinstall.sh
    echo -e "----------------------------------------------------------------------------------------------------------------------------------"
 exit 1
fi
clear
}

function important_information() {
 echo -e "================================================================================================================================"
 echo -e "${GREEN}$COIN_NAME Masternode is up and running${NC}."
 echo -e "Configuration file is: ${RED}$CONFIGFOLDER/$CONFIG_FILE${NC}"
 echo -e "Start manuell: systemctl start $COIN_NAME"
 echo -e "Stop manuell: systemctl stop $COIN_NAME"
 echo -e "VPS_IP:PORT $NODEIP:$COIN_PORT"
 echo -e "MASTERNODE PRIVATEKEY is: $COINKEY"
 echo -e "Please check ${RED}$COIN_NAME${NC} daemon is running with the following command: ${RED}systemctl status $COIN_NAME${NC}"
 echo -e "Use ${RED}./$COIN_CLI masternode status${NC} to check your Masternode status."
 echo -e "================================================================================================================================"
}

function setup_node() {
  get_ip
  create_config
  create_key
  update_config
  enable_firewall
  important_information
  configure_systemd
}

##### Main #####
clear
delete_old_installation
checks
prepare_system
download_node
setup_node
