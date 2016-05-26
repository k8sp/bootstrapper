## 一 初始化

### 1. 从这里开始：  

<https://coreos.com/kubernetes/docs/latest/getting-started.html>

### 2. 记录变量初始值
    ETCD_ENDPOINTS     #1.按照 `http://ip:port`这样的格式写  2.其中ip是ETCD所在host的ip地址，port的默认值是2379  
    POD_NETWORK=10.2.0.0/16  
    SERVICE_IP_RANGE=10.3.0.0/24  
    K8S_SERVICE_IP=10.3.0.1  
    DNS_SERVICE_IP=10.3.0.10  
    
### 3. 在etc/systemd/system下创建服务配置文件
文件的目录结构如下


    │  kubelet.service               #kubelet服务文件
    │  kubelet.service.master         #在第二步搭建k8s的master节点的时候的kubelet的配置文件
    │  
    ├─docker.service.d               #docker服务配置
    │      40-flannel.conf           #定义了flannel服务在docker启动以后再开启
    │      
    ├─etcd2.service.d                #etcd服务配置
    │      40-listen-address.conf    #定义了ETCD服务的外部和内部访问地址
    │      
    ├─flanneld.service.d             #flanneld服务配置
    │      40-ExecStartPre-symlink.conf    #定义了flanneld服务启动前，做了一个软链接
    │      
    └─multi-user.target.wants
            docker.service
            etcd2.service
            flanneld.service
            kubelet.service
            
具体内容可以参考：     

<https://github.com/xiaohe1977/k8s-coreos-bare-metal>

### 4. 生成Kubernetes TLS Assets
TLS Assets主要用来进行安全验证，是kubectl执行时需要的重要参数信息。创建TLS Assets过程可以参考这里：   

<https://coreos.com/kubernetes/docs/latest/openssl.html>

我已经把这个过程封装成一些脚本，放到了这里:   

<https://github.com/xiaohe1977/k8s-coreos-bare-metal/tree/master/tls>  

创建好的这些文件可以先统一放到etc/kubernetes/ssl里面。
然后执行如下命令，设置好权限：
  
    $ sudo chmod 600 etc/kubernetes/ssl-key.pem  
    $ sudo chown root:root etc/kubernetes/ssl-key.pem


### 5. 各种配置

参考：<https://github.com/xiaoe1977/k8s-coreos-bare-metal/tree/master/etc>  来创建或修改以下配置文件：

- 配置网络  

        /etc/flannel/options.env
        /etc/systemd/system/flanneld.service.d/40-ExecStartPre-symlink.conf 

- 配置docker  
 
        /etc/systemd/system/docker.service.d/40-flannel.conf

- Create the kubelet Unit  
 
        /etc/systemd/system/kubelet.service

- Set Up the kube-apiserver Pod

        /etc/kubernetes/manifests/kube-apiserver.yaml

- Set Up the kube-proxy Pod  

        /etc/kubernetes/manifests/kube-proxy.yaml

- Set Up the kube-controller-manager Pod  

        /etc/kubernetes/manifests/kube-controller-manager.yaml

- Set Up the kube-scheduler Pod

        /etc/kubernetes/manifests/kube-scheduler.yaml

- Set Up the policy-agent Pod  

        /etc/kubernetes/manifests/policy-agent.yaml

**需要注意的是：上面的配置不包含与Calico相关的服务的配置。**


## 二 Deploy Master

### 6. 启动服务

    $ sudo systemctl daemon-reload  

用下面的命令配置flannel需要的pod网段以及ETCD服务器地址   
    
    $ curl -X PUT -d "value={\"Network\":\"$POD_NETWORK\",\"Backend\":{\"Type\":\"vxlan\"}}" "$ETCD_SERVER/v2/keys/coreos.com/network/config"

### 7. 启动Kubelet  
    
    $ sudo systemctl start kubelet
    $ sudo systemctl enable kubelet

