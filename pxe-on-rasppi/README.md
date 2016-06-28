# PXE in the Office

I am trying to setup and run a PXE server, which can boot and
auto-install CoreOS on other machines connected to a home-use router.

I happen to have a 32-bit Raspberry Pi with ARMv7l CPU and Raspbian
Linux 8.  I try to make it the PXE server.

## Network Topology

I have a LinkSys router.  I plug its upstream cable to the Ethernet
slot on the wall of the office.  As shown in the following figure, I
plugged three downstream cables to

1. a MacBook Pro from which I ssh to other nodes.
1. a Raspberry Pi used as the PXE server, and
1. a Lenovo Thinkpad X240 running Ubuntu.

The Raspberry Pi is supposed to be the PXE server.  I want it able to
boot and auto-install CoreOS on the Thinkpad.

After booting all these computers, they got IP addresses from the router:

1. MacBook Pro: 192.168.2.10
1. Raspberry Pi: 192.168.2.11
1. Thinkpad: 192.168.2.12
1. SysLink router: 192.168.2.1

I can configure the router via a Web UI at `http://192.168.2.1`, where
`192.168.2.1` is the static IP of the router.  This Web UI allows me
to disable/enable the DHCP service on the router.  At this moment, I
keep it as "enabled".  The default IP address allocation range is from
`192.168.2.10` to `192.168.2.249`.

On this Web UI, I can see that the subnet mask is `255.255.255.0`.

I can ssh to the Thinkpad and the Raspberry Pi from the MacBook Pro.
On both of these Linux comptuers, I confirmed that `route -n` returns
the gateway IP address as `192.168.2.1`, which is the router's IP
address.

On all these computers, I did `curl www.gooogle.com` and verified that
I can access the Internet.


## Install the DHCP Server

A PXE server is a DHCP server that returns not only the IP address,
but also URL of boot images that will be used to boot the target
computer.

