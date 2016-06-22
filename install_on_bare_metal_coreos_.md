

## 1 脚本说明


本脚本实现了在bare-metal上对kubernetes的master和worker节点的自动安装。有3台bare-metal，IP和角色如下表：

|      IP      |   角色   |
| :----------: | :----: |
| 10.10.10.191 | master |
| 10.10.10.192 | worker |
| 10.10.10.193 |  etcd  |

通过本文实现在191上安装kubernetes的master节点，在192上安装kubernetes的worker节点。


## 2 安装步骤

### 2.1 在bare-metal上安装coreos

参考这里：<https://github.com/k8sp/bare-metal-coreos/blob/master/README.md>
​    
### 2.2 确保ETCD2, Flanneld这两个基础服务能正常运行

安装好coreos以后，我们需要启动两个关键服务etcd2和flanneld。这两个服务的配置方法很特殊，因为它们是操作系统级别的服务。在coreos中，所有操作系统级别的服务，如网络配置，用户账户以及systemd units，都需要通过coreos-cloudinit这个程序来进行配置。coreos-cloudinit可以让用户对coreos进行一些定制，用户只需要为其传入一个cloud-config文件就行。这个配置有两种方式：一种是在系统刚启动完成以后加载cloud-config文件来实现；另外一种方式是在系统运行过程中，动态调用cloud-config文件来实现。cloud-config文件是一个yaml格式的文件，一般情况下会以“ #cloud-config” 为第一行。关于这个文件更详细的格式说明，可以看这里：<https://coreos.com/os/docs/latest/cloud-config.html>。

一般情况下，coreos安装好后，在/home/core目录下会有一个yml文件，这个yml文件就是一个cloud-config文件。我们可以对其进行修改,暂且统一命名为：cloud-config.yml。修改要点如下：

#### 2.2.1 确保3台bare-metal拥有同样的discoveryURL。  

discorveryURL是全局唯一的，etcd官网已经给我们提供了一个服务，确保生成的URL绝对的唯一，我们可以先申请一个，具体操作如下：

    curl -w "\n" 'https://discovery.etcd.io/new?size=3'

注意，上面的**size=3**,这个3是根据我们要部署的etcd节点数确定的。上面的命令运行结果如下：

    https://discovery.etcd.io/ff98f990c68da6016fe5fe154b3405fb

修改cloud-config文件：

    $ sudo vim cloud-config.yml

把里面ETCD_DISCOVERY的值改为：

    Environment="ETCD_DISCOVERY=https://discovery.etcd.io/ff98f990c68da6016fe5fe154b3405fb"

然后验证这个cloud-init文件，输入下面的网址：

    https://coreos.com/validate/

在打开的网页中把user_data文件里面的内容粘贴到左侧的文本输入框里，点击Validate Cloud-Config按钮，可以预先检查该cloud-config文件是否合法。如果一切顺利，就把另外两台机器也做同样的修改。

### 2.2.2 检查cloud-config文件

