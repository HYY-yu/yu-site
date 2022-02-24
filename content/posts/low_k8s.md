---
title: "如何低成本的搭建一个真实的Kubernetes集群"
date: 2022-02-24T22:18:39+08:00
draft: false
---
> 引言：kubernetes作为当前事实上的容器编排标准，其势头可谓是如日中天，然而，kubernetes一直以来被人诟病的就是其复杂的搭建成本，作为个人，除了用miniKube等工具在个人电脑上模拟一个集群，或者通过虚拟机模拟一个集群，但终归，真实集群和虚拟集群是不同的。我一直在想，如今云服务器已经十分成熟，难道就不能作为搭建kubernetes平台的基础设施吗？

## 一、架构规划

其实对于现在的云服务来说，各家竞争激烈，价格也打得比较低，但是存在一个问题：为了吸引新用户，云服务厂商一般都对产品首单、新用户首次下单时进行特别大的折扣，入坑后才发现，续费或者购买新服务器动辄上千元💰！实在不是我等普通程序员愿意支出的一笔消费😭。好在我了解到，各云厂商现在在主推一种新的云服务器（可以称之为云服务器的阉割版），比如腾讯云叫“轻量应用服务器”，阿里云肯定也有对应的产品。这种阉割过的服务器，价格实惠，正适合购买来做个人集群。   
那么假如我们是新用户（新用户其实很简单，以前注册过的，换个手机号注册就是了，反正一个身份证一般都能绑多个账号，各个云厂商都差不多政策的。），我们以首单优惠买个阉割版服务器，再通过首单优惠买个云服务器，有两个服务器不就能搭一个真正的Kubernetes集群吗？😏
为了方便选择，我也做了一个价格表，目前阿里云、腾讯云都在搞活动，正是入手的好时机：

| 云厂商 | 轻量服务器最低配置 | 云服务器最低配置 | 活动链接|
| --- | --- | --- | --- |
| 腾讯云 | 2核2G 200/3年 | 2核2G 298/3年 |[ 点击查看](https://curl.qcloud.com/UvDbS6a0) | 
| 阿里云 | 2核2G 99/年 | 1核2G 261/3年 | [点击查看](https://www.aliyun.com/daily-act/ecs/activity_selection?userCode=vgb3ncpv)
| 华为云 | - | 1核2G 158 /1年 （新用户可买3台）| [点击查看](https://activity.huaweicloud.com/discount_area_v5/index.html)

以上这个表格应该对比的很清晰了，都是各厂商活动页首推的配置，应该是最便宜的了。个人感觉华为云最不实惠，不推荐。
腾讯云别看总价是498，[点击这个连接](https://curl.qcloud.com/laygSFzY)领取新人优惠券，我算下来，差不多373元拿下两个云服务器，3年呐，！简直是买不了吃亏，买不了上当，感觉厂商都要亏本！       
贴上我以前做活动时买的，都是1核2G的配置，轻量买了1年（我那时候怕轻量和云服务器不可以在kubernetes集群中互联互通），云服务器买了3年，都要269元，这样一算，2核2G两个3年才373，我简直血亏😭。

![image.png](https://img-blog.csdnimg.cn/img_convert/4d0c0826cef0c3002958d7c8685a9cc0.png)

回归主题！当我们以低成本拿到两个服务器后，就可以规划准备搭建集群了，这里我先放个架构图：

![截屏2022-02-24 下午7.19.17.png](https://img-blog.csdnimg.cn/img_convert/12d2282c03c253a85ba2976eade6f356.png)

假设 Node1 是我们买的CVM云服务器， Light Node1 是我们买的轻量应用服务器，它们位于不同的网段，我们需要做好网络规划，让两个网段能互联互通即可。

## 搭建步骤

#### 1. 各服务器上安装docker、kubelet kubectl kubeadm

要搭建kubernetes集群，首先集群中的每个节点都需要安装好以上这些软件，docker怎么安装网络上教程一大把，我这里就不多介绍了，只是要注意修改`/etc/docker/daemon.json`的配置：

```json
{
    "registry-mirrors": [
        "https://mirror.ccs.tencentyun.com"
    ],
    "bip": "10.47.0.1/16",
    "exec-opts": ["native.cgroupdriver=systemd"]
}
```
这里我修改了docker的网段地址，把cgroupdriver改成了systemd（kubernetes要求）。修改docker网段地址是因为：我们要保证节点网络、docker内部网络、kubernetes网络地址CIDR段不要冲突，冲突不好搞的，在规划时就要区别开。这里你要根据你的节点的实际网络地址，配置一个网段，不要从我的示例json中直接复制。

这里给出kubelet kubectl kubeadm的安装方法：
```
 cat <<EOF > /etc/yum.repos.d/kubernetes.repo
 [kubernetes]
 name=Kubernetes
 baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
 enabled=1
 gpgcheck=1
 repo_gpgcheck=1
 gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
 EOF
 setenforce 0
 yum install -y kubelet-1.22.0 kubeadm-1.22.0 kubectl-1.22.0
```
yum安装好了以后，`systemctl enable kubelet && systemctl start kubelet`命令设置成开机启动即可。   
同时，我们把两个云服务器的hostname设置成`k8s-master`、`k8s-node1`。

#### 2. 保证CVM和轻量应用服务器可以互联互通

[参考腾讯云文档](https://cloud.tencent.com/document/product/1207/56847)   
配置完成后，CVM和轻量应用服务器应该就可以相互ping通。

#### 3. 使用 kubeadm 安装集群的master节点

```
kubeadm init \ 
--apiserver-advertise-address=172.17.0.3 \
--image-repository registry.aliyuncs.com/google_containers \ 
--kubernetes-version v1.22.0 \ 
--service-cidr=10.96.0.0/12 \ 
--pod-network-cidr=10.244.0.0/16 \
--ignore-preflight-errors=all
```
这里要感谢阿里云，他们提供的国内镜像地址，可以让我们快速的下载下来kubernetes所需要的镜像。
可以看到，此命令中需要提供kubernetes的service网段和pod网段，也需要注意不要冲突。

#### 4. 安装node节点

安装node节点就非常简单了，当master节点成功安装完毕，命令应该会打印出如何安装node节点的示例，复制下来，在k8s-node1上运行就行了。

#### 5. 开启防火墙的端口

最后，我们需要在云服务器和轻量应用服务器的防火墙中，配置端口联通规则：   
在k8s-master上放行：TCP:6443,10250,10251,10252   
在k8s-node1 上放行：TCP: 10250

#### 6. 其它工作

最后可能需要配置Flannel、移除master节点的污点等。这里就不再过多介绍，以后有时间，可以再写些博客详细分享一下。目前，我也是学习者的状态。

## 三、参考资料

- [K8s安装](https://www.cnblogs.com/takako_mu/p/15380607.html)  
- [腾讯云购买地址](https://curl.qcloud.com/UvDbS6a0)
- [技术交流群](https://github.com/HYY-yu/seckill.shop/tree/master)