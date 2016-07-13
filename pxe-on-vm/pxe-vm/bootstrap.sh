#!/usr/bin/env bash

echo "Hello! Here we are going to configure this VM a PXE server for
booting CoreOS.  This bootstraping script comes from
https://github.com/k8sp/bare-metal-coreos/tree/master/pxe-on-rasppi"

apt-get update

## DHCP Server
apt-get install -y isc-dhcp-server

# Note that we don't edit /etc/network/interfaces as documented in
# https://github.com/k8sp/bare-metal-coreos/tree/master/pxe-on-rasppi,
# because in our Vagrantfile, we have
#
#   config.vm.network "public_network", ip: "192.168.2.10"
#
# which sets the static IP 192.168.2.10 on the bridged NIC.

cat > /etc/dhcp/dhcpd.conf <<EOF
subnet 192.168.2.0 netmask 255.255.255.0 {
    range 192.168.2.11 192.168.2.249;
    option routers 192.168.2.1;
    option broadcast-address 192.168.2.255;
    option domain-name-servers 8.8.8.8;
}

next-server 192.168.2.10;
filename "pxelinux.0";
EOF

service isc-dhcp-server restart