### 8. 创建Namespace
    
    $ curl -H "Content-Type: application/json" -XPOST -d'{"apiVersion":"v1","kind":"Namespace","metadata":{"name":"calico-system"}}' "http://127.0.0.1:8080/api/v1/namespaces"

### 9. 现在kubelet服务应该已经创建好了，可以用下面的命令检查一下
    
    systemctl status kubelet.service  

另外，很有必要检查一下docker状态，用下面的命令：  
    
    docer ps                       


## 三 Deploy Worker Node(s)

### 10. 忽略官网向导以下步骤，但是必要时可以检查。
       
因为第5步的准备，以下操作被忽略:

    -  TLS Assets
    -  Networking Configuration
    -  Docker Configuration
    -  Create the kubelet Unit
    -  Set Up the kube-proxy Pod
    -  Set Up kubeconfig

如果要检查，可以参考这个官网向导：   

<https://coreos.com/kubernetes/docs/latest/deploy-workers.html>

### 11. 启动服务

    $ sudo systemctl daemon-reload
    
    $ sudo systemctl start flanneld
    $ sudo systemctl start kubelet
    $ sudo systemctl start calico-node
    
    $ sudo systemctl enable flanneld
    $ sudo systemctl enable kubelet
    $ sudo systemctl enable calico-node

### 12. 检查服务

    systemctl status kubelet.service

## 四 Setting up kubectl

这一步可以直接参考官网：

<https://coreos.com/kubernetes/docs/latest/configure-kubectl.html>

但是如果要节约时间，可以这样：   

### 13. 快速配置kubectl

直接国内下载kubectl：   

    curl -O https://github.com/xiaohe1977/k8s-coreos-bare-metal/blob/master/kubectl
   
直接下载并执行这个脚本：   

    curl -O https://github.com/xiaohe1977/k8s-coreos-bare-metal/blob/master/coreos_scripts/configure_cubectl.sh  
    bash configure_cubectl.sh
   
检查配置结果

    $ kubectl get nodes      
    
    NAME            STATUS      AGE  
    127.17.8.101    Ready       21h


## 五 Deploy the DNS Add-on


### 15. 配置dns.yml   
    
已经配置好，直接下载：
    
    curl -O https://github.com/xiaohe1977/k8s-coreos-bare-metal/blob/master/coreos_scripts/dns-addon.yml  

### 16. 启动DNS add-on

    $ kubectl create -f dns-addon.yml
    
执行完可以用如下命令来检查：   
    
    $ kubectl get pods --namespace=kube-system | grep kube-dns-v11
   
### 17. 显示所有节点状态，执行如下命令  

    kubectl get nodes
    kubectl get pods --namespace=kube-system | grep kube-dns-v11  
    kubectl describe services  
    systemctl status kubelet.service    
    
为了方便，这个已经封装成脚本：<https://github.com/xiaohe1977/k8s-coreos-bare-metal/blob/master/coreos_scripts/show.sh>



******************

    
## 附录1：踩过的坑


### 坑1. 启动KubeletService失败

#### 先启动kubelet

    core@core-01 ~ $ sudo systemctl start kubelet

#### 再查看kubelet状态

    core@core-01 ~ $ sudo systemctl status kubelet

结果如下：

	kubelet.service
	Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; vendor preset: disabled)
	Active: activating (auto-restart) (Result: exit-code) since Tue 2016-05-24 00:34:32 UTC; 936ms ago
	Process: 1146 ExecStart=/usr/lib/coreos/kubelet-wrapper --api-servers=http://127.0.0.1:8080 --network-plugin-dir= --network-plugin= --registe
	Process: 1140 ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests (code=exited, status=0/SUCCESS)
	Main PID: 1146 (code=exited, status=1/FAILURE)

	May 24 00:34:32 core-01 systemd[1]: kubelet.service: Main process exited, code=exited, status=1/FAILURE
	May 24 00:34:32 core-01 systemd[1]: kubelet.service: Unit entered failed state.
	May 24 00:34:32 core-01 systemd[1]: kubelet.service: Failed with result 'exit-code'.

