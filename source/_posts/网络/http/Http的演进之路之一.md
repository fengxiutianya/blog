---
tags:
  - http
categories:
  - 网络
title: Http的演进之路之一
abbrlink: e3e09015
date: 2019-03-10 08:23:00
---
---
# Http的演进之路之一

## 声明，此系列文章转载自[lonnieZ http的演进之路](https://www.zhihu.com/people/lonniez/activities)

## **摘要**

本文主要介绍了HTTP协议的演进过程，从HTTP/0.9到目前HTTP/2中各个版本的特点以及成因。通过对比各个版本的特点以及相关数据的支持来讲解整个HTTP协议的演进过程。此外，文中还会涉及一些相关协议概念，包括TCP/IP、DNS、HTTPS、QUIC、SPDY等，正是这些协议与HTTP一起为我们展现了一个丰富多彩的互联网的世界。

## **HTTP的演进**

![upload successful](/images/pasted-209.png)

HTTP(HyperText Transfer Protocol)是万维网（World Wide Web）的基础协议，她制定了浏览器与服务器之间的通讯规则，她由Berners-Lee和他的团队在1989-1991年期间开发完成，至今共经历了3个版本的演化。

<!-- more -->
## **HTTP/0.9**

HTTP问世之初并没有作为标准建立，被正式制定为标准是在1996年公布的HTTP/1.0协议。因此，在这之前的协议被称为HTTP/0.9

HTTP/0.9协议功能极为简单，request只有一行且只有一个GET命令，命令后面跟着的是资源路径。

```text
GET /index.html
```

reponse同样简单，仅包含文件内容本身。

```text
<html>
  <body>HELLO WORLD!</body>
</html>
```

HTTP/0.9没有header的概念，也没有content-type的概念，仅能传递html文件。同样由于没有status code，当发生错误的时候是通过传递回一个包含错误描述的html文件来处理的。

**此外HTTP/0.9具有无状态性**，每个请求之间是独立的，当这个请求处理完成后会释放当前连接，因此可以看到**HTTP协议无状态性其实是天生的**，这也就有了后面的Cookie和Session技术。

## **HTTP/1.0**

随着互联网技术的飞速发展，HTTP协议被使用的越来越广泛，协议本身的局限性已经不能满足互联网功能的多样性。因此，HTTP/1.0于1996年问世了，其内容和功能都大大增加了。对比与HTTP/0.9，新的版本包含了以下功能：

- 在每个request的GET一行后面添加版本号
- 在response中添加状态行并作为第一行返回给用户
- 在request和response中添加header的概念
- 在header中添加content-type以此可以传输html之外类型的文件
- 在header中添加content-encoding来支持不同编码格式文件的传输
- 引入了POST和HEAD命令，丰富了浏览器与服务器的交互方式
- 支持长连接（默认还是短连接）

也就是自从HTTP/1.0开始，HTTP的主要格式就定义下来，如下所示：

**请求报文包含四部分：**

- 请求行：包含请求方法、URI、HTTP版本信息
- 请求头部字段
- 空行
- 请求内容实体

**响应报文包含四部分：**

- 状态行：包含HTTP版本、状态码、状态码的原因短语
- 响应头部字段
- 空行
- 响应内容实体

一个典型的的request/response交互如下：

```text
GET /index.html HTTP/1.0
User-Agent: NCSA_Mosaic/2.0 (Windows 3.1)

200 OK
Date: Tue, 15 Nov 1994 08:12:31 GMT
Server: CERN/3.0 libwww/2.17
Content-Type: text/html
<HTML>
A page with an image
  <IMG src="/image.gif">
<HTML>
```

当Mosaic浏览器解析html文件后，会发起第二个请求来获取图片：

```http
GET /image.gif HTTP/1.0
User-Agent: NCSA_Mosaic/2.0 (Windows 3.1)

200 OK
Date: Tue, 15 Nov 1994 08:12:32 GMT
Server: CERN/3.0 libwww/2.17
Content-Type: text/gif
(image content)
```

此外，在HTTP/1.0中规定header信息必须是ASCII码，后面的数据可以是任何格式。因此，服务器在应答的时候需要告诉用户数据的格式，即Content-Type的作用。一些常见Content-Type：

![upload successful](/images/pasted-210.png)

Content-Type的每个值包括一级类型和二级类型，之间用斜杠分开；此外还可以自定义Content-Type；还可以在Content-Type中添加参数，如下面的示例，Content-Type表示发送的是网页而编码格式是utf-8.

```http
Content-Type: text/html; charset=utf-8
```

由于支持任意数据格式的发送，因此可以先把数据进行压缩再发送。HTTP/1.0进入了Content-Encoding来表示数据的压缩方式。

- Content-Encoding: gzip
- Content-Encoding: compress
- Content-Encoding: deflate

而客户端也可以在header中添加如下信息来表明自己可以接受哪些压缩方式：

```http
Accept-Encoding: gzip, deflate
```

为了解决每次请求完一个资源后连接会断开，若再请求同一个服务器上的资源需要重新建立连接的问题，HTTP/1.0引入了长连接的概念。众所周知，HTTP的建连成本是较高的，由于HTTP基于TCP协议之上，一个建立连接的过程需要DNS过程以及TCP的三次握手。随着网页资源的日益增多，每请求完一个资源需要重新建立的消耗越来越大，因此用一条长连接来获取多个资源就可以大大节省网页的访问时间，提升连接的效率。HTTP/1.1在request header中引入如下信息来告知服务器完成一次request请求后不要关闭连接：

```http
Connection: keep-alive
```

同样，服务器端也会答复一个相同的信息表示连接仍然有效。这样，后面的请求就可以复用该条连接了，只可惜该条信息此时没有加入到标准中，而是一种自定义行为。HTTP/1.0的[RFC1945](http://link.zhihu.com/?target=https%3A//tools.ietf.org/html/rfc1945)