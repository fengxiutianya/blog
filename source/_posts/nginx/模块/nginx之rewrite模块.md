---
title: nginx之rewrite模块
abbrlink: 4123ac31
categories:
  - nginx
  - 模块
tags:
  - nginx
  - 重定向
date: 2019-04-08 15:17:04
---
**ngx_http_rewrite_module**模块用于使用pcre正则表达式更改请求URI、返回重定向和有条件地选择配置。此模块主要有下面几个指令：`break`,`if`,`return`,`rewrite`和`set`指令，这些指令按照以下顺序被执行：
1.  首先按照顺序执行server上下文中的rewrite模块指令。
2.  循环执行以下指令
    1.  依据请求的URI，匹配定义对应的location
    2.  按照顺序执行匹配到的location中的rewrite模块指令
    3.  如果请求被重写，将进入下一次的循环，但是循环的次数不能超过10次。

<!--  more  -->
## 指令讲解
下面分别看看上面的每个指令：

### break

停止执行 ngx_http_rewrite_module 的指令集，但是其他模块指令是不受影响的。

```nginx
Syntax:	break;
Default:	—
Context:	server, location, if
```

例子：

```nginx
server {
    listen 8080;
    # 此处 break 会停止执行 server 块的 return 指令(return 指令属于rewrite模块)
    # 如果把它注释掉 则所有请求进来都返回 ok
    break;
    return 200 "ok";
    location = /testbreak {
        break;
        return 200 $request_uri;
        proxy_pass http://127.0.0.1:8080/other;
    }
    location / {
        return 200 $request_uri;
    }
}
```

发送请求和得到的结果如下：

```bash
curl 127.0.0.1:8080/testbreak
/other
```

可以看到 返回 `/other` 而不是 `/testbreak`，说明 `proxy_pass` 指令还是被执行了，也就是说 其他模块的指令是不会被 break 中断执行的(proxy_pass是ngx_http_proxy_module的指令)

### if

依据指定的条件决定是否执行 if 块语句中的内容。里面可以设置其他模块的指令，但是必须是if指令所在上下文中存在的指令。

```nginx
Syntax:	if (condition) { ... }
Default:	—
Context:	server, location
```

#### if 中的几种 判断条件

1. 一个`变量名`，如果变量 $variable 的值为空字符串或者字符串"0"，则为false
2. `变量`与一个字符串的比较相等为(=) 不相等为(!=) 
3. `变量`与一个正则表达式的模式匹配 操作符可以是(`~` 区分大小写的正则匹配， `~*`不区分大小写的正则匹配，` !~``!~*`，前面两者的非)
4. 检测文件是否存在 使用 `-f`(存在) 和 `!-f`(不存在)
5. 检测路径是否存在 使用 `-d`(存在) 和 `!-d`(不存在) 后面判断可以是字符串也可是变量
6. 检测文件、路径、或者链接文件是否存在 使用 `-e`(存在) 和 `!-e`(不存在) 后面判断可以是字符串也可是变量
7. 检测文件是否为可执行文件 使用 `-x`(可执行) 和 `!-x`(不可执行) 后面判断可以是字符串也可是变量

注意 上面 第1，2，3条被判断的必须是变量， 4, 5, 6, 7则可以是变量也可是字符串

```nginx
set $variable "0"; 
if ($variable) {
    # 不会执行，因为 "0" 为 false
    break;            
}

# 使用变量与正则表达式匹配 没有问题
if ( $http_host ~ "^star\.igrow\.cn$" ) {
    break;            
}

# 字符串与正则表达式匹配 报错
if ( "star" ~ "^star\.igrow\.cn$" ) {
    break;            
}
# 检查文件是否存在 字符串与变量均可
if ( !-f "/data.log" ) {
    break;            
}

if ( !-f $filename ) {
    break;            
}
```

### return

停止处理并将指定的code码返回给客户端。在不发送响应头的情况下关闭连接则设置code码为444（这个是nginx特有的，不一定适用于其他的服务器）。

从0.8.42版开始，可以指定重定向URL（code码为301、302、303、307和308）或响应正文文本（不是前面的重定向或者444code码）。响应正文文本和重定向URL可以包含变量。在特殊情况下，可以将重定向URL指定为此服务器的本地URI，在这种情况下，重定向的完整URL是根据请求方案（$scheme）和重定向指令中的server_name_in_redirect和port_in_redirect来形成。

此外，可以只设置URl参数，不过这样的指令返回的code码都是302.可以将代码为302。这样的参数以“http://”、“https://”或“$scheme”字符串开头。URL可以包含变量。

在版本0.7.51之前可以使用以下code码：204、400、402-406、408、410、411、413、416和500-504。

直到版本1.1.16和1.0.13，code码307才被视为重定向。

直到版本1.13.0，code码308才被视为重定向。

```nginx
Syntax:	return code [text];
        return code URL;
        return URL;
Default:	—
Context:	server, location, if
```

例子如下：

```nginx
# return code [text]; 返回 ok 给客户端
location = /ok {
    return 200 "ok";
}

# return code URL; 临时重定向到 百度
location = /redirect {
    return 302 http://www.baidu.com;
}

# return URL; 和上面一样 默认也是临时重定向
location = /redirect {
    return http://www.baidu.com;
}
```

### rewrite

```nginx
Syntax:	rewrite regex replacement [flag];
Default:	—
Context:	server, location, if
```

如果指定的正则表达式与请求URI匹配，URI将会替换成replacement字符串。rewrite指令按照它们在配置文件中出现的顺序依次执行。可以使用`flag`终止指令的进一步处理。如果替换字符串以“http://”、 “https://” 或“$scheme”开头，则停止处理并将重定向返回到客户端。

