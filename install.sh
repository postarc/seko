#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE='seko.conf'
COIN_DAEMON='sekod'
CONFIGFOLDER='.seko'
COIN_CLI='seko-cli'
COIN_TGZ='https://github.com/sekopaycoin/sekopay/releases/download/v2.3.0/SekoPay-v2.3.0-LINUX.zip'
COIN_ZIP='SekoPay-v2.3.0-LINUX.zip'
COIN_NAME='seko'
COIN_PORT=4786
RPC_PORT=5786
PORT=4786
TRYCOUNT=7
WAITP=10
if [[ "$USER" == "root" ]]; then
        HOMEFOLDER="/root"
 else
        HOMEFOLDER="/home/$USER"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'



while [ -n "$(sudo lsof -i -s TCP:LISTEN -P -n | grep $RPC_PORT)" ]
do
(( RPC_PORT--))
done
echo -e "${GREEN}Free RPCPORT address:$RPC_PORT${NC}"
while [ -n "$(sudo lsof -i -s TCP:LISTEN -P -n | grep $PORT)" ]
do
(( PORT--))
done
echo -e "${GREEN}Free MN port address:$PORT${NC}"

function download_node() {
if [ ! -f "/usr/local/bin/ifpd" ]; then
  echo -e "Download $COIN_NAME"
  cd
  wget -q $COIN_TGZ
  unzip $COIN_ZIP
  rm $COIN_ZIP
  chmod +x $COIN_DAEMON $COIN_CLI
  sudo chown -R root:users /usr/local/bin/
  sudo bash -c "cp $COIN_CLI /usr/local/bin/"
  sudo bash -c "cp $COIN_DAEMON /usr/local/bin/"
  rm $COIN_CLI
  rm $COIN_DAEMON
  #clear
else
  echo -e "${GREEN}Bin files exist. Skipping copy...${NC}"
fi
}


function create_config() {
  mkdir $CONFIGFOLDER >/dev/null 2>&1
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
  cat << EOF > $CONFIGFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcport=$RPC_PORT
rpcallowip=127.0.0.1
listen=0
server=1
daemon=1
EOF
}

function create_key() {
echo "Input masternode key or ENTER:"
read -e COINKEY
 if [[ -z "$COINKEY" ]]; then
   /usr/local/bin/$COIN_DAEMON -reindex
   sleep $WAITP
    if [ -z "$(ps axo cmd:100 | grep $COIN_DAEMON)" ]; then
     echo -e "${RED}$COIN_NAME server couldn not start.${NC}"
     exit 1
    fi
  COINKEY=$($COIN_CLI masternode genkey)
  ERROR=$?
  while [ "$ERROR" -gt "0" ] && [ "$TRYCOUNT" -gt "0" ]
  do
  sleep $WAITP
  COINKEY=$($COIN_CLI masternode genkey)
  ERROR=$?
    if [ "$ERROR" -gt "0" ];  then
      echo -e "${GREEN}Wallet not fully loaded. Let us wait and try again to generate the Private Key${NC}"
      
    fi
  TRYCOUNT=$[TRYCOUNT-1]
  done
 /usr/local/bin/$COIN_CLI stop
 fi
#clear
}

function update_config() {
  cat << EOF >> $CONFIGFOLDER/$CONFIG_FILE

masternode=1
externalip=$NODEIP
bind=$NODEIP
masternodeaddr=$NODEIP:$COIN_PORT
port=$PORT
masternodeprivkey=$COINKEY

addnode=159.69.38.232:4786
addnode=159.69.44.115:4786
addnode=159.69.38.218:4786
addnode=116.203.106.199:4786
EOF
}



function get_ip() {
NODEIP=$(curl -s4 icanhazip.com)
}


function checks() {
if [[ $(lsb_release -d) != *16.04* ]]; then
  echo -e "${GREEN}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
  exit 1
fi

if [[ $EUID -eq 0 ]]; then
   echo -e "${GREEN}$0 must be run without sudo.${NC}"
   exit 1
fi

if [ ! -n "ps -u $USER | grep $COIN_DAEMON" ] && [ -d "$HOMEFOLDER/$CONFIGFOLDER" ] ; then
  echo -e "${GREEN}$COIN_NAME is already installed.${NC}"
  exit 1
fi
}


function prepare_system() {
echo -e "Installing ${GREEN}$COIN_NAME${NC} Masternode."
sudo apt-get update >/dev/null 2>&1
#sudo apt install virtualenv python 
#clear
}


function important_information() {
 echo
 echo -e "=====================Infinipay====================="
 echo -e "$COIN_NAME Masternode is up and running listening on port ${GREEN}$COIN_PORT${NC}."
 echo -e "Configuration file is: ${GREEN}$CONFIGFOLDER/$CONFIG_FILE${NC}"
 echo -e "VPS_IP:PORT ${GREEN}$NODEIP:$COIN_PORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${GREEN}$COINKEY${NC}"
 echo -e "=====================Infinipay====================="
 echo -e "Start node: sekod -daemon"
 echo -e "Stop node: seko-cli stop"
 echo -e "Block sync status: seko-cli getinfo"
 echo -e "Node sync status: seko-cli mnsync status"
 echo -e "Masternode status: seko-cli masternode status"
}

function setup_node() {
  get_ip
  create_config
  create_key
  update_config
  important_information  
}


##### Main #####
#clear
checks
prepare_system
download_node
setup_node
rm -rf seko
if [ -n "$(ps -u $USER | grep $COIN_DAEMON)" ]; then
	pID=$(ps -u $USER | grep $COIN_DAEMON | awk '{print $1}')
	kill -9 ${pID}
 fi
sleep 1
$COIN_DAEMON -reindex 
