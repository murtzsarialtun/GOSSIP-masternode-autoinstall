# GOSSIP
Shell script to install a [GOSSIP Masternode](https://gossipcoin.net/) on a Linux server running Ubuntu 16.04. Use it on your own risk.

This script install the GOSSIP cold wallet on your VPS, update Ubuntu, creates a service for the wallet and configures the firewall.

Prepare your Windows wallet:

- Put to your masternode.conf: MN01 VPS_IP:22123 masternodegenkey masternodeoutputs

## Installation
```
wget https://github.com/g0ssipcoin/GOSSIP-masternode-autoinstall/raw/master/gossip-autoinstall.sh && bash gossip-autoinstall.sh
```
## Usage control script:

```
./gos-control.sh -[argument]

-a start GOSSIP service
-b stop GOSSIP service
-c status GOSSIP service
-d checks the autostart of the GOSSIP service when the server is starting
-e masternode sync status
-f masternode status
-g checks the blockcount
-h help - usage for this script
-k firewall status
-l show gossipcoin.conf
-m show firewall log
```

## Multi Masternode Installation
```
wget https://raw.githubusercontent.com/murtzsarialtun/GOSSIP-masternode-autoinstall/master/gossip-autoinstall.sh && bash gossip-autoinstall.sh
```
## Multi Masternode control

:TODO

