---
title: Http的演进之路之三
tags:
  - http
categories:
  - 网络
  - http
abbrlink: 9a3c28b1
date: 2019-03-10 08:23:00
---
---
# Http的演进之路之三

## 声明，此系列文章转载自[lonnieZ http的演进之路](https://www.zhihu.com/people/lonniez/activities)

## **HTTP/1.1**

## cookie机制

前面不止一次讲过HTTP属于无状态的协议。所谓无状态是指：每个请求之间是独立的，当前请求不会记录它与上一次请求之间的关系。那么我们面临的问题是：当需要完成一整套业务逻辑的时候，请求与请求之间需要建立一定的逻辑关系，那么如何管理多次请求之间的关系来保证上下文的一致性。为此，网景公司（早期浏览器大厂，曾经与微软的IE进行过著名的浏览器大战）设计了Cookie，它是保存在客户端并通过request header发送给服务端的一段文本，用来标识客户在服务端的状态。简单来说，当你访问一个之前曾经登录过的网站的时候，你会发现现在的状态是已登录的状态，而不再需要输入用户名和密码才能登录。这就是Cookie的作用，它让浏览器与服务端可以对用户的状态进行沟通，从而使原本没有状态的HTTP协议变得有状态了。一个Cookie的简单交互流程如下：

![upload successful](/images/pasted-234.png)
<!-- more -->

当用户访问一个服务器的时候，服务端会获取该用户的相关信息（例如账号等），然后会在服务端计算出一个数值并通过Set-Cookie头域返回给客户端。从上图中可以看到用户第一次访问[http://www.alibaba-inc.com](http://link.zhihu.com/?target=http%3A//www.alibaba-inc.com)并在response中得到了Set-Cookie头域。当用户再次访问该服务器时，会在request header中添加一个Cookie头域并在该头域中设置之前服务器返回的信息，当服务端收到这个带有Cookie头域的request请求时就会知道是谁发起了这次请求并会在服务端立刻恢复用户状态。

其中Set-Cookie用在响应消息中，里面包含了如下信息。Cookie头域用在请求消息中，它包含了Set-Cookie中返回的NAME-VALUE对。

![upload successful](/images/pasted-235.png)

从上面的表格中，我们可以看出Cookie的一些特性，例如Cookie的不可跨域性。当访问Baidu的时候相关request不会带上Google的Cookie，反之也是一样的。因为在Cookie中会根据Domain和Path参数来限定浏览器使用Cookie的URL。以下是一个实际的例子。这是第一次访问[http://www.baidu.com](http://link.zhihu.com/?target=http%3A//www.baidu.com)的时候服务端返回了一些Set-Cookie，里面包含了上面所说的那些信息。

![upload successful](/images/pasted-236.png)

当再次对baidu进行访问的时候，在request的header中添加了Cookie的信息，这些Cookie的信息就是上次response中Set-Cookie的内容：

![upload successful](/images/pasted-237.png)

从上面的实际返回信息可以看出，Baidu网站返回Cookie的Domain为".[http://baidu.com](http://link.zhihu.com/?target=http%3A//baidu.com)"，这说明所有以[http://baidu.com](http://link.zhihu.com/?target=http%3A//baidu.com)结尾的域名都可以使用该Cookie；返回的Path为"/"，这说明该domain下的所有path访问都可以使用该Cookie，假如返回的是"/example/"，那么只有包含"/example/"的URL可以使用该Cookie。

此外，Cookie分为两种：会话Cookie与持久Cookie。前者是一种临时Cookie，当浏览器退出时，该Cookie就会被删除，这种Cookie会保存在内存中。而持久Cookie会保持在磁盘上，只有当Cookie的有效期过了以后，才会将相关Cookie删除。

## session机制

Cookie保存在浏览器端，相当于由用户来保存相关的状态。而Session是另一种记录用户状态的机制，它是由服务端保存用户状态信息并返回一个唯一的SessionID给用户，当用户提供相关SessionID后服务端恢复对应状态。如果说Cookie机制是通过检查客户身上的“身份证”来确定身份信息的话，那么Session机制就是通过检查服务端上“客户信息表”来确认客户身份。Session机制相当于在服务端建立了一份客户档案，客户来访问的时候仅需要查询该份档案即可。以下是一个示例，当我们第一次访问[http://www.elf.com/](http://link.zhihu.com/?target=http%3A//www.elf.com/)的时候，服务端会通过Set-Cookie头域返回一个SessionID：

![upload successful](/images/pasted-238.png)

当我们再次访问这个网站的时候，可以看到浏览器将这个SessionID通过Cookie头域发送给服务端：

![img](https://pic2.zhimg.com/80/v2-0259adf2e7b498acf3291315caaad62d_hd.jpg)

至此，我们可以罗列以下Cookie与Session的区别：

- Cookie将数据存放在客户的浏览器上；Session将数据存放在服务器上
- Cookie更容易泄漏，别人可以分析存放在本地的Cookie信息并进行Cookie欺骗；而Session在安全性上相对好些；
- Cookie不会增加服务器的负担；Session不仅会加大服务器侧的负担，而且在一些分布式服务器上SessionID会失效，因为Session信息不一定会同步到各个服务器上
- Session的运行依赖于SessionID，而SessionID又是在Cookie中，即如果Cookie被禁用了，那么Session机制也会失效

综上所述：对于一些非常敏感的信息，例如登录信息等最好使用Session机制由服务端管理，而其他信息可以使用Cookie机制在本地进行管理。

## 数据压缩

Http数据部分的压缩其实是就是对其编码的过程（例如gzip）。客户端在请求数据的时候会告知服务端自己可以接收的编码格式，服务端在随后的应答时会将相关数据使用这些编码格式进行编码并发送给客户端。从下图可以看出客户端在发送request请求的时候会添加accept-encoding头域来告知服务端自己支持的内容编码格式：

- gzip 使用GUN zip对内容进行编码；
- compress 使用UNIX的文件压缩程序进行编码；
- deflate 使用zlib对内容进行编码；
- identity 表明不对内容进行编码，当没有accept-encoding头域时，默认为这种情况。

![upload successful](/images/pasted-239.png)

从上图中可以看到当申请一个index.html资源时，如果使用了accept-encoding头域，则会在服务端对相关资源进行压缩处理并通过content-encoding头域告知客户端该资源已经通过gzip进行了压缩。通过数据压缩可以大大减少双方的数据交互，节省流量。从下图的抓包中可以看到使用gzip压缩后可以大大降低数据的大小。

![upload successful](/images/pasted-240.png)