#### 再查看Journal日志，发现bad http:// status code 404错误

    sudo journalctl -r -u kubelet.service

结果如下：

	May 24 00:36:51 core-01 systemd[1]: kubelet.service: Failed with result 'exit-code'.
	May 24 00:36:51 core-01 systemd[1]: kubelet.service: Unit entered failed state.
	May 24 00:36:51 core-01 systemd[1]: kubelet.service: Main process exited, code=exited, status=1/FAILURE
	May 24 00:36:51 core-01 kubelet-wrapper[1533]: run: bad HTTP status code: 404
	May 24 00:36:49 core-01 kubelet-wrapper[1533]: image: downloading signature from https://quay.io/c1/aci/quay.io/coreos/hyperkube/0.19.3/aci.asc
	May 24 00:36:49 core-01 kubelet-wrapper[1533]: image: keys already exist for prefix "quay.io/coreos/hyperkube", not fetching again
	May 24 00:36:49 core-01 kubelet-wrapper[1533]: image: remote fetching from URL "https://quay.io/c1/aci/quay.io/coreos/hyperkube/0.19.3/aci/linu
	May 24 00:36:47 core-01 kubelet-wrapper[1533]: image: searching for app image quay.io/coreos/hyperkube
	May 24 00:36:47 core-01 kubelet-wrapper[1533]: image: using image from file /usr/lib64/rkt/stage1-images/stage1-fly.aci
	May 24 00:36:47 core-01 systemd[1]: Started kubelet.service.
	May 24 00:36:47 core-01 systemd[1]: Starting kubelet.service...
	May 24 00:36:47 core-01 systemd[1]: Stopped kubelet.service.
	May 24 00:36:47 core-01 systemd[1]: kubelet.service: Service hold-off time over, scheduling restart.
	May 24 00:36:37 core-01 systemd[1]: kubelet.service: Failed with result 'exit-code'.
	May 24 00:36:37 core-01 systemd[1]: kubelet.service: Unit entered failed state.
	May 24 00:36:37 core-01 systemd[1]: kubelet.service: Main process exited, code=exited, status=1/FAILURE
	May 24 00:36:37 core-01 kubelet-wrapper[1491]: run: bad HTTP status code: 404
	May 24 00:36:35 core-01 kubelet-wrapper[1491]: image: downloading signature from https://quay.io/c1/aci/quay.io/coreos/hyperkube/0.19.3/aci.asc
	May 24 00:36:35 core-01 kubelet-wrapper[1491]: image: keys already exist for prefix "quay.io/coreos/hyperkube", not fetching again
	May 24 00:36:35 core-01 kubelet-wrapper[1491]: image: remote fetching from URL "https://quay.io/c1/aci/quay.io/coreos/hyperkube/0.19.3/aci/linu
	May 24 00:36:33 core-01 kubelet-wrapper[1491]: image: searching for app image quay.io/coreos/hyperkube
	May 24 00:36:33 core-01 kubelet-wrapper[1491]: image: using image from file /usr/lib64/rkt/stage1-images/stage1-fly.aci
	May 24 00:36:33 core-01 systemd[1]: Started kubelet.service.
	May 24 00:36:33 core-01 systemd[1]: Starting kubelet.service...
	May 24 00:36:33 core-01 systemd[1]: Stopped kubelet.service.
	May 24 00:36:33 core-01 systemd[1]: kubelet.service: Service hold-off time over, scheduling restart.
	May 24 00:36:23 core-01 systemd[1]: kubelet.service: Failed with result 'exit-code'.
	May 24 00:36:23 core-01 systemd[1]: kubelet.service: Unit entered failed state.

#### 解决办法

    sudo vim etc/systemd/system/kubelet.service

按下面这一行修改配置文件：
    
    Environment=KUBELET_VERSION=v1.2.4_coreos.1

********************

### 坑2. curl http://127.0.0.1/8080/version 访问失败