I learned about DHCP server on Ubuntu from
[this tutorial](http://www.noveldevices.co.uk/rp-dhcp-server).  To
install a DHCP server:

```
sudo apt-get install isc-dhcp-server
```

### DHCP Server's Static IP

A PXE server needs a static IP address, so that target computers know
from where to download the OS images.  To do this, I edited
`/etc/network/interfaces` to assign `eth0` a static IP address
`192.168.2.10`.

```
auto eth0
iface eth0 inet static
address 192.168.2.10
netmask 255.255.255.0
gateway 192.168.2.1
dns-nameservers 8.8.4.4 8.8.8.8
```

### DHCP Configuration

Then I rewrote `/etc/dhcp/dhcpd.conf` to make the DHCP server
allocating IP addresses in the range from `192.168.2.11` to
`192.168.2.249`.  Please be aware that I reserve `192.168.2.10` for
the DHCP (PXE) server itself.

```
subnet 192.168.2.0 netmask 255.255.255.0 {
	range 192.168.2.11 192.168.2.249;
	option routers 192.168.2.1;
	option broadcast-address 192.168.2.255;
	option domain-name-servers 8.8.8.8;
}

next-server 192.168.2.10;
filename "pxelinux.0";
```

Also, please be aware that `next-server` and `filename` together
indicates the boot image path as `tftp://192.168.2.10/pxelinux.0`.  We
will talk about this TFTP service later.

Please refer to
[DHCP Configuration Error Checking](#dhcp-configuration-error-checking)
for a pitfall I encountered here.

Now we can restart the server to make the configuration happen:

```
sudo service isc-dhcp-server restart
```

### Switch DHCP Service

I now disabl the DHCP service on the router via its Web UI.  Then I
restarted the Thinkpad.  After it reboots, it got new IP address
`192.168.2.13`.  It seems that the Raspberry Pi DHCP server works.

I can ssh to Thinkpad using its new IP address.

Then I restarted the Raspberry Pi.  It boots into a status that the
DHCP server runs OK and it can resovle and access `www.google.com`.

Then I restarted the Mac Mini again.  It got `192.168.2.15`, an IP
address in the specified range.


## TFTP Server

I followed
[this tutorial for Ubuntu](http://vinobkaranath.blogspot.com/2014/06/install-tftp-server-in-ubuntu-1404.html)
and installed tftpd-hpa.  A difference is that I use the default TFTP
serving path `/srv/tftp`.

To test the TFTP server, I installed a client: `sudo apt-get install
tftp-hpa`, then run

```
echo Hello > /srv/tftp/hello
tftp 192.168.2.11 -c  get hello
cat ./hello
Hello
```

It is noticable that the server is listening on `192.168.2.11`, but
not on `127.0.0.1` (`localhost`).


### Deploy PXELINUX

The boot image aforementioned in DHCP configuraton file was retrieved
from the pxelinux package:

```
sudo apt-get install pxelinux syslinux-common
cp /usr/lib/PXELINUX/pxelinux.0 /srv/tftp/
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 /srv/tftp/
```

Then I checked that the Thinkpad can get `pxelinux.0` and
`ldlinux.c32` from the TFTP server running on the Raspberry Pi:

```
ssh yi@192.168.2.16
> tftp 192.168.2.10 -c get pxelinux.0
> tftp 192.168.2.10 -c get ldlinux.c32
```

### Deploy CoreOS Images

On the Raspberry Pi,

```
cd /srv/tftp
CHANNEL=stable
VERSION=1010.5.0
wget https://${CHANNEL}.release.core-os.net/amd64-usr/${VERSION}/coreos_production_pxe.vmlinuz
wget https://${CHANNEL}.release.core-os.net/amd64-usr/${VERSION}/coreos_production_pxe_image.cpio.gz
```

We can also verify the downloaded image files:

```
wget https://${CHANNEL}.release.core-os.net/amd64-usr/${VERSION}/coreos_production_pxe.vmlinuz.sig
wget https://${CHANNEL}.release.core-os.net/amd64-usr/${VERSION}/coreos_production_pxe_image.cpio.gz.sig
gpg --verify coreos_production_pxe.vmlinuz.sig
gpg --verify coreos_production_pxe_image.cpio.gz.sig
```

## Configure PXELINUX to Boot CoreOS

The idea that we need pxelinux.0 is that, when a target computer
boots, it broadcasts a request for IP address.  The DHCP server
responses an IP address and `next-server` and `filename`.  If the
network card and BIOS of the target computer supports PXE, it would
download the boot image from URL `tftp://192.168.1.105/pxelinux.0` and
keep this URL as *current working directory*.  When it runs
`pxelinux.0`, it lets it knows the current working directory, so that
`pxelinux.0` can load its configuration file from there.

Suppose that the MAC address of the network card on the target
computer is `28-d2-44-fb-19-49`, then `pxelinux.0` will read
configuration file
`tftp://192.168.1.105/pxelinux.cfg/01-88-99-aa-bb-cc-dd`.  If that
file doesn't exists, it tries to read
`tftp://192.168.1.105/pxelinux.cfg/default`.

The content of our `/var/lib/tftpboot/pxelinux.cfg/default` is as
follows:

```
default coreos

label coreos
  kernel coreos_production_pxe.vmlinuz
  append initrd=coreos_production_pxe_image.cpio.gz cloud-config-url=http://192.168.1.105:8080/cloud-config/install-coreos
```

This configuration file tells `pxelinux.0` to download CoreOS images
`coreos_production_pxe.vmlinuz` and
`coreos_production_pxe_image.cpio.gz` form its current working
directory.  Then `pxelinux.0` will boot the system using the CoreOS
images.


### Cloud-Config and HTTP Server

Above pxelinux configuration file requires the cloud-config file at
`http://192.168.2.10:8080/cloud-config/install-coreos`.  To make
192.168.2.10, the Raspberry Pi PXE server to serve that, we install
Nginx:

```
sudo apt-get update
sudo apt-get install nginx
```




## Pitfalls

### DHCP Configuration Error Checking

When I start the DHCP server as follows, it complains and error:

```
pi@raspberrypi:/etc/dhcp $ sudo service isc-dhcp-server restart
Job for isc-dhcp-server.service failed. See 'systemctl status isc-dhcp-server.service' and 'journalctl -xn' for details.
```

But `systemctl status isc-dhcp-server.service` and `journalctl -xn` shows nothing interesting.

So I had a look at the file `/etc/init.d/isc-dhcp-server`, which is a
Shell script and invokes `/usr/sbin/dhcpd`.  This inspired me to run
`/usr/sbin/dhcpd` from the command line, which shows the reason -- I
got syntax errors in the configuration file:

```
pi@raspberrypi:/etc/dhcp $ /usr/sbin/dhcpd
Internet Systems Consortium DHCP Server 4.3.1
Copyright 2004-2014 Internet Systems Consortium.
All rights reserved.
For info, please visit https://www.isc.org/software/dhcp/
Config file: /etc/dhcp/dhcpd.conf
Database file: /var/lib/dhcp/dhcpd.leases
PID file: /var/run/dhcpd.pid
unable to create icmp socket: Operation not permitted
/etc/dhcp/dhcpd.conf line 8: semicolon expected.
filename 
 ^
/etc/dhcp/dhcpd.conf line 8: expecting a declaration

^
Configuration file errors encountered -- exiting
```

I simply added the missing semicolons, then `sudo service
isc-dhcp-server start` works and `systemctl status
isc-dhcp-server.service` shows that the service is running well.

### DNS Server Configuration

When I switched to use the DHCP service on the Raspberry Pi from using
that on the router, `curl www.google.com` on the Thinkpad failed:

```
yi@pxe:~$ curl www.google.com
curl: (6) Could not resolve host: www.google.com
```

A brute force solution is to edit `/etc/resolv.conf` on the Thinkpad
and add a line `nameserver 8.8.8.8`.  For CoreOS target computers, the
same brute force solution can be done by adding lines into the
cloud-config file:

```
write_files:
  - path: "/etc/resolv.conf"
    permissions: "0644"
    owner: "root"
    content: |
       nameserver 8.8.8.8
```	

But an elegant solution is to add a line to the `/etc/dhcp/dhcpd.conf`
on the Raspberry Pi:

```
option domain-name-servers 8.8.8.8;
```

Then we can restart the DHCP server

```
sudo service isc-dhcp-server restart
```

and on the Thinkpad, we release the old lease and renew it:

```
sudo dhclient -r
sudo dhclient
```

Or, of couse, we can restart the Thinkpad.  Now `curl www.google.com`
should work on the Thinkpad.

