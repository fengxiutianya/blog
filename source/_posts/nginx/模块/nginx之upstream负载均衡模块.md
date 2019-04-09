---
title: nginx之upstream(负载均衡)模块
abbrlink: 4b64784d
categories:
  - nginx
  - 模块
tags:
  - nginx
  - 负载均衡
  - upstream
date: 2019-04-08 19:23:16
---
ngx_http_upstream_module模块用于定义服务器组，可以在proxy_pass, fastcgi_pass, uwsgi_pass, scgi_pass以及memcached_pass指令中引用。

示例如下
``` nginx
 upstream backend {
    server backend1.example.com       weight=5;
    server backend2.example.com:8080;
    server unix:/tmp/backend3;

    server backup1.example.com:8080   backup;
    server backup2.example.com:8080   backup;
}

server {
    location / {
        proxy_pass http://backend;
    }
}
```
<!-- more -->
## 指令集
### upstream
``` nginx
    Syntax:	upstream name { ... }
    Default:	—
    Context:	http
```
定义一组服务器。服务器可以监听不同的端口。此外，服务器可以混合的监听TCP和UNIX-domain socket。

示例如下,至于使用的参数，下面会讲解：
``` nginx
upstream backend {
    server backend1.example.com weight=5;
    server 127.0.0.1:8080       max_fails=3 fail_timeout=30s;
    ## unix 套接字
    server unix:/tmp/backend3;

    server backup1.example.com  backup;
}
```
默认情况下，请求在服务器之间的分配使用带权重的轮询负载均衡方式。上面的例子中，每7个请求会按如下方式分配：5个请求分配到backend1.example.com，第二个和第三个服务器分别分配1个请求。如果在与一个服务器通信时发生了错误，请求将会传递给下一个服务器，直到所有的服务器都尝试了。如果从任何一个服务器都得不到成功的响应，客户端将会收到与最后一个服务器通信的结果。

### server
``` nginx
    Syntax:	server address [parameters];
    Default:	—
    Context:	upstream
```
定义服务器的地址和其他参数。地址可以指定为一个域名或IP地址与可选的端口号，或UNIX-domain socket路径指定在“unix:”前缀后面。如果没有指定端口，则使用80端口。如果域名解析成多个IP地址，一次定义多个服务器。