#### 错误提示：

    curl (7) Failed to connect to 127.0.0.1 port 8080 Connection refused

#### 查看Journal日志：
	
	$ journalctl -r -u kubelet.service

	-- Logs begin at Mon 2016-05-23 11:56:59 UTC, end at Tue 2016-05-24 02:16:18 UTC. --
	May 24 02:16:18 core-01 kubelet-wrapper[8402]: W0524 02:16:18.529148 8402 manager.go:408] Failed to update status for pod "_()": Get http://127.0.0.1:8080/api/v1/namespaces/kube-system/pods/kube-scheduler-172.17.8.101: dial tcp 127.0.0.1:8080: connection refused
	May 24 02:16:18 core-01 kubelet-wrapper[8402]: W0524 02:16:18.528742 8402 manager.go:408] Failed to update status for pod "_()": Get http://127.0.0.1:8080/api/v1/namespaces/kube-system/pods/kube-proxy-172.17.8.101: dial tcp 127.0.0.1:8080: connection refused
	May 24 02:16:18 core-01 kubelet-wrapper[8402]: W0524 02:16:18.528310 8402 manager.go:408] Failed to update status for pod "_()": Get http://127.0.0.1:8080/api/v1/namespaces/kube-system/pods/kube-controller-manager-172.17.8.101: dial tcp 127.0.0.1:8080: connection refused
	May 24 02:16:18 core-01 kubelet-wrapper[8402]: W0524 02:16:18.527707 8402 manager.go:408] Failed to update status for pod "_()": Get http://127.0.0.1:8080/api/v1/namespaces/kube-system/pods/kube-apiserver-172.17.8.101: dial tcp 127.0.0.1:8080: connection refused
	May 24 02:16:13 core-01 kubelet-wrapper[8402]: E0524 02:16:13.004607 8402 event.go:202] Unable to write event: 'Post http://127.0.0.1:8080/api/v1/namespaces/kube-system/events: dial tcp 127.0.0.1:8080: connection refused' (may retry after sleeping)
	May 24 02:16:10 core-01 kubelet-wrapper[8402]: E0524 02:16:10.529897 8402 pod_workers.go:138] Error syncing pod 00ae8a278467a8c378c5e1271ad42748, skipping: failed to "StartContainer" for "kube-apiserver" with CrashLoopBackOff: "Back-off 5m0s restarting failed container=kube-apiserver pod=kube-apiserver-172.17.8.101_kube-system(00ae8a278467a8c378c5e1271ad42748)"
	May 24 02:16:10 core-01 kubelet-wrapper[8402]: I0524 02:16:10.529652 8402 manager.go:2050] Back-off 5m0s restarting failed container=kube-apiserver pod=kube-apiserver-172.17.8.101_kube-system(00ae8a278467a8c378c5e1271ad42748)
	May 24 02:16:10 core-01 kubelet-wrapper[8402]: E0524 02:16:10.528207 8402 kubelet.go:1764] Failed creating a mirror pod for "kube-apiserver-172.17.8.101_kube-system(00ae8a278467a8c378c5e1271ad42748)": Post http://127.0.0.1:8080/api/v1/namespaces/kube-system/pods: dial tcp 127.0.0.1:8080: connection refused
	May 24 02:16:08 core-01 kubelet-wrapper[8402]: E0524 02:16:08.530450 8402 kubelet.go:1764] Failed creating a mirror pod for "kube-scheduler-172.17.8.101_kube-system(89bbc6210d1c82fd0ff8bc04a8d1fa17)": Post http://127.0.0.1:8080/api/v1/namespaces/kube-system/pods: dial tcp 127.0.0.1:8080: connection refused
	May 24 02:16:08 core-01 kubelet-wrapper[8402]: E0524 02:16:08.530170 8402 kubelet.go:1764] Failed creating a mirror pod for "kube-controller-manager-172.17.8.101_kube-system(83c8dad823686562797212f08ef55033)": Post http://127.0.0.1:8080/api/v1/namespaces/kube-system/pods: dial tcp 127.0.0.1:8080: connection refused
	May 24 02:16:08 core-01 kubelet-wrapper[8402]: W0524 02:16:08.529069 8402 manager.go:408] Failed to update status for pod "_()": Get http://127.0.0.1:8080/api/v1/namespaces/kube-system/pods/kube-scheduler-172.17.8.101: dial tcp 127.0.0.1:8080: connection refused
	May 24 02:16:08 core-01 kubelet-wrapper[8402]: W0524 02:16:08.528732 8402 manager.go:408] Failed to update status for pod "_()": Get http://127.0.0.1:8080/api/v1/namespaces/kube-system/pods/kube-proxy-172.17.8.101: dial tcp 127.0.0.1:8080: connection refused
	May 24 02:16:08 core-01 kubelet-wrapper[8402]: W0524 02:16:08.528279 8402 manager.go:408] Failed to update status for pod "_()": Get http://127.0.0.1:8080/api/v1/namespaces/kube-system/pods/kube-controller-manager-172.17.8.101: dial tcp 127.0.0.1:8080: connection refused
	May 24 02:16:08 core-01 kubelet-wrapper[8402]: W0524 02:16:08.527680 8402 manager.go:408] Failed to update status for pod "_()": Get http://127.0.0.1:8080/api/v1/namespaces/kube-system/pods/kube-apiserver-172.17.8.101: dial tcp 127.0.0.1:8080: connection refused
	May 24 02:16:03 core-01 kubelet-wrapper[8402]: E0524 02:16:03.003577 8402 event.go:202] Unable to write event: 'Post http://127.0.0.1:8080/api/v1/namespaces/kube-system/events: dial tcp 127.0.0.1:8080: connection refused' (may retry after sleeping)
	May 24 02:15:58 core-01 kubelet-wrapper[8402]: E0524 02:15:58.531227 8402 pod_workers.go:138] Error syncing pod 00ae8a278467a8c378c5e1271ad42748, skipping: failed to "StartContainer" for "kube-apiserver" with CrashLoopBackOff: "Back-off 5m0s restarting failed container=kube-apiserver pod=kube-apiserver-172.17.8.101_kube-system(00ae8a278467a8c378c5e1271ad42748)"
	May 24 02:15:58 core-01 kubelet-wrapper[8402]: I0524 02:15:58.531019 8402 manager.go:2050] Back-off 5m0s restarting failed container=kube-apiserver pod=kube-apiserver-172.17.8.101_kube-system(00ae8a278467a8c378c5e1271ad42748)


