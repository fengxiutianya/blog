---
title: TCP保活机制
tags:
  - tcp
categories:
  - 网络
  - tcp
abbrlink: b56667c1
date: 2019-03-10 08:23:00
---
# TCP保活机制

## 什么是保活机制

保活机制是一种在不影响数据流内容的情况下探测对方的方式。和名字正好相反，是服务器用来确认什么时候应该断开连接的一种机制。保活功能在默认情况下是关闭的， TCP连接的任何一端都可以请求打开这一功能。保活功能可以被设置在连接的一端、两端,或者两端都没有。
<!-- more -->

## **TCP保活的缘起**

双方建立交互的连接，但是并不是一直存在数据交互，有些连接会在数据交互完毕后，主动释放连接，而有些不会，那么在长时间无数据交互的时间段内，交互双方都有可能出现掉电、死机、异常重启等各种意外，当这些意外发生之后，这些TCP连接并未来得及正常释放，那么，连接的另一方并不知道对端的情况，它会一直维护这个连接，长时间的积累会导致非常多的半打开连接，造成端系统资源的消耗和浪费，为了解决这个问题，在传输层可以利用TCP的保活报文来实现。

## TCP保活的作用

1. **探测连接的对端是否存活**        

   在应用交互的过程中，可能存在以下几种情况：

   * 客户端或服务器端意外断电、死机、崩溃、重启
   * 中间网络已经中断，而客户端与服务器端并不知道

   利用保活探测功能，可以探知这种对端的意外情况，从而保证在意外发生时，可以释放半打开的TCP连接。

2. **防止中间设备因超时删除连接相关的连接表**

   中间设备如防火墙等，会为经过它的数据报文建立相关的连接信息表，并为其设置一个超时时间的定时器，如果超出预定时间，某连接无任何报文交互的话，中间设备会将该连接信息从表中删除，在删除后，再有应用报文过来时，中间设备将丢弃该报文，从而导致应用出现异常，这个交互的过程大致如下图所示：

   ![upload successful](/images/pasted-207.png)

   这种情况在有防火墙的应用环境下非常常见，这会给某些长时间无数据交互但是又要长时间维持连接的应用（如数据库）带来很大的影响，为了解决这个问题，应用本身或TCP可以通过保活报文来维持中间设备中该连接的信息，（也可以在中间设备上开启长连接属性或调高连接表的释放时间来解决，但是，这个影响可能较大，有机会再针对这个做详细的描述，在此不多说）。

**常见应用故障场景：**

​       某财务应用，在客户端需要填写大量的表单数据，在客户端与服务器端建立TCP连接后，客户端终端使用者将花费几分钟甚至几十分钟填写表单相关信息，终端使用者终于填好表单所需信息后，点击“提交”按钮，结果，这个时候由于中间设备早已经将这个TCP连接从连接表中删除了，其将直接丢弃这个报文或者给客户端发送RST报文，应用故障产生，这将导致客户端终端使用者所有的工作将需要重新来过，给使用者带来极大的不便和损失。

## TCP保活报文格式

在一段时间(称为保活时间,keepalivetime)内连接处于非活动状态,开启保活功能的一端将向对方发送一个保活探测报文。如果发送端没有收到响应报文,那么经过一个已经提前配置好的**保活时间间隔**(keepaliveinterval),将继续发送保活探测报文,直到发送探测报文的次数达到**保活探测数**(keepaliveprobe),这时对方主机将被确认为不可到达,连接也将被中断。

保活探测报文为一个空报文段（或1个字节），序列号等于对方主机发送的ACK报文的最大序列号减1。
 因为这一序列号的数据段已经被成功接收,所以不会对到达的报文段造成影响,但探测报文返回的响应可以确定连接是否仍在工作。接收方收到该报文以后，会认为是之前丢失的报文，所以不会添加进数据流中。但是仍然要发送一个ACK确认。探测及其响应报文丢失后都不会重传。探测方主动不重传，相应方的ACK报文并不能自己重传，所以需要保活探测数。

**TCP保活的交互过程大致如下图所示：**

![upload successful](/images/pasted-208.png)

### 保活结果

1. **对方主机仍在工作**： 服务器端正常收到ACK，说明客户端正常工作。 请求端将保活计时器重置。重新计时。
2. **对方主机已经崩溃：**对方的TCP将不会响应ACK。超过保活探测数以后，认为对方主机已经关闭,连接也将被断开。
3. **客户主机崩溃并且已重启：**客户端响应是一个重置报文段,请求端将会断开连接。
4. **对方主机仍在工作：**但是因为其他原因就是没有收到ACK。

## **TCP保活可能带来的问题**

1. **中间设备因大量保活连接，导致其连接表满**

​       网关设备由于保活问题，导致其连接表满，无法新建连接（XX局网闸故障案例）或性能下降严重

2. **正常连接被释放**

    当连接一端在发送保活探测报文时，中间网络正好由于各种异常（如链路中断、中间设备重启等）而无法将该保活探测报文正确转发至对端时，可能会导致探测的一方释放本来正常的连接，但是这种可能情况发生的概率较小，另外，一般也可以增加保活探测报文发生的次数来减小这种情况发生的概率和影响。

## 参考

1. [TCP保活（TCP keepalive）](http://www.vants.org/?post=162)
2. [第十七章 TCP保活机制](https://www.jianshu.com/p/31222c1fbe56)