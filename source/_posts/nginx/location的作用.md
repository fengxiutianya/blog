---
title: location的作用
tags:
  - nginx
categories:
  - nginx
abbrlink: 764b901a
date: 2019-03-09 12:33:00
---
## location的作用
location指令的作用是根据用户请求URI来执行不同的应用，location会根据用户请求网站URL进行匹配定位到某个location区块。 如果匹配成功将会处理location块的规则。

## location的语法规则如下
```
location  =     /uri
   ┬      ┬       ┬
   │      │       │
   │      │       │
   │      │       │
   │      │       │
   │      │       └─────────────── 前缀|正则
   │      └──────────────────── 可选的修饰符（用于匹配模式及优先级）
   └───────────────────────── 必须
```
<!-- more -->
## 修饰符说明及优先级顺序
优先级的高低表示优先匹配顺讯，可理解为编程当中的switch语法。下面列表从上到下，第一个优先级最高。
``` 
=      |   location =  /uri
^~     |   location ^~ /uri
~      |   location ~  pattern
~*     |   location ~* pattern
/uri   |   location /uri
@      |   location @err
```
**`=` ，精确匹配，表示严格相等,区分大小写**
```nginx
location = /static {
  default_type text/html;
  return 200 "hello world";
}

# http://localhost/static   [成功]
# http://localhost/Static   [失败]
```

**`^~` ，匹配以URI开头，对大小写敏感**
```  nginx
location ^~ /static {
  default_type text/html;
  return 200 "hello world";
}

# http://localhost/static/1.txt    [成功]
# http://localhost/Static/1.txt    [失败]
# http://localhost/public/1.txt    [失败]
```

**`~`，使用正则表达式，对大小写敏感。注意：某些操作系统对大小写敏感是不生效的，比如windows操作系统**
``` nginx
location ~ ^/static$ {
   default_type text/html;
  return 200 "hello world";
}

# http://localhost/static         [成功]
# http://localhost/static?v=1     [成功] 忽略查询字符串
# http://localhost/STATic         [失败]
# http://localhost/static/        [失败] 多了斜杠
```

**`~*`，与`~`相反，忽略大小写敏感, 使用正则**
``` nginx
location ~* ^/static$ {
  default_type text/html;
  return 200 "hello world";
}

# http://localhost/static         [成功]
# http://localhost/static?v=1     [成功] 忽略查询字符串
# http://localhost/STATic         [成功]
# http://localhost/static/        [失败] 多了斜杠
```

**`/uri` ，匹配以`/uri`开头的地址**
``` nginx
location  /static {
  default_type text/html;
  return 200 "hello world";
}

# http://localhost/static              [成功]
# http://localhost/STATIC?v=1          [成功]
# http://localhost/static/1            [成功]
# http://localhost/static/1.txt        [成功]
```

**`@` 用于定义一个Location块，且该块不能被外部Client所访问，只能被nginx内部配置指令所访问，比如 try_files or error_page**
``` nginx
location  / {
  root   /root/;
  error_page 404 @err;
}
location  @err {
  default_type text/html;
  return 200 "err";
}

# 如果 http://localhost/1.txt 404，将会跳转到@err并输出err
```
## 理解优先级
**注意：优先级不是编辑location前后顺序**
``` nginx
server {
  listen      80;
  server_name  localhost;

  location  ~ .*\.(html|htm|gif|jpg|pdf|jpeg|bmp|png|ico|txt|js|css)$ {
    default_type text/html;
    return 200 "~";
  }

  location ^~ /static {
    default_type text/html;
    return 200 "^~";
  }

  location / {
    root   /Users/xiejiahe/Documents/nginx/nginx/9000/;
    error_page 404 @err;
  }

  location = /static {
    default_type text/html;
    return 200 "=";
  }

  location ~* ^/static$ {
    default_type text/html;
    return 200 "~*";
  }

  location @err {
    default_type text/html;
    return 200 "err";
  }
}
```
1. `http://localhost/static` 会输出什么？输出了`=`，因为`=`表示严格相等，而且优先级是最高
2. `http://localhost/static/1.txt` 输出什么？输出`^~`， 匹配前缀为`/static`

所以实际使用中，个人觉得至少有三个匹配规则定义，如下：
1. 直接匹配网站根目录，通过域名访问网站首页比较频繁，使用这个会加速处理，比如官网首页。这里里是直接转发给后端应用服务器了，也可以是一个静态首页
   ```nginx
   location = / {
   	proxy_pass http://tomcat:8080/index
   }
   ```
2.  第二个必选规则是处理静态文件请求，这是nginx作为http服务器的强项
    有两种配置模式，目录匹配或后缀匹配,任选其一或搭配使用
    ```nginx
      location ^~ /static/ {
      	  root /webroot/static/；
      }
      location ~* .(gif|jpg|jpeg|png|css|js|ico)$ {
        	root /webroot/res/;
      }
    ```

3. 第三个规则就是通用规则，用来转发动态请求到后端应用服务器，非静态文件请求就默认是动态请求，自己根据实际把握
   ``` nginx
   location / {
   	 proxy_pass http://tomcat:8080/
   }
   ```

## 参考

1. [Nginx配置location详解](https://www.jianshu.com/p/653d2ce0caf3)
2. [nginx - location配置详解第一篇](https://juejin.im/entry/5b10a08ae51d4506ca62b5ec)