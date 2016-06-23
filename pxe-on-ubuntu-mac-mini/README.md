# PXE at Home

I am trying to setup and run a PXE server, which can boot CoreOS on
other machines connected to my home router.

## Mac Mini PXE Server

I happen to have an old Mac Mini.  I decided to make it a PXE server.
A PXE server should run a DHCP server, which directs target machines
to the boot program at IP allocation time, and a TFTP server, which
serves the boot program and OS images.  To install and run these
programs, I re-installed Linux on my Mac Mini.

### Install Linux on Mac Mini

It is generally the usual way to install Linux:

1. Downloaded Ubuntu server ISO image and wrote it into a USB stick,
1. booted the Mac Mini using the USB stick and installed Ubuntu.

A few notes:

1. We need to press `C` when we boot the Mac from USB stick.
1. We need a Mac keyboard when we press `C`.

More details can be found
[here](https://nsrc.org/workshops/2014/nsrc-ubuntunet-trainers/raw-attachment/wiki/Agenda/install-ubuntu-mac-mini.htm).

### Install TFTP Server

I followed
[this tutorial](http://vinobkaranath.blogspot.com/2014/06/install-tftp-server-in-ubuntu-1404.html).
The only difference is that I use the default TFTP server path
`/var/lib/tftpboot`.

To test the TFTP server, I installed a client: `sudo apt-get install
tftp-hpa`, then run

```
echo Hello > hello
tftp localhost
> put hello
> ^D
cat /var/lib/tftpboot/hello
Hello
```

### Install DHCP Server

As suggested by
[this tutorial](https://help.ubuntu.com/community/isc-dhcp-server), I
installed DHCP server:

```
sudo apt-get install isc-dhcp-server
```

Add the following two lines to `/etc/dhcp/dhcpd.conf`, so to make the
DHCP response contains the TFTP server IP and the TFTP path to the
boot image:

```
next-server 192.168.1.105
filename "pxelinux.0"
```

where `192.168.1.105` is the IP address of the Mac Mini.

Restart the server:

```
sudo service isc-dhcp-server restart
```

### Boot Images

The boot image aforementioned in DHCP configuraton file was retrieved
from the pxelinux package:

```
sudo apt-get install pxelinux
sudo cp /usr/lib/PXELINUX/pxelinux.0 /var/lib/tftpboot/
```

When a target computer boots, it broadcasts a request for IP address.
The DHCP server responses an IP address and `next-server` and
`filename`.  If the network card and BIOS of the target computer
supports PXE, it would download the boot image from URL
`tftp://192.168.1.105/pxelinux.0` and keep this URL as *current
working directory*.  When it runs `pxelinux.0`, it lets it knows the
current working directory, so that `pxelinux.0` can load its
configuration file from there.

Suppose that the MAC address of the network card on the target
computer is `88-99-aa-bb-cc-dd`, then `pxelinux.0` will read
configuration file
`tftp://192.168.1.105/pxelinux.cfg/01-88-99-aa-bb-cc-dd`.  If that
file doesn't exists, it tries to read
`tftp://192.168.1.105/pxelinux.cfg/default`, or
`/var/lib/tftpboot/pxelinux.cfg/default`.

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
images.  To make this happen, we need to download CoreOS images:

```
CHANNEL=stable
VERSION=1010.5.0
cd /var/lib/tftpboot/
wget https://${CHANNEL}.release.core-os.net/amd64-usr/${VERSION}/coreos_production_pxe.vmlinuz
wget https://${CHANNEL}.release.core-os.net/amd64-usr/${VERSION}/coreos_production_pxe_image.cpio.gz
```

The pxelinux configuration file
`/var/lib/tftpboot/pxelinux.cfg/default` also specifies the
cloud-config file
`http://192.168.1.105:8080/cloud-config/install-coreos`, which will be
executed by CoreOS system after it boots.  We want this cloud-config
file installs CoreOS onto the disk of the target computer.

### Install CoreOS onto Disks

The above `http://` URL implies that we need to install Nginx (or any
other HTTP server) on the Mac Mini to host the cloud-config file.
