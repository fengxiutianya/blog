---
title: 深入理解TCP的TIME-WAIT
tags:
  - tcp
categories:
  - 网络
abbrlink: dcf09bf2
date: 2019-03-10 08:23:00
---
---
# 深入理解TCP的TIME-WAIT

## 什么是 Time Wait 状态？

`time wait` 是 tcp connection 的状态之一，进入这个状态的原因只有一种：主动关闭 connection （active close）。

与其相对的是 `close wait` 状态，进入该状态是由于被动关闭 connection（passive close），也就是说接收到了对方的 `FIN` 信号（并且发出了自己的 `ACK` 信号）。
<!-- more -->

## 为什么Time Wait 要等待2MSL

我在TCP协议中提到 `TIME-WAIT` 状态，超时时间占用了 2MSL ，在 Linux 上固定是 60s 。之所以这么长时间，是因为两个方面的原因。

1. 一个数据报在发送途中或者响应过程中有可能成为残余的数据报，因此必须等待足够长的时间避免新的连接会收到先前连接的残余数据报，而造成状态错误。

   ![upload successful](/images/pasted-202.png)

   由于 TIME-WAIT 超时时间过短，旧连接的 `SEQ=3` 由于 **路上太眷顾路边的风景，姗姗来迟** ，混入新连接中，加之 SEQ 回绕正好能够匹配上，被当做正常数据接收，造成数据混乱。

2. 确保被动关闭方已经正常关闭。

   ![upload successful](/images/pasted-203.png)

   如果主动关闭方提前关闭，被动关闭方还在 LAST-ACK 苦苦等待 FIN 的 ACK 。此时对于主动关闭方来说，连接已经得到释放，其端口可以被重用了，如果重用端口建立三次握手，发出友好的 SYN ，谁知 **热脸贴冷屁股**，被动关闭方得不到想要的 ACK ，给出 RST 。所以等待2MSL可以使得主动方发出的ACK确认到达被动关闭的一方，并且如果中间有丢失，被动关闭方还可以在这个时间内进行重发，这就不具体讨论了。

## TIME-WAIT危害

主动关闭方进入 TIME-WAIT 状态后，无论对方是否收到 ACK ，都需要苦苦等待 60s 。这期间完全是 **占着茅坑不拉屎** ，不仅占用内存（系统维护连接耗用的内存），耗用CPU，更为重要的是，宝贵的端口被占用，端口枯竭后，新连接的建立就成了问题。之所以端口 **宝贵** ，是因为在 IPv4 中，一个端口占用2个字节，端口最高65535。

#### 解决

TCP协议推出了一个扩展 [RFC 1323 TCP Extensions for High Performance](http://tools.ietf.org/html/rfc1323) ，在 TCP Header 中可以添加2个4字节的时间戳字段，第一个是发送方的时间戳，第二个是接受方的时间戳。

基于这个扩展，Linux 上可以通过开启 `net.ipv4.tcp_tw_reuse` 和 `net.ipv4.tcp_tw_recycle` 来减少 TIME-WAIT 的时间，复用端口，减缓端口资源的紧张。

如果对于是 **client （连接发起主动方）主动关闭连接** 的情况，开启 `net.ipv4.tcp_tw_reuse` 就很合适。通过两个方面来达到 **reuse** TIME-WAIT 连接的情况下，依然避免本文开头的两个情况。

1. 防止残余报文混入新连接。得益于时间戳的存在，残余的TCP报文由于时间戳过旧，直接被抛弃。

2. 即使被动关闭方还处于 LAST-ACK 状态，主动关闭方 **reuse** TIME-WAIT连接，发起三次握手。当被动关闭方收到三次握手的 SYN ，得益于时间戳的存在，并不是回应一个 RST ，而是回应 FIN+ACK，而此时主动关闭方正在 SYN-SENT 状态，对于突如其来的 FIN+ACK，直接回应一个 RST ，被动关闭方接受到这个 RST 后，连接就关闭被回收了。当主动关闭方再次发起 SYN 时，就可以三次握手建立正常的连接。

   ![upload successful](/images/pasted-204.png)

而对于 **server （被动发起方）主动关闭连接** 的情况，开启 `net.ipv4.tcp_tw_recyle` 来应对 TIME-WAIT 连接过多的情况。开启 recyle 后，系统便会记录来自每台主机的每个连接的分组时间戳。对于新来的连接，如果发现 SYN 包中带的时间戳比之前记录来自同一主机的同一连接的分组所携带的时间戳要比之前记录的时间戳新，则接受复用 TIME-WAIT 连接，否则抛弃。

但是开启 `net.ipv4.tcp_tw_recyle` 有一个比较大的问题，虽然在同一个主机中，发出TCP包的时间戳是可以保证单调递增，但是 TCP包经过路由 NAT 转换的时候，并不会更新这个时间戳，因为路由是工作在IP层的嘛。所以如果在 client 和 server 中经过路由 NAT 转换的时候，对于 server 来说源IP是一样的，但是时间戳是由路由后面不同的主机生成的，后发包的时间戳就不一定比先发包的时间戳大，很容易造成 **误杀** ，终止了新连接的创建。

最后的结论是：

- 对于是 **client （连接发起主动方）主动关闭连接** 的情况，开启 `net.ipv4.tcp_tw_reuse` 就很合适的。
- 对于 **server （被动发起方）主动关闭连接** 的情况，确保 client 和 server 中间没有 NAT ，开启 `net.ipv4.tcp_tw_recycle` 也是ok的。但是如果有 NAT ，那还是算了吧。

## 参考

1. [深入理解TCP的TIME-WAIT](http://blog.qiusuo.im/blog/2014/06/11/tcp-time-wait/)
2. [TCP Time Wait State，通过代码体现了TIME-WAIT的问题](https://zhuanlan.zhihu.com/p/45218723)