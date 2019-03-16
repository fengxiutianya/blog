---
title: TCP 三次握手，四次挥手进阶
tags:
  - tcp
categories:
  - 网络
  - tcp
abbrlink: 1fc2fe8
date: 2019-03-09 13:25:00
---
   ## ISN

   三次握手的一个重要功能是客户端和服务端交换ISN(Initial Sequence Number), 以便让对方知道接下来接收数据的时候如何按序列号组装数据。

   如果ISN是固定的，攻击者很容易猜出后续的确认号。

   ```
   ISN = M + F(localhost, localport, remotehost, remoteport)
   ```

   M是一个计时器，每隔4微秒加1。 F是一个Hash算法，根据源IP、目的IP、源端口、目的端口生成一个随机数值。要保证hash算法不能被外部轻易推算得出。
   <!--more -->

   ## 序列号回绕

   因为ISN是随机的，所以序列号容易就会超过2^31-1. 而tcp对于丢包和乱序等问题的判断都是依赖于序列号大小比较的。此时就出现了所谓的tcp序列号回绕（sequence wraparound）问题。怎么解决？

   ```
   /** The next routines deal with comparing 32 bit unsigned ints
    * and worry about wraparound (automatic with unsigned arithmetic).*/
   
   static inline int before(__u32 seq1, __u32 seq2){
       return (__s32)(seq1-seq2) < 0;}
   
   #define after(seq2, seq1) before(seq1, seq2)
   ```

   上述代码是内核中的解决回绕问题代码。s32是有符号整型的意思，而u32则是无符号整型。序列号发生回绕后，序列号变小，相减之后，把结果变成有符号数了，因此结果成了负数。

   ```
   假设seq1=255， seq2=1（发生了回绕）。
   seq1 = 1111 1111 seq2 = 0000 0001
   我们希望比较结果是
    seq1 - seq2=
    1111 1111
   -0000 0001
   -----------
    1111 1110
   
   由于我们将结果转化成了有符号数，由于最高位是1，因此结果是一个负数，负数的绝对值为
    0000 0001 + 1 = 0000 0010 = 2
   
   因此seq1 - seq2 < 0
   ```

   ## syn flood攻击

   最基本的DoS攻击就是利用合理的服务请求来占用过多的服务资源，从而使合法用户无法得到服务的响应。syn flood属于Dos攻击的一种。

   如果恶意的向某个服务器端口发送大量的SYN包，则可以使服务器打开大量的半开连接，分配TCB（Transmission Control Block）, 从而消耗大量的服务器资源，同时也使得正常的连接请求无法被相应。当开放了一个TCP端口后，该端口就处于Listening状态，不停地监视发到该端口的Syn报文，一 旦接收到Client发来的Syn报文，就需要为该请求分配一个TCB，通常一个TCB至少需要280个字节，在某些操作系统中TCB甚至需要1300个字节，并返回一个SYN ACK命令，立即转为SYN-RECEIVED即半开连接状态。系统会为此耗尽资源。

   ## 常见的防攻击方法有：

   ### 无效连接的监视释放

   监视系统的半开连接和不活动连接，当达到一定阈值时拆除这些连接，从而释放系统资源。这种方法对于所有的连接一视同仁，而且由于SYN Flood造成的半开连接数量很大，正常连接请求也被淹没在其中被这种方式误释放掉，因此这种方法属于入门级的SYN Flood方法。

   ### 延缓TCB分配方法

   消耗服务器资源主要是因为当SYN数据报文一到达，系统立即分配TCB，从而占用了资源。而SYN Flood由于很难建立起正常连接，因此，当正常连接建立起来后再分配TCB则可以有效地减轻服务器资源的消耗。常见的方法是使用Syn Cache和Syn Cookie技术。

   ### Syn Cache技术

   系统在收到一个SYN报文时，在一个专用HASH表中保存这种半连接信息，直到收到正确的回应ACK报文再分配TCB。这个开销远小于TCB的开销。当然还需要保存序列号。

   ### Syn Cookie技术

   Syn Cookie技术则完全不使用任何存储资源，这种方法比较巧妙，它使用一种特殊的算法生成Sequence Number，这种算法考虑到了对方的IP、端口、己方IP、端口的固定信息，以及对方无法知道而己方比较固定的一些信息，如MSS(Maximum Segment Size，最大报文段大小，指的是TCP报文的最大数据报长度，其中不包括TCP首部长度。)、时间等，在收到对方 的ACK报文后，重新计算一遍，看其是否与对方回应报文中的（Sequence Number-1）相同，从而决定是否分配TCB资源。

   ### 使用SYN Proxy防火墙

   一种方式是防止墙dqywb连接的有效性后，防火墙才会向内部服务器发起SYN请求。防火墙代服务器发出的SYN ACK包使用的序列号为c, 而真正的服务器回应的序列号为c', 这样，在每个数据报文经过防火墙的时候进行序列号的修改。另一种方式是防火墙确定了连接的安全后，会发出一个safe reset命令，client会进行重新连接，这时出现的syn报文会直接放行。这样不需要修改序列号了。但是，client需要发起两次握手过程，因此建立连接的时间将会延长。

   ## 连接队列

   在外部请求到达时，被服务程序最终感知到前，连接可能处于SYN_RCVD状态或是ESTABLISHED状态，但还未被应用程序接受。

   ![upload successful](/images/pasted-182.png)

   对应地，服务器端也会维护两种队列，处于SYN_RCVD状态的半连接队列，而处于ESTABLISHED状态但仍未被应用程序accept的为全连接队列。如果这两个队列满了之后，就会出现各种丢包的情形。

   ```
   查看是否有连接溢出
   netstat -s | grep LISTEN
   ```

   ### 半连接队列满了

   在三次握手协议中，服务器维护一个半连接队列，该队列为每个客户端的SYN包开设一个条目(服务端在接收到SYN包的时候，就已经创建了request_sock结构，存储在半连接队列中)，该条目表明服务器已收到SYN包，并向客户发出确认，正在等待客户的确认包。这些条目所标识的连接在服务器处于Syn_RECV状态，当服务器收到客户的确认包时，删除该条目，服务器进入ESTABLISHED状态。

   目前，Linux下默认会进行5次重发SYN-ACK包，重试的间隔时间从1s开始，下次的重试间隔时间是前一次的双倍，5次的重试时间间隔为1s, 2s, 4s, 8s, 16s, 总共31s, 称为`指数退避`，第5次发出后还要等32s才知道第5次也超时了，所以，总共需要 1s + 2s + 4s+ 8s+ 16s + 32s = 63s, TCP才会把断开这个连接。由于，SYN超时需要63秒，那么就给攻击者一个攻击服务器的机会，攻击者在短时间内发送大量的SYN包给Server(俗称SYN flood攻击)，用于耗尽Server的SYN队列。对于应对SYN 过多的问题，linux提供了几个TCP参数：tcp_syncookies、tcp_synack_retries、tcp_max_syn_backlog、tcp_abort_on_overflow 来调整应对。

   ![upload successful](/images/pasted-183.png)

   ### 全连接队列满

   当第三次握手时，当server接收到ACK包之后，会进入一个新的叫 accept 的队列。

   当accept队列满了之后，即使client继续向server发送ACK的包，也会不被响应，此时ListenOverflows+1，同时server通过tcp_abort_on_overflow来决定如何返回，0表示直接丢弃该ACK，1表示发送RST通知client；相应的，client则会分别返回`read timeout` 或者 `connection reset by peer`。另外，tcp_abort_on_overflow是0的话，server过一段时间再次发送syn+ack给client（也就是重新走握手的第二步），如果client超时等待比较短，就很容易异常了。而客户端收到多个 SYN ACK 包，则会认为之前的 ACK 丢包了。于是促使客户端再次发送 ACK ，在 accept队列有空闲的时候最终完成连接。若 accept队列始终满员，则最终客户端收到 RST 包（此时服务端发送syn+ack的次数超出了tcp_synack_retries）。

   服务端仅仅只是创建一个定时器，以固定间隔重传syn和ack到服务端

   ![upload successful](/images/pasted-184.png)

   ## 参考

   1. [三次握手，四次挥手你真的懂吗？](https://zhuanlan.zhihu.com/p/53374516)

