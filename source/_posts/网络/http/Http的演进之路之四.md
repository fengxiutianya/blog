---
tags:
  - http
categories:
  - 网络
  - http
title: Http的演进之路之四
abbrlink: d6ee44af
date: 2019-03-10 10:23:00
---
## **HTTP/1.1**
## 同源策略与跨域访问
同源策略（Same-Origin Policy）是浏览器访问网页过程中最基础的安全策略。它仍然是由大名鼎鼎的网景公司提出的（网景公司对HTTP、SSL等协议的制定做出了巨大贡献，只是在随后的浏览器大战中输给了以垄断见长的微软IE）。所谓“同源”是指浏览器访问目标url的域名（domain）、协议（protocol）、端口（port）这三个要素是相同的。所谓“同源策略”是指A页面里的脚本通过[XHR](http://link.zhihu.com/?target=https%3A//developer.mozilla.org/zh-CN/docs/Web/API/XMLHttpRequest)和[Fetch](http://link.zhihu.com/?target=https%3A//developer.mozilla.org/zh-CN/docs/Web/API/Fetch_API)等方式加载B页面资源时，如果发现B页面与A页面不是“同源”的，则会禁止访问（准确的说是对跨域请求的返回结果进行屏蔽）。下图显示了一个由script发出的非同源请求，数据最终会在browser端被屏蔽。
<!-- more -->

![upload successful](/images/pasted-241.png)

为了验证一下同源策略的有效性，我进行了如下测试，首先在本地Mac上搭建一个nignx服务器，可以参照这个[方法](http://link.zhihu.com/?target=https%3A//blog.csdn.net/snowrain1108/article/details/50072057)搭建。然后在首页（/usr/local/var/www/index.html）中添加如下script内容：

```java
<script>
var xhr = new XMLHttpRequest();
xhr.onreadystatechange=function(){
    if (xhr.readyState == 4) {
        if((xhr.status >= 200 && xhr.status < 300) || xhr.status == 304) {
            alert("ok");
        } else {
            alert("fail");
        }
    }
};
xhr.open("GET", "http://api.yunos.com", true);
xhr.send(null);
</script>
```

在shell中开启nignx，然后通过chrome浏览器输入http://localhost:8080会显示以下内容。这表示由xhr发起的跨域请求没有成功。

![upload successful](/images/pasted-242.png)

再通过chrome浏览器的开发者工具中的console可以看到如下信息。从红色信息中可以看到，由于跨域请求的资源 [http://api.yunos.com](http://api.yunos.com)的response header中没有Access-Control-Allow-Origin头域（后面会讲到），因此本次跨域请求的返回结果被屏蔽。

![upload successful](/images/pasted-243.png)

为了进一步验证数据是在浏览器侧被屏蔽的，我们通过wireshark进行了抓包处理，从抓包中可以清楚的看到[http://api.yunos.com](http://api.yunos.com)的内容已经下载到了客户端：

![upload successful](/images/pasted-244.png)

![upload successful](/images/pasted-245.png)

从上面的实验可以验证同源测试的有效性。

## 跨域资源共享（Cross-Origin Resource Sharing, CORS）

随着互联网的不断发展，网站的规模和复杂程度也与日俱增，因此在网页设计上会存在类似上面那样的跨域请求，即需要绕过“同源策略”去完成跨域请求。因此，出现了“跨域资源共享”（CORS）机制，它的实现原理是服务端与客户端配合，新增一组HTTP首部字段，允许服务器声明哪些源站有权限访问哪些资源。例如，通过在response header中添加相关头域（上面看到的Access-Control-Allow-Origin头域）来告知客户端（浏览器）该资源是否可以跨域访问本资源。

此外，对于那些可能对服务端数据产生副作用的HTTP方法（例如GET以外的一些方法），要求浏览器必须先使用[OPTIONS](http://link.zhihu.com/?target=https%3A//developer.mozilla.org/zh-CN/docs/Web/HTTP/Methods/OPTIONS)方法发起一个预检请求（preflight request），从服务器端获知是否允许本次跨域请求。只有当服务器端允许后，才能发起实际的HTTP请求。在预检请求对应的response中，服务端也可以通知客户端是否需要携带身份凭证（例如Cookie等）。因此，CORS将跨域请求分为了三种情况：

- 简单请求（Simple Request）
- 预检请求（Preflight Request）
- 附带身份凭证请求（Request with Credential）

### 简单请求（Simple Request）

如果一个请求中没有包含任何自定义的请求头，并且他所使用的HTTP方法是GET、HEAD或POST之一，并且方法为POST时，其Content-Type需要是`application/x-www-form-urlencoded`，`multipart/form-data`或`text/plain`之一。

下面是一个Simple Request的示例。此处是在[arunranga](http://arunranga.com/examples/access-control/simpleXSInvocation.html)这个域名里面通过一个XHR请求GET申请[aruner](http://aruner.net/resources/access-control-with-get/)里面的资源。

```javascript
<script type="text/javascript">
    var invocation = new XMLHttpRequest();
    var url = 'http://aruner.net/resources/access-control-with-get/';

    invocation.open('GET', url, true);
    invocation.onreadystatechange = handler;
    invocation.send(); 
    ...    
</script>
```

通过chrome的开发者工具来看具体的request请求。当在arunranga中发起对[http://aruner.net](http://aruner.net)的资源的请求后，[http://aruner.net](http://aruner.net)返回的response header中添加了Access-Control-Allow-Origin头域并告知可以允许[http://arunrange.com](http://arunrange.com)使用该资源。

![upload successful](/images/pasted-246.png)

下面是通过wireshark抓包的情况：

![upload successful](/images/pasted-247.png)

简单请求的原理是在浏览器中设置了一个白名单，符合以上条件的才是简单请求。当我们要发送一个跨域请求的时候，浏览器会先检查该请求，如果满足以上条件，浏览器会立即发送该请求。如果发现为非简单请求（比如头域中包含一个X-Forwarded-For字段），此时浏览器不会马上发送该请求，而是发送一个Preflight Request，有一个与服务器进行验证的过程。

### 预检请求（Preflight Request）

如果一个请求包含了任何自定义的头域，或者它使用的HTTP方法是GET、HEAD、POST之外的任何一个方法，或者POST请求的Content-Type不是application/x-www-form-urlencoded，multipart/form-data或text/plain之一。

下面是一个Preflight Request的示例。此处是在[arunranga](http://arunranga.com/examples/access-control/preflightInvocation.html)这个域名里面通过一个XHR请求POST一段数据至[aruner](http://aruner.net/resources/access-control-with-post-preflight/)端。

```script
<script type="text/javascript">
    var invocation = new XMLHttpRequest();
    var url = 'http://aruner.net/resources/access-control-with-post-preflight/';
    var body = '<?xml version="1.0"?><person><name>Arun</name></person>';

    invocation.open('POST', url, true);
    invocation.setRequestHeader('X-PINGARUNER', 'pingpong');
    invocation.setRequestHeader('Content-Type', 'application/xml');
    invocation.onreadystatechange = handler;
    invocation.send(body);
    ...
</script>
```

通过chrome的开发者工具来看具体的request请求。当浏览器发现本次请求存在跨域情况并且不符合“简单请求”的条件（此处为POST操作且包含自定义的头域X-PINGARGUNER，此外Content-Type也不符合“简单请求”的限制），因此将其视为Preflight Request进行操作。此时会先向目标地址发送一个OPTIONS请求并告知服务器随后会使用POST方法（Access-Control-Request-Method: POST）和自定义的请求头部（Access-Control-Request-Headers: X-PINGARUNER, CONTENT-TYPE）以此来问询服务器是否接受。

服务器在response header中对OPTIONS请求中的问询内容进行了反馈，具体可以看到Access-Control-Allow-Methods: POST, GET, OPTIONS 表明服务端允许客户端使用POST、GET、OPTIONS方法；Access-Control-Allow-Headers: X-PINGARUNER, CONTENT-TYPE表明服务端允许客户端使用携带X-PINGARUNER和CONTENT-TYPE的头域；Access-Control-Max-Age表明该响应的时效为20天，即20天内浏览器无需再为同一个请求发起预检请求（浏览器自身维护了一个最大有效时间，以两者中较小值为准）。

![upload successful](/images/pasted-248.png)

下面的这个请求就是OPTIONS返回后实际发出的POST请求。在该请求中包含了OPTIONS向服务端查询的那些头域：

![upload successful](/images/pasted-249.png)

下面是wireshark抓包的情况。从抓包可以看到，两次请求是通过一个tcp connection发出的。首先发送了OPTIONS进行问询，随后发送了真正的POST请求：

![upload successful](/images/pasted-250.png)

### 附带身份凭证请求（Request with Credential）

如果一个跨域请求中包含了当前页面的用户凭证（例如Cookie信息等）。

下面是一个的示例。当将XHR的withCredentials设置为“true”以后，则会想服务端发送当前页面的Cookie信息。此处是在arunranga这个域名里面通过一个XHR请求GET申请[aruner](http://aruner.net/resources/access-control-with-credentials/)里面的资源并要求携带本页面的Cookie信息。

```javascript
<script type="text/javascript"> 
    var invocation = new XMLHttpRequest(); 
    var url = 'http://aruner.net/resources/access-control-with-credentials/';       
     
    invocation.open('GET', url, true);      
    invocation.withCredentials = "true"; // 向服务器发送Cookie信息     
    invocation.onreadystatechange = handler;     
    invocation.send();
    ... 
</script>
```

由于这是一个GET请求，因此浏览器不会视其为“预检请求”，她会直接发送GET请求。当第一次发起请求的时候，服务端会通过Set-Cookie头域返回Cookie信息，并且通过Access-Control-Allow-Credentials: true 头域告知浏览器可以将响应内容传递给用户（如果响应头域中未包含该项，则浏览器将屏蔽返回内容）。

![upload successful](/images/pasted-251.png)

当二次发起该请求的时候，可以看到此时已经将Cookie信息带上了。从返回的内容也可以看出，服务端已经识别了客户端的Cookie信息：

![upload successful](/images/pasted-252.png)

需要注意的是：对于“附带身份凭证请求”，服务器响应的Access-Control-Allow-Origin的值不能为“*”（即不能设置对所有人可见），这是因为在第一次的响应请求头域中携带了Set-Cookie信息、在第二次的请求头域中携带了Cookie信息。

**相关头域**

![upload successful](/images/pasted-253.png)

## 参考
1. [lonnieZ http的演进之路](https://www.zhihu.com/people/lonniez/activities)