上面指令可以指定下面几个参数，（有些参数只能在商业版中使用，这里就没说）
1. **weight=number**:设置权重，默认为1。
2. **max_conns=number**：限制到代理服务器的同时活动连接的最大数量（从1.11.5版本开始）。默认值为零，表示没有限制。如果服务器组没有设置shared memory中，则是分别针对每个工作进程分别来进行限制。
   如果启用[空闲连接](#keeplive)、多个workers和[共享内存](#zone)，则到代理服务器的激活的连接和空闲的连接总数可能超过最大值。
3. **max_fails=number**：设置在fail_timeout参数设置的持续时间内尝试与服务器通信失败的次数，以考虑服务器在fail_timeout参数设置的持续时间内不可用。默认情况下，不成功的尝试次数为1。零值禁用记录尝试次数。什么被视为不成功的尝试由proxy_next_upstream, fastcgi_next_upstream, uwsgi_next_upstream, scgi_next_upstream 和 memcached_next_upstream指令定义。
4. **fail_timeout=time**：和前面max_fails一起使用，在指定的时间内如果与代理服务器连接不成功的次数大于max_fails，则表示这个服务器不可用。并且持续不可用的时间为这个指定的时间值。默认值是10秒。因此这个时间的设置的单位也是秒。
5. **backup**：表示这台服务器是backup服务器。当前面设置的primary服务器都不可用时，才会使用这台服务器。
6. **down**：表示这台服务器永久不可用。

此外还有一点需要注意的是，如果一个组里面只有一台服务器，则max_fails,fail_timeout和slow_start参数会被忽略，这个服务器永远不会被视为不可用。（这里的不可用是指，所有的请求都会转发到这个服务器山个，即使服务器是不可用的，只是得到的结果都是错误）
### zone
``` nginx
    Syntax:	zone name [size];
    Default:	—
    Context:	upstream
    # 这个指令在版本1.9.0之后
```
定义共享内存区域名称和大小，用于保存服务器组的配置和运行状，在workers进程之间共享。多个服务器组可以共享相同的区域。这种情况下，仅指定一次大小就够了。
另外，在商业版本中，这些组允许在不重启nginx改变组的成员或修改一个服务器的配置。配置通过一个特殊的由upstream_conf处理的location访问。
### state
``` nginx
    Syntax:	state file;
    Default:	—
    Context:	upstream
    # 指令在版本1.9.7之后.
```
指定保持动态可配置组状态的文件。

例子：
``` nginx
state /var/lib/nginx/state/servers.conf; # path for Linux
state /var/db/nginx/state/servers.conf;  # path for FreeBSD
```
当前状态仅限于服务器及其参数的列表。分析配置时读取该文件，并在每次更改upstream配置时更新该文件。应避免直接更改文件内容。该指令不能与server指令一起使用。
在配置重新加载和二进制升级过程中的改变会丢失。

**该指令是商业版本的一部分。**

### hash
``` nginx
Syntax:	hash key [consistent];
Default:	—
Context:	upstream
从版本1.7.2+.
```
为服务器组指定一个负载均衡的方法：客户端-服务器映射基于哈希键值。可以包含文本、变量以及它们的混合。
注意，从组中添加或移除服务器可能会导致大部分的关键字都重新映射到不同的服务器。该方法与Cache::Memcached Perl库一致。
如果指定consistent参数，ketama一致性哈希算法将被使用。该方法确保当服务器添加到组或从组中删除时只有一少部分关键字会被映射到不同的服务器。这有助于为缓存服务器获得更高的缓存命中率。该方法与Cache::Memcached::Fast Perl库ketama_points参数设为160一致。

可以看下面的例子来帮助理解：
假设请求的url为**http://www.a.com/{path_var1}/{path_var2}**：其中path_var1和path_var2是两个path variable，如果现在只想根据path_var1来做路由，即path_var1相同的请求落在同一台服务器上，应当怎么配置呢？

场景大概就是这样，当url请求过来时候，通过url中的一个特定数值，进行提取，然后进行hash

![upload successful](/images/pasted-344.png)

下面是通常的配置
``` nginx
server{
    server_name 127.0.0.1;
    listen 80;
    location / {
        proxy_pass http://www_jesonc;
        # return 200 "index";
    }
}
upstream www_jesonc {
    server 127.0.0.1:5000;
    server 127.0.0.1:5001;
    server 127.0.0.1:5002;
}
server {
    listen       5000;
    location / {
      return 200 "5000";
    }
}
server {
    listen       5001;
    location / {
     return 200 "5001";
    }
}
server {
    listen       5002;
    location / {
        return 200 "5002";
    }
}
```
这时如果我们使用**http://127.0.0.1/5000/6000**来访问，这时会随机的分配到upstream组中的任何一台服务器上，也就是每一次访问都有可能不同。

下面我们使用自定义hash key的方式来使得相同的key值落在相同的服务器上，可以像下面这样设置:
``` nginx
## server 上下文
if ( $uri ~* "^\/([^\/]+)\/.*" ){
    set $defurlkey $1;
}

upstream www_jesonc {
    hash $defurlkey;
    server 127.0.0.1:5000;
    server 127.0.0.1:5001;
    server 127.0.0.1:5002;
}
```
这时如果我们使用上面的地址来访问，每一次都会落在相同的服务器上。
### ip_hash
``` nginx
    Syntax:	ip_hash;
    Default:	—
    Context:	upstream
```
指定一个组使用负载均衡方法基于客户端IP地址分配服务器。客户端IPv4地址的前三字节或整个IPv6地址作为哈希关键字。该方法确保来自相同的客户端请求将总会被传给同一个服务器，除非服务器不可用。在最后一种情况下，客户端请求将会传给另一个服务器。大部分情况下，总会传给相同的服务器。
**IPv6地址从1.3.2和1.2.2版本开始支持。**
如果其中一个服务器需要临时的移除，需要标记为down以保留当前的客户端IP地址哈希。

例子：
``` nginx
upstream backend {
    ip_hash;

    server backend1.example.com;
    server backend2.example.com;
    server backend3.example.com down;
    server backend4.example.com;
}
```
直到1.3.1和1.2.2版本，不能为使用ip_hash负载均衡的服务器指定权重。
### keeplive
``` nginx
    Syntax:	keepalive connections;
    Default:	—
    Context:	upstream
    指令自动版本1.1.4.
```
为连接到上游服务器的连接开启缓存。
connections参数设置与upstream服务器的空闲保持连接的最大数量，这些连接保留在每个工作进程的缓存中。如果超过此数字，则关闭最近使用的连接。
``` txt
应该特别注意的是，keepalive指令不限制nginx工作进程可以打开的upstream服务器的连接总数。连接参数应该设置为足够小的数字，以便upstream服务器也可以处理新的传入连接。
```
memcached upstream服务器使用keepalive连接的示例配置：
``` nginx
    upstream memcached_backend {
        server 127.0.0.1:11211;
        server 10.0.0.2:11211;

        keepalive 32;
    }

    server {
        ...

        location /memcached/ {
            set $memcached_key $uri;
            memcached_pass memcached_backend;
        }

    }
```
对于HTTP，proxy_http_version指令应设置为“1.1”，“Connection”头需要清空：
``` nginx
    upstream http_backend {
        server 127.0.0.1:8080;

        keepalive 16;
    }

    server {
        ...

        location /http/ {
            proxy_pass http://http_backend;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            ...
        }
    }
```
或者，HTTP/1.0持久连接可以通过传递“Connection: Keep-Alive”头域到上游服务器，但这种方法不推荐。
### keepalive_requests
``` nginx
Syntax:	keepalive_requests number;
Default:	keepalive_requests 100;
Context:	upstream
# 这个指令自从版本1.15.3.
```
设置一个keeplive连接可以通过最大的请求数量，如果此连接发送的请求数量超过这个值，将会被关闭。
### keepalive_timeout
``` nginx
    Syntax:	keepalive_timeout timeout;
    Default:	keepalive_timeout 60s;
    Context:	upstream
    # 指令自从版本1.15.3.
```
 设置空闲连接如果在指定的时间内没有发送请求就关闭这个连接。
 ### ntlm
 ``` nginx
 Syntax:	ntlm;
Default:	—
Context:	upstream
# 指令在版本1.9.2之后。
 ```
允许代理请求使用NTLM验证。上游连接需要客户端连接发送请求的“Authorization”字段值以“Negotiate”或“NTLM”开头。后面的客户端请求需要通过同一个上游连接进行代理，保持认证上下文。

为了使NTLM验证工作，需要启用与上游服务器的keepalive连接。proxy_http_version指令需要设置为“1.1”，“Connection”头域需要清空：
``` nginx
upstream http_backend {
    server 127.0.0.1:8080;

    ntlm;
}

server {
    ...

    location /http/ {
        proxy_pass http://http_backend;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        ...
    }
}
```
当使用除了轮询方式的负载均衡方法，需要在ntlm指令之前激活他们。
**该指令为商业版本的一部分。**
### least_conn
``` nginx
Syntax:	least_conn;
Default:	—
Context:	upstream
# 这个指令出现在1.3.1 and 1.2.2之后.
```
指定服务器组使用负载平衡方法：首先将请求传递到活动连接数最少的服务器，同时考虑服务器的权重。如果有多个连接数相同的服务器，则使用加权循环平衡方法依次尝试它们。

### 内嵌变量
ngx_http_upstream_module模块支持以下内嵌变量：
```
$upstream_addr
 保存upstream服务器的IP地址和端口号，或UNIX-domain socket路径。如果在处理请求时有多个服务器参与，它们的地址会用逗号分割，例如“192.168.1.1:80, 192.168.1.2:80, unix:/tmp/sock”。如果从一个服务器组发生了内部重定向，由“X-Accel-Redirect”发起或error_page，那么服务器地址不同的组会使用冒号分割，例如“192.168.1.1:80, 192.168.1.2:80, unix:/tmp/sock : 192.168.10.1:80, 192.168.10.2:80”。

$upstream_bytes_received
从upstream服务器接收到字节数（从本1.11.4开始）。来自多个连接的值会由逗号和冒号分隔，如$upstream addr变量中的地址。

$upstream_bytes_sent
发送给upstream服务器的字节数(从版本1.15.8开始)。来自多个连接的值会由逗号和冒号分隔，如$upstream addr变量中的地址。

$upstream_cache_status
保存访问缓存响应的状态（从版本0.8.3+）。状态可以是“MISS”, “BYPASS”, “EXPIRED”, “STALE”, “UPDATING”, “REVALIDATED”或“HIT”。

$upstream_connect_time
保留与upstream服务器建立连接花费的时间（1.9.1+）。时间为秒数精确到毫秒。如果是SSL，包含握手的时间消耗。多个连接的时间通过逗号和冒号分割，就像$upstream_addr变量中的地址一样。

$upstream_cookie_name
upstream服务器在“set cookie”响应头字段中发送的具有指定name的cookie。（1.7.1+）。只有最后一个服务器响应的cookie会被保存。

$upstream_header_time
保存从upstream服务器收到响应头的时间花费（1.7.10+）。时间为秒数精确到毫秒。多个响应的时间以逗号分割，就像$upstream_addr变量中的地址。

$upstream_http_name
保存服务器响应头。例如，“Server”响应头可以通过$upstream_http_server变量使用。转换头域名称到变量名称的规则与“$http_”前缀开头的变量相同。只有最后一个服务器响应头的头域会保存。
```
## 参考
1. [ngx_http_upstream_module](http://nginx.org/en/docs/http/ngx_http_upstream_module.html#zone)
2. [nginx中文文档-ngx_http_upstream_module](https://blog.lyz810.com/article/2016/05/ngx_http_upstream_module_doc_zh-cn/)
3. [Nginx负载均衡－如何自定义URL中的hash key](http://www.imooc.com/article/19980#)
