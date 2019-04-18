---
title: Http协议中的Content-Encoding
abbrlink: e20a716d
categories:
  - 网络
  - http
date: 2019-04-18 22:46:30
tags:
  - Content-Encoding
  - Accept-Encoding
  - 请求内容压缩
---
`Accept-Encoding`和`Content-Encoding`是HTTP中用来对「采用何种编码格式传输正文」进行协定的一对头部字段。它的工作原理是这样：浏览器发送请求时，通过Accept-Encoding带上自己支持的内容编码格式列表；服务端从中挑选一种用来对正文进行编码，并通过`Content-Encoding`响应头指明选定的格式；浏览器拿到响应正文后，依据`Content-Encoding`进行解压。当然，服务端也可以返回未压缩的正文，但这种情况不允许返回`Content-Encoding`。这个过程就是HTTP的内容编码机制。

内容编码目的是优化传输内容大小，通俗地讲就是进行压缩。一般经过gzip压缩过的文本响应，只有原始大小的1/4。对于文本类响应是否开启了内容压缩，是我们做性能优化时首先要检查的重要项目；而对于`JPG/PNG`这类本身已经高度压缩过的二进制文件，不推荐开启内容压缩，效果微乎其微还浪费CPU。不过谷歌开源了一个新的JPG图片压缩算法[guetzli](https://github.com/google/guetzli/),这个算法只有原来的1/3大小，有兴趣可以看一下。
<!-- more -->
内容编码针对的只是传输正文。在HTTP/1中，头部始终是以ASCII文本传输，没有经过任何压缩。这个问题在HTTP/2中得以解决，详见[TTP/2 头部压缩技术介绍](/posts/21d5679a/)。

内容编码使用特别广泛，理解起来也很简单，随手打开一个网页抓包看下请求响应就能明白。唯一要注意的是不要把它与 HTTP中的另外一个概念：[传输编码（Transfer-Encoding）](/posts/ce94709/)搞混。

上面已经大致介绍了内容编码，并且在实际的web开发过程中使用的也比较多，理解起来没那么难。下面将重点介绍内容编码机制，主要有以下三种：
- **DEFLATE**，是一种使用 Lempel-Ziv 压缩算法（LZ77）和哈夫曼编码的数据压缩格式。定义于[RFC 1951 : DEFLATE Compressed Data Format Specification](http://tools.ietf.org/html/rfc1951)；
- **ZLIB**，是一种使用DEFLATE的数据压缩格式。定义于 [RFC 1950 : ZLIB Compressed Data Format Specification](http://tools.ietf.org/html/rfc1950)；
- **GZIP**，是一种使用DEFLATE的文件格式。定义于[RFC 1952 : GZIP file format specification](http://tools.ietf.org/html/rfc1952)；

这三个名词有太多的含义，很容易让人晕菜。所以本文有如下约定：
1. DEFLATE、ZLIB、GZIP 这种大写字符，表示数据压缩格式；
2. deflate、gzip 这种小写字符，表示 HTTP 中 Content-Encoding 的取值；
3. Gzip 特指 GUN zip 文件压缩程序，Zlib 特指 Zlib 库；

在 HTTP/1.1 的初始规范[RFC 2616 的「3.5 Content Codings」](https://tools.ietf.org/html/rfc7230#section-4.2)这一节中，这样定义了Content-Encoding中的gzip和deflate：

* gzip，一种由文件压缩程序「Gzip，GUN zip」产生的编码格式，描述于(RFC 1952)。这种编码格式是一种具有32位CRC的Lempel-Ziv编码（LZ77）；
* deflate，由定义于 RFC 1950 的「ZLIB」编码格式与 RFC 1951 中描述的「DEFLATE」压缩机制组合而成的产物；
RFC 2616 对 Content-Encoding 中的 gzip 的定义很清晰，它就是指在 RFC 1952 中定义的 GZIP 编码格式；但对 deflate 的定义含糊不清，实际上它指的是 RFC 1950 中定义的 ZLIB编码格式，但 deflate这个名字特别容易产生误会。

在 Zlib 库的官方网站，有这么一条[FAQ：What's the difference between the "gzip" and "deflate" HTTP 1.1 encodings?](http://www.gzip.org/zlib/zlib_faq.html#faq38) 就是在讨论 HTTP/1.1对deflate的错误命名：
```
Q：在 HTTP/1.1 的 Content-Encoding 中，gzip 和 deflate 的区别是什么？

A：gzip 是指 GZIP 格式，deflate 是指 ZLIB 格式。HTTP/1.1 的作者或许应该将后者称之为 zlib，从而避免与原始的 DEFLATE 数据格式产生混淆。虽然 HTTP/1.1 RFC 2016 正确指出，Content-Encoding 中的 deflate 就是 RFC 1950 描述的 ZLIB，但仍然有报告显示部分服务器及浏览器错误地生成或期望收到原始的 DEFLATE 格式，特别是微软。所以虽然使用 ZLIB 更为高效（实际上这正是 ZLIB 的设计目标），但使用 GZIP 格式可能更为可靠，这一切都是因为 HTTP/1.1 的作者不幸地选择了错误的命名。
```
结论：在 HTTP/1.1的Content-Encoding中，请使用 gzip。

在 HTTP/1.1 的修订版 RFC 7230 的[4.2 Compression Codings](https://tools.ietf.org/html/rfc7230#section-4.2)这一节中，彻底明确了deflate的含义，对gzip也做了补充：

* deflate，包含「使用 Lempel-Ziv 压缩算法（LZ77）和哈夫曼编码的 DEFLATE 压缩数据流（RFC 1951）」的ZLIB数据格式（RFC 1950）。注：一些不符合规范的实现会发送没有经过ZLIB包装的 DEFLATE 压缩数据；

* gzip，具有32位循环冗余检查（CRC）的LZ77编码，通常由Gzip文件压缩程序（RFC 1952）产生。接受方应该将x-gzip视为gzip；

总结一下，HTTP 标准中定义的 Content-Encoding: deflate，实际上指的是ZLIB编码（RFC 1950）。但由于RFC 2616中含糊不清的定义，导致IE错误地实现为只接受原始DEFLATE（RFC 1951）。为了兼容 IE，我们只能 Content-Encoding: gzip进行内容编码，它指的是GZIP编码（RFC 1952）。

其实上，ZLIB 和 DEFLATE 的差别很小：ZLIB 数据去掉 2 字节的 ZLIB 头，再忽略最后 4 字节的校验和，就变成了 DEFLATE 数据。


## 参考
1. [HTTP 协议中的 Content-Encoding](https://imququ.com/post/content-encoding-header-in-http.html)
2. [如何压缩 HTTP 请求正文](https://imququ.com/post/how-to-compress-http-request-body.html)