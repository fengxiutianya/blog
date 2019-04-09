---
title: nginx之负载均衡策略总结
abbrlink: 2fee60ee
tags:
  - nginx
  - upstream
  - 负载均衡
categories:
  - nginx
date: 2019-04-08 20:25:46
---
在nginx中，负载均衡策略主要由以下几种，轮询、加权轮询、ip_hash、least_conn、fair和url_hash。下面将分别介绍每一种。
<!-- more -->
### 轮询
每个请求按时间顺序，依次分配到不同的后端服务器。如果后端某台服务器宕机，故障系统被自动剔除，使用户访问不受影响。
``` nginx
    upstream backend { 
         server 192.168.0.1; 
         server 192.168.0.1; 
    } 
```
### 加权轮询
weight指定轮询的权值，weight值越大，分配到的访问机率越高，此策略主要用于后端每个服务器性能不均的情况下。
``` nginx
upstream backend { 
    server 192.168.0.1 weight=10; 
    server 192.168.0.2 weight=20;

    # 这台服务器性能好 所以设置weight=30 使之被访问的几率最大 
    server 192.168.0.3 weight=30; 
} 
```
### ip_hash
每个请求按访问IP的hash结果分配，这样来自同一个IP的访客固定访问一个后端服务器，可以解决session不能跨服务器的问题。当然如果这个节点不可用了，会发到下个节点，而此时没有session同步的话就注销掉了。
``` nginx
upstream backend { 
## 设置轮询方式为ip_hash
ip_hash; 
server 192.168.0.1:88; 
server 192.168.0.1:80; 
} 
```
### least_conn
请求被发送到当前活跃连接最少的后端服务器。会考虑weight的值。如果有多个后端服务器的Connection值同为最小的，那么对它们采用加权轮询算法（weight）。
``` nginx
upstream backend {
    least_conn;
    server 192.168.0.1:88; 
    server 192.168.0.1:80; 
}
```
### fair（upstream_fair模块）
根据后端服务器的响应时间来分配请求，响应时间短的优先分配。Nginx本身是不支持fair的，如果需要使用这种调度算法，必须下载Nginx的upstream_fair模块。
``` nginx
upstream backend { 
    server 192.168.0.14:88; 
    server 192.168.0.15:80; 
    fair; 
} 
```
### url_hash（nginx _upstream_hash模块）
此方法按访问url的hash结果来分配请求，使每个url定向到同一个后端服务器，可以进一步提高后端缓存服务器的效率。Nginx本身是不支持url_hash的，如果需要使用这种调度算法，必须下载 Nginx 的 nginx_upstream_hash 模块。
``` nginx
upstream backend { 
    server 192.168.0.1; 
    server 192.168.0.2; 
    hash $request_uri; 
    hash_method crc32;  
} 
```
本篇文章只是简单的总结了nginx中的负载均衡，如果希望了解负载均衡的详细配置，可以看这篇文章
[nginx之upstream(负载均衡)模块](/posts/4b64784d/)