一个完整的cloud-config文件如下所示：

    #cloud-config

    coreos:
        etcd2:  
            discovery: "https://discovery.etcd.io/ff98f990c68da6016fe5fe154b3405fb"
            # multi-region and multi-cloud deployments need to use $public_ipv4
            advertise-client-urls: "http://10.10.10.191:2379"
            initial-advertise-peer-urls: "http://10.10.10.191:2380"
            # listen on both the official ports and the legacy ports
            # legacy ports can be omitted if your application doesn't depend on them 
            listen-client-urls: "http://0.0.0.0:2379,http://0.0.0.0:4001"
            listen-peer-urls: "http://10.10.10.191:2380,http://10.10.10.191:7001"
        update: 
            reboot-strategy: "etcd-lock"
        units:  
            - name: "etcd2.service"
              command: "start" 
            - name: "fleet.service"
              command: "start" 
            - name: "docker.socket"
              command: "start" 
            - name: "flanneld.service"
              command: "start" 
    
    hostname: "coreos-191"
    
    ssh_authorized_keys:
        - "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAzAy8KEKxDMmjd55RMKLFs8bhNGHgC+pvjbC7BOp4gibozfZAr84nWsfZPs44h1jMq0pX2qzGOpzGEN9RH/ALFCe/OixWkh+INnVTIr8scZr6UXwK06T2MyT71wuiqhbUZMwQEAKrWsvt9CPhqyHD2Ueul0cG/0fHqOXS/fw7Ikg29rUwdzRuYnvw6izuyJdNox0/nd87OVvd0fE5xEz+xZ8aFwGyAZabo/KWgcMxk6WN0O1Q== xxxxx@Megatron"
        - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDXZ722k3K5gvfT6kirCHtZRmpEvnVnET3I3MY6V5zqStkPi+yDTtAJKrN+chPbpwQUZip1/vstGCO24bxCWj9DgaN4tn4k0piskZu5wmwK+1BWyL1oycijbdtQ== xxxx@renhe-ThinkPad-X240"
        - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDVwfLAgA8DICHp0//xfBTgfU34fVOtKpxgrkceC605HGQ6GIPiwZBDNtMZxTeyQ7+79sqA2VUR2I5nrhlxw/Wc80yTsjbRmcIbr3mUNCd3+cOqnOAsWEucZCHHcNYwUQ3wIOoyP0cBLKI4b25ucgtawxCmB7PJ1Cm7HhCZZP46APaLmZPmmHeoJKx31M0IERWYaZRvLe0Pl7Pp6DueOSJvvNwR5YbNe5aQ2pO3xiv3wCj6n66dlqAhpmmD vien.xx@localhost"
        - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCrYpsQVHBRUA/sZfxgK+9jZBGZfoulXXe0faPCGC0b3L6z/qYzJnNFf1d4gj6hQaGyHGvVlr6Kd/6y+0Eour51R2H+8FO+9Y7Baom+BUcj/0LZ45tzsblpA2JOiMJkpqtx17WPKIzc9q5OZKVcV+zh/O+JuKLW/bDIndGiQRVJBGa87ZkCf+fzO5ME4nl7MsG/YY+9J/UkwDbZQd3wFTRqmHncrSupNhu1R2DttP9eWSHQsJIaEXmqKv4p7p4byztix3A/2hBUILZa3iDwxlCZq7OBrQCc/xOI45VMR7 xxxxx@xxx-Ubuntu"
    
    users:
      - name: "ops"
        passwd: "$6$rounds=656000$fgFH.d8/o8iamB2U$maTs.wA6WnRe0Lg4vBd9E6PVI9lsENftY5i4bmBCTSiu14WYNsRMg5dgKWJAdvKESC1Y1YvN4F3vYVqugc8Np/"


关键是检查：
1. coreos:etcd2:discovery:这个值是否所有的机器都相同
2. units配置

        units:  
            - name: "etcd2.service"
              command: "start" 
            - name: "fleet.service"
              command: "start" 
            - name: "docker.socket"
              command: "start" 
            - name: "flanneld.service"
              command: "start"

上面的几个服务都要有。


### 2.2.3 让cloud-config文件生效

    sudo coreos-cloudinit --from-file cloud-init.yml

注意：一定要加**sudo**，这个命令能够让coreos按照cloud-config文件重新配置。在3台机器上重复以上操作。**在操作完成后，3台机器的ETCD2服务因为有相同的discovery url, 3个ETCD2服务会自动连在一起，并保持数据同步。**

### 2.3 检查etcd2和flanneld是否已经被正常启动了

#### 2.3.1 检查etcd2服务

1）运行如下命令查看服务etcd2的状态

    systemctl status etcd2

2）正常的结果

    ● etcd2.service - etcd2
       Loaded: loaded (/usr/lib64/systemd/system/etcd2.service; disabled; vendor preset: disabled)
      Drop-In: /run/systemd/system/etcd2.service.d
               └─20-cloudinit.conf
       Active: active (running) since Fri 2016-06-03 02:02:49 UTC; 17h ago
     Main PID: 1352 (etcd2)
       Memory: 83.3M
          CPU: 6min 22.068s
       CGroup: /system.slice/etcd2.service
               └─1352 /usr/bin/etcd2
    
    Jun 03 17:20:46 coreos-191 etcd2[1352]: compacted raft log at 145015
    Jun 03 17:20:49 coreos-191 etcd2[1352]: purged file /var/lib/etcd2/member/snap/0000000000000002-00000000000186aa.snap successfully
    Jun 03 18:20:18 coreos-191 etcd2[1352]: start to snapshot (applied: 160016, lastsnap: 150015)
    Jun 03 18:20:18 coreos-191 etcd2[1352]: saved snapshot at index 160016
    Jun 03 18:20:18 coreos-191 etcd2[1352]: compacted raft log at 155016
    Jun 03 18:20:19 coreos-191 etcd2[1352]: purged file /var/lib/etcd2/member/snap/0000000000000002-000000000001adbb.snap successfully
    Jun 03 19:19:51 coreos-191 etcd2[1352]: start to snapshot (applied: 170017, lastsnap: 160016)
    Jun 03 19:19:51 coreos-191 etcd2[1352]: saved snapshot at index 170017
    Jun 03 19:19:51 coreos-191 etcd2[1352]: compacted raft log at 165017
    Jun 03 19:20:19 coreos-191 etcd2[1352]: purged file /var/lib/etcd2/member/snap/0000000000000002-000000000001d4cc.snap successfully

