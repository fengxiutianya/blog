---
title: 配置github pages 个人域名
tags:
  - 建站
categories:
  - 建站
abbrlink: 7f3bd1c7
date: 2019-03-15 08:56:00
---
# 配置github pages 个人域名

 **向你的 Github Pages 仓库添加一个CNAME(一定要\*大写\*)文件**

其中只能包含一个顶级域名，像这样：

```text
example.com

```
<!-- more -->
注意上面是俩行，其中一行是空行，这个是必不可少的。一定要有。否则会遇到下面错误

```
Domain's DNS record could not be retrieved
```

如果你是用 hexo 框架搭建博客并部署到 Github Pages 上，每次

```text
> hexo g
> hexo d
```

后会把你的博客所在目录下 public 文件夹里的东西都推到 Github Pages 仓库上，并且把 CNAME 文件覆盖掉，解决这个问题可以直接把 CNAME 文件添加到 source 文件夹里，这样每次推的时候就不用担心仓库里的 CNAME 文件被覆盖掉了。

**2. 向你的 DNS 配置中添加 3 条记录**

```text
@          A             192.30.252.153
@          A             192.30.252.154
www      CNAME           username.github.io.
```

用你自己的 Github 用户名替换 username

配置 DNS 推荐使用 DNSPOD 的服务，使用国外的 DNS 解析服务可能有被墙的风险。

至于如何使用 DNSPOD 解析域名，参考

http://jingyan.baidu.com/article/546ae1857c4ee81149f28cbe.htmljingyan.baidu.com

**3. 等待你的 DNS 配置生效**

对DNS的配置不是立即生效的，过10分钟再去访问你的域名看看有没有配置成功 

**4. 启用 HTTPS**

自 2018 年 5 月 1 日，Github 支持自定义域名的 HTTPS 请求了。

详情见：https://blog.github.com/2018-05-01-github-pages-custom-domains-https/blog.github.com

配置也相当简单，只需要更新 DNS 配置里的 A 记录，将其指向以下4个 IP 地址中的至少一个。

- 185.199.108.153
- 185.199.109.153
- 185.199.110.153
- 185.199.111.153

HTTPS 让你的网站和网站访客更安全，并且 Github 提供的这些 IP 地址自动将你的站点加入了 CDN，提高了访问速度。

你还可以在 GiHub Pages 仓库的设置里勾选 'Enforce HTTPS'，这样所有访问你站点的请求都会走 HTTPS。

不得不说，GitHub 是真的良心。