#### 解决办法：
1）修改flannel配置项目，ENDPOINTS加`http://`

    FLANNELD_ETCD_ENDPOINTS=http://172.17.8.101:2379
    
**关键是这一步。**

2）先启动flannel（官方文档没有强调这个，把相关组件也同步启动一下）  

    sudo systemctl daemon-reload
    sudo systemctl start flanneld
    sudo systemctl enable flanneld
    sudo systemctl restart docker
    sudo systemctl enable docker

3）确认kube-apiserver.yaml配置，etcd服务器要加http

    vim kube-apiserver.yaml
    etcd-servers=http://172.17.8.101:2379

4）重启kubelet  

    sudo systemctl restart kubelet

5）查看错误日志

    $ journalctl -r -u kubelet.service > kubeleg.log
    $ vim kubeleg.log
    
 当出现 namespaces kube-system not found 就好办了，可以确定之前的问题已经解决，现在主要是namespace没有创建，可以按照官网向导继续向下走了。


6) 访问: <http://127.0.0.18080/version>

成功！返回结果如下：  
        
	$ curl "http://127.0.0.1:8080/version"
	{
	"major": "1",
	"minor": "2",
	"gitVersion": "v1.2.3+coreos.0",
	"gitCommit": "c2d31de51299c6239d8b061e63cec4cb4a42480b",
	"gitTreeState": "clean"
	}