当看到“active (running)” 时，说明etcd2服务已经启动起来了，如果多执行几次，下面的日志没有滚动变化，且没有异常信息，则可以确信etcd2服务正常。

当然，这里很容易出问题，可以使用journalctl这个工具来查问题。 常用的命令是： 

    journalctl -u etcd2 -f

或者
​     
    journalctl -t etcd2 -f

如果没发现明显的错误信息，则要看全局的日志信息，直接：

    journalctl -f

3） 常见错误

    member "xx.xx.xx.xx" has previously registered with discovery service token (https://discovery.etcd.io/xxxx)
    But etcd could not find vaild cluster configuration in the given data dir (/var/lib/etcd2).

这种问题是说，当前etcd节点没有办法找到leader了，形象点说，就是找不到组织(集群）了。对于这种问题，一般的解决办法就是对所有节点验证discoveryURL是否相同，如果不相同要确保相同；另外，如果discoveryURL比较陈旧了，官方论坛建议重新申请一个新的；然后配置好cloud-config.yml文件，然后用coreos-cloudinit程序更新配置。


#### 2.3.2 检查flanneld

1） 运行如下命令

    systemctl status flanneld

2） 运行结果如下：

    ● flanneld.service - Network fabric for containers
       Loaded: loaded (/usr/lib64/systemd/system/flanneld.service; disabled; vendor preset: disabled)
      Drop-In: /etc/systemd/system/flanneld.service.d
               └─40-ExecStartPre-symlink.conf.conf
       Active: active (running) since Fri 2016-06-03 02:09:35 UTC; 18h ago
         Docs: https://github.com/coreos/flannel
     Main PID: 1722 (sdnotify-proxy)
       Memory: 16.1M
          CPU: 10.143s
       CGroup: /system.slice/flanneld.service
               ├─1722 /usr/libexec/sdnotify-proxy /run/flannel/sd.sock /usr/bin/docker run --net=host --privileged=true --rm --volume=/run/flann...
               └─1729 /usr/bin/docker run --net=host --privileged=true --rm --volume=/run/flannel:/run/flannel --env=NOTIFY_SOCKET=/run/flannel/...
    
    Jun 03 02:09:35 coreos-191 sdnotify-proxy[1722]: I0603 02:09:35.053882 00001 etcd.go:204] Picking subnet in range 172.17.1.0 ... 172.17.255.0
    Jun 03 02:09:35 coreos-191 sdnotify-proxy[1722]: I0603 02:09:35.210063 00001 etcd.go:84] Subnet lease acquired: 172.17.60.0/24
    Jun 03 02:09:35 coreos-191 sdnotify-proxy[1722]: I0603 02:09:35.366702 00001 ipmasq.go:50] Adding iptables rule: FLANNEL -d 172.17.0.... ACCEPT
    Jun 03 02:09:35 coreos-191 sdnotify-proxy[1722]: I0603 02:09:35.368551 00001 ipmasq.go:50] Adding iptables rule: FLANNEL ! -d 224.0.0...QUERADE
    Jun 03 02:09:35 coreos-191 sdnotify-proxy[1722]: I0603 02:09:35.382176 00001 ipmasq.go:50] Adding iptables rule: POSTROUTING -s 172.1...FLANNEL
    Jun 03 02:09:35 coreos-191 sdnotify-proxy[1722]: I0603 02:09:35.384023 00001 ipmasq.go:50] Adding iptables rule: POSTROUTING ! -s 172...QUERADE
    Jun 03 02:09:35 coreos-191 sdnotify-proxy[1722]: I0603 02:09:35.385933 00001 udp.go:222] Watching for new subnet leases
    Jun 03 02:09:35 coreos-191 sdnotify-proxy[1722]: I0603 02:09:35.386973 00001 udp.go:247] Subnet added: 172.17.30.0/24
    Jun 03 02:09:35 coreos-191 sdnotify-proxy[1722]: I0603 02:09:35.387004 00001 udp.go:247] Subnet added: 172.17.85.0/24
    Jun 03 02:09:35 coreos-191 systemd[1]: Started Network fabric for containers.

如果出现“Active(Running)”，则说明这个服务正常。到这一步，如果成功，说明coreos的系统级服务也配置成功了。后面，工作重点就是对Master节点和Worker节点配置各自的服务了。这些可以用脚本自动实现，我们提供了这样的脚本。主要包含两个文件夹，master和worker。master文件夹里是master节点的自动安装脚本及相关配置文件，worker文件夹里是worker节点的自动安装脚本及相关配置文件。

### 2.4 配置Master节点

先把master文件夹拷贝到master节点(10.10.10.191)上的/home/core下，然后做一些小配置，再执行：

    **sudo** ./setup_k8s_master.sh 

