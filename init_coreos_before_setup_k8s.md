# 在bareos上安装k8s的初始化工作

## 1. 任务描述
在3台只安装了coreos的bare-metal上安装tkubernetes。这3台机器的IP地址如下：
- 10.10.10.191
- 10.10.10.192
- 10.10.10.193

## 2. 确保ETCD2, Flanneld这两个基础服务能正常运行

bare-metal上面安装完coreos以后,在/home/core下面会有一个**user__data**文件，这个文件实际上就是cloud-config文件，该文件内容如下：
    #cloud-config

    coreos:
        etcd2:
            discovery: "https://discovery.etcd.io/cb3514be263aa4f79260d70047f0a3ff"
            # multi-region and multi-cloud deployments need to use $public_ipv4
            advertise-client-urls: "http://10.10.10.192:2379"
            initial-advertise-peer-urls: "http://10.10.10.192:2380"
            # listen on both the official ports and the legacy ports
            # legacy ports can be omitted if your application doesn't depend on them
            listen-client-urls: "http://0.0.0.0:2379,http://0.0.0.0:4001"
            listen-peer-urls: "http://10.10.10.192:2380,http://10.10.10.192:7001"
        update:
            reboot-strategy: "etcd-lock"
        units:
            - name: "etcd2.service"
              command: "start"
            - name: "fleet.service"
              command: "start"
            - name: "docker.socket"
              command: "start"
    
    hostname: "coreos-192"
    
    ssh_authorized_keys:
        - "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAzAy8KEKxDMmjd55RMKLFs8bhNGHgC+pvjbC7BOp4gibozfZAr84nWsfZPs44h1jMq0pX2qzGOpzGEN9RH/ALFCe/OixWkh+INnVTIr8scZr6M+3NzN+chBVGvmIAebUfhXrrP7pUXwK06T2MyT7HaDumf
    
    users:
      - name: "ops"
        passwd: "$6$rounds=656000$fgFH.d8/o8iamB2U$maTs.wA6WnRe0Lg4vBd9E6PVI9lsENftY5i4bmBCTSiu14WYNsRMg5dgKWJAdvKESC1Y1YvN4F3vYVqugc8Np/"
        groups:
          - "sudo"



这个文件里面的**ETCD__DISCOVERY**的地址需要统一配置一下。

先访问：  
​    
    curl -w "\n" 'https://discovery.etcd.io/new?size=3'

注意，上面的**size=3**,这个3是根据我们要部署的etcd节点数确定的。上面的命令运行结果如下：

    https://discovery.etcd.io/ff98f990c68da6016fe5fe154b3405fb

修改cloud-config文件：

    $ sudo vim user_data

把里面ETCD_DISCOVERY的值改为：

    Environment="ETCD_DISCOVERY=https://discovery.etcd.io/ff98f990c68da6016fe5fe154b3405fb"

然后验证这个cloud-init文件(user_data)，输入下面的网址：

    https://coreos.com/validate/

在打开的网页中把user_data文件里面的内容粘贴到左侧的文本输入框里，点击Validate Cloud-Config按钮，可以预先检查该cloud-config文件是否合法。如果一切顺利，执行下面的命令：
​    
    sudo coreos-cloudinit --from-file user_data 

注意：一定要加**sudo**，这个命令能够让coreos按照cloud-config文件重新配置。

在3台机器上重复以上操作。**在操作完成后，3台机器的ETCD2服务因为有相同的discovery url, 3个ETCD2服务会自动连在一起，并保持数据同步。**

可以用systemctl检查etcd2和flanneld服务的状态。执行命令如下；

    systemctl status flanneld
    systemctl status etcd2

#### 2. 配置节点基本信息

对于节点10.10.10.191，进行如下操作

    $ vim /etc/environment

填入内容：

    COREOS_PUBLIC_IPV4=10.10.10.191
    COREOS_PRIVATE_IPV4=10.10.10.191

其他两个节点也进行同样的操作。  
完成上面的两步，实际上bare-metal的很多难点就解决了，后面可以用脚本实现自动化配置。