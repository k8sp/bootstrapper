本文档记录了一种在机群里安装 CoreOS 的方法。分两步，第一步使用 iPXE 引导在内存中运行 CoreOS，第二步将 CoreOS 安装到硬盘。

# 使用 iPXE 引导 CoreOS

* 我实验的子网内没有 DHCP 服务，所以我自建了 DHCP 和 TFTP 服务，根据 [iPXE 的文档](http://ipxe.org/howto/chainloading) 通过 PXE 来 chainload iPXE。
* 使用了 [coreos-ipxe-server](https://github.com/kelseyhightower/coreos-ipxe-server) 这个工具来引导安装 CoreOS 到内存。这个工具的方便在于：
  * 自动生成 iPXE boot script，通过自带的 HTTP 服务提供。
  * 可以为每台主机分别提供不同的 cloud-config 文件，每个文件可以以主机的 MAC 地址为文件名，引导时通过 iPXE 提供的主机 MAC 地址自动选择，从而可以批量安装系统，并且为每台主机应用不同的配置。
  * 一个 tip：iPXE 的变量 ${net0/mac} 替换为网卡 MAC 时是小写，如果 coreos-ipxe-server 的配置文件名用的是大写（如[这个视频](https://www.youtube.com/watch?v=dRG2ajUaBqs)中演示的），会找不到文件。

# 将 CoreOS 安装到硬盘

国内从 CoreOS 官方下载系统很慢，所以我找了一台内网服务器提供做了镜像，通过查看 coreos-install 的输出，发现只需要下载两个文件，即 image 和它的 .sig 文件。下面是做这个下载镜像源的步骤。

这个过程我只做了一次，下边的 bash script 是根据过程补做的，所以可能还有错。


```bash
#!/bin/bash

CHANNEL=stable
VER=899.17.0
MIRROR_DIR=/work/local/lipeng/coreos-mirror

mkdir -p ${MIRROR_DIR}/${VER}
(
  cd ${MIRROR_DIR}/${VER}
  [ -f ${VER}/coreos_production_image.bin.bz2 ] || \ 
    wget http://${CHANNEL}.release.core-os.net/amd64-usr/${VER}/coreos_production_image.bin.bz2 && \ 
    wget http://${CHANNEL}.release.core-os.net/amd64-usr/${VER}/coreos_production_image.bin.bz2.sig
)

# 启动一个 nginx docker 来提供 image 下载，启动前先设置好 `pwd`/config/nginx.conf，并创建目录 logs 用于记录 nginx 的日志（可能没必要）。
sudo docker run -it --rm -p 8080:80 -v ${MIRROR_DIR}:/www:ro -v `pwd`/config:/etc/nginx:ro -v `pwd`/logs:/var/log/nginx nginx
```
最后，回到刚才装在内存中的 CoreOS server，用以下命令安装系统到硬盘。这里通过 -c 指定的 cloud-config 文件是将 coreos-ipxe-server 中的配置文件下载到了本地，因为我发现 -c 参数不支持 http 的 URL。-b 指定的是系统下载镜像地址。
```bash
sudo coreos-install -d /dev/sda -c 00\:25\:90\:c0\:f7\:86.yml -b http://10.10.10.1:8080
```