就可以了。具体配置如下：

#### 2.4.1 配置environment文件

environment文件存储当前节点IP，脚本会读这个文件获得IP信息。我们需要在这里配置Master节点的IP，具体过程如下：

    vim environment

打开后如下：

    COREOS_PUBLIC_IPV4=10.10.10.191
    COREOS_PRIVATE_IPV4=10.10.10.191

将它们的值都改成Master节点的IP，然后保存。

#### 2.4.2 配置openssl.conf

这个文件是tls的安全配置有关系。打开以后是：

      1 [req]
      2 req_extensions = v3_req
      3 distinguished_name = req_distinguished_name
      4 [req_distinguished_name]
      5 [ v3_req ]
      6 basicConstraints = CA:FALSE
      7 keyUsage = nonRepudiation, digitalSignature, keyEncipherment
      8 subjectAltName = @alt_names
      9 [alt_names]
     10 DNS.1 = kubernetes
     11 DNS.2 = kubernetes.default
     12 DNS.3 = kubernetes.default.svc
     13 DNS.4 = kubernetes.default.svc.cluster.local
     14 IP.1 = 10.3.0.1
     15 IP.2 = 10.10.10.191

我们主要修改第15行，IP2=MasterNode的IP。

#### 2.4.3 运行配置脚本

    **sudo** ./setup_k8s_worker.sh

这个脚本实现了master节点的其余配置以及服务的启动。

#### 2.4.4 检查运行状态

运行下面的命令：

    systemctl status kubelet

返回结果如下：

    ● kubelet.service
       Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; vendor preset: disabled)
       Active: active (running) since Fri 2016-06-03 10:32:22 UTC; 10h ago
      Process: 2658 ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests (code=exited, status=0/SUCCESS)
      Process: 2655 ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests (code=exited, status=0/SUCCESS)
     Main PID: 2663 (kubelet)
       Memory: 840.5M
          CPU: 4min 44.749s
       CGroup: /system.slice/kubelet.service
               ├─2663 /kubelet --api-servers=http://127.0.0.1:8080 --network-plugin-dir=/etc/kubernetes/cni/net.d --network-plugin= --register-n...
               └─2791 journalctl -k -f

说明状态良好。


### 2.5 配置Worker节点

先把worker文件夹拷贝到worker节点(10.10.10.192)上的/home/core下，然后做一些小配置，再执行：

    **sudo** ./setup_k8s_worker.sh 

就可以了。具体配置如下：

#### 2.5.1 配置environment文件

environment文件存储当前节点IP，脚本会读这个文件获得IP信息。我们需要在这里配置Master节点的IP，具体过程如下：

    vim environment

打开后如下：

    COREOS_PUBLIC_IPV4=10.10.10.192
    COREOS_PRIVATE_IPV4=10.10.10.192

将它们的值都改成Worker节点的IP，然后保存。

#### 2.5.2 配置openssl.conf
跟3.2相同。

#### 2.5.3 运行配置脚本

    **sudo** ./setup_k8s_worker.sh

这个脚本实现了master节点的其余配置以及服务的启动。

#### 2.5.4 检查运行状态


运行下面的命令：

    systemctl status kubelet

返回结果如下：    

    ● kubelet.service
       Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; vendor preset: disabled)
       Active: active (running) since Fri 2016-06-03 16:41:08 UTC; 4h 26min ago
      Process: 25702 ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests (code=exited, status=0/SUCCESS)
     Main PID: 25705 (kubelet)
       Memory: 830.4M
          CPU: 2min 32.877s
       CGroup: /system.slice/kubelet.service
               ├─25705 /kubelet --api-servers=https://10.10.10.191 --network-plugin-dir=/etc/kubernetes/cni/net.d --network-plugin= --register-n...
               └─25827 journalctl -k -f


说明服务正常。 


#2.6 使用kubectl来观察

    待续...


## 3 参考

### 3.1 原理参考

本脚本编写过程中主要参考了coreos官网安装k8s的step by step 教程，地址如下：

1. https://coreos.com/kubernetes/docs/latest/openssl.html
2. https://coreos.com/kubernetes/docs/latest/getting-started.html
3. https://coreos.com/kubernetes/docs/latest/deploy-master.html
4. https://coreos.com/kubernetes/docs/latest/deploy-workers.html
5. https://coreos.com/kubernetes/docs/latest/configure-kubectl.html
6. https://coreos.com/kubernetes/docs/latest/deploy-addons.html

### 3.2 代码参考
本脚本代码主要基于：https://github.com/coreos/coreos-kubernetes 中的
https://github.com/coreos/coreos-kubernetes/blob/master/multi-node/generic/controller-install.sh