这里先看俩个例子，然后在来说rewrite的四个flag

第一种情况 重写的字符串 带`http://`

```nginx
location / {
    # 当匹配 正则表达式 /test1/(.*)时 请求将被临时重定向到 http://www.$1.com
    # 相当于flag 写为 redirect
    rewrite /test1/(.*) http://www.$1.com;
    return 200 "ok";
}
```

在浏览器中输入 

```
127.0.0.1:8080/test1/baidu
```

则临时重定向到 www.baidu.com,后面的 return 指令将没有机会执行.

第二种情况 重写的字符串 不带`http://`

```nginx
location / {
    rewrite /test1/(.*) www.$1.com;
    return 200 "ok";
}
```

发送请求和结果如下

```bash
curl 127.0.0.1:8080/test1/baidu
ok
```

此处没有带http:// 所以只是简单的重写。请求的 uri 由 /test1/baidu 重写为 www.baidu.com。因为会顺序执行 rewrite指令所以下一步执行return指令响应了ok

#### rewrite 的四个 flag

1. `last`
   停止处理当前的`ngx_http_rewrite_module`的指令集，并开始搜索与更改后的`URI`相匹配的`location`;
2. `break`
   停止处理当前的`ngx_http_rewrite_module`指令集，就像上面说的`break`指令一样;
3. `redirect`
   返回302临时重定向。
4. `permanent`
   返回301永久重定向。

```nginx
# 没有rewrite 后面没有任何 flag 时就顺序执行 
# 当 location 中没有 rewrite 模块指令可被执行时 就重写发起新一轮location匹配
location / {
    # 顺序执行如下两条rewrite指令 
    rewrite ^/test1 /test2;
    rewrite ^/test2 /test3;  # 此处发起新一轮location匹配 uri为/test3
}

location = /test2 {
    return 200 "/test2";
}  

location = /test3 {
    return 200 "/test3";
}
```

发送请求和结果如下:

```bash
curl 127.0.0.1:8080/test1
/test3
```

从上面可以看出，在第一个location中，将地址重写成/test3，也就是符合我们说的，如果没有flag时，就顺序执行，然后执行到最后一个时，就去搜索location，返回对应的结果。

#### last 与 break 的区别

last和break一样它们都会终止此location中其他它rewrite模块指令的执行，但是last立即发起新一轮的location 匹配，而break不会。

例子如下：

```nginx
location / {
    rewrite ^/test1 /test2;
    rewrite ^/test2 /test3 last;  # 此处发起新一轮location匹配 uri为/test3
    rewrite ^/test3 /test4;
    proxy_pass http://www.baidu.com;
}

location = /test2 {
    return 200 "/test2";
}  

location = /test3 {
    return 200 "/test3";
}
location = /test4 {
    return 200 "/test4";
}

```

发送请求和结果如下：

```bash
curl 127.0.0.1:8080/test1
/test3 
```

这个结果符合我们的预期，发送了一个新的请求。

当如果将上面的`location /` 改成如下代码

```nginx
location / {
    rewrite ^/test1 /test2;
    # 此处不会发起新一轮location匹配；当是会终止执行后续rewrite模块指令 
    # 重写后的uri为 /more/index.html
    rewrite ^/test2 /more/index.html break;  
    rewrite /more/index\.html /test4; # 这条指令会被忽略

    # 因为proxy_pass 不是rewrite模块的指令 所以它不会被 break终止
    proxy_pass https://www.baidu.com;
}
```

浏览器输入`127.0.0.1:8080/test1`,代理到百度产品大全页面`https://www.baidu.com/more/index.html`;也就是请求地址重写。但是不会重新发送新一轮的请求。类如上面如果美欧proxy_pass指令，使用同样的请求将返回404。

但是，如果这些指令放在location为`/download/`下，最后一个标志应该替换为break，否则nginx将进行10次循环并返回500个错误：

```nginx
location /download/ {
    rewrite ^(/download/.*)/media/(.*)\..*$ $1/mp3/$2.mp3 break;
    rewrite ^(/download/.*)/audio/(.*)\..*$ $1/mp3/$2.ra  break;
    return  403;
}
```

#### rewrite 后的请求参数

如果替换字符串`replacement`包含新的请求参数，则在它们之后附加先前的请求参数。如果你不想要之前的参数，则在替换字符串 `replacement` 的末尾放置一个问号，避免附加它们。

```nginx
# 由于最后加了个 ?，原来的请求参数将不会被追加到rewrite之后的url后面 
rewrite ^/users/(.*)$ /show?user=$1? last;
```

### rewrite_log

```nginx
Syntax:	rewrite_log on | off;
Default:	rewrite_log off;
Context:	http, server, location, if
```

开启或者关闭 `rewrite`模块指令执行的日志，如果开启，则重写将记录下`notice` 等级的日志到`nginx` 的 `error_log`中，默认为关闭 `off`

### set

```nginx
Syntax:	set $variable value;
Default:	—
Context:	server, location, if
```

设置指定变量的值。变量的值可以包含文本，变量或者是它们的组合形式。

```nginx
location / {
    set $var1 "host is ";
    set $var2 $host;
    set $var3 " uri is $request_uri";
    return 200 "response ok $var1$var2$var3";
}
```

### uninitialized_variable_warn

```nginx
Syntax:	uninitialized_variable_warn on | off;
Default:	uninitialized_variable_warn on;
Context:	http, server, location, if
```

控制是否记录有关未初始化变量的警告。默认开启

##  参考

1. [搞懂nginx的rewrite模块](https://segmentfault.com/a/1190000008102599)
2. [Module ngx_http_rewrite_module](http://nginx.org/en/docs/http/ngx_http_rewrite_module.html)

