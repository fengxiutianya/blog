---
title: Servlet开发详解
abbrlink: d40d9fb9
categories:
  - java
  - javaweb
  - servlet
date: 2019-03-25 15:57:52
tags:
  - servlet
copyright:
---
## 概述
上一篇文章已经详细介绍Servlet的开发流程以及生命周期，本篇文章将围绕着如何开发Servlet，
<!-- more -->
## Servlet 
这里我们首先看一下Servlet在Java EE中定义的继承体系，如下图
![servlet](/source/images/servlet.png)
我们进行web的开发，实际上就是在实现Servlet接口，然后写一些逻辑操作。但是每次实现这个接口都要实现大量的方法，这不利于编码。因此官方就提供了了GenericServlet和HttpServlet俩个抽象类，相当于模板，方便对Servlet进行实现。这里多说一句，Servlet并没有要求只能使用HTTP协议来开发web应用，只不过我们经常见到的Servlet都是用于网站后台，也就是使用HTTP协议来进行请求。而我们从Servlet的默认实现类GenericServlet和HttpServlet也可以看出一写端倪。下面来仔细说说这俩个类。

GenericServlet是一个协议无关的Servlet抽象类，任何协议都可以继承这个类。这个抽象类实现了Servlet接口中定义的基本方法，并实现ServletConfig接口，ServletConfig接口用于获取servlet本身的配置信息和Servlet容器的全局配置信息，类如ServletContext，在webx.ml中配置的全局常量等，是被所有的Servlet共用，这些下面都会讲解。

HttpServlet是我们经常使用的，专门为Http协议提供的Servlet。一般情况下，我们只需要继承这个类，覆盖其中需要实现的方法就行，类如init，destroy，do*方法。

下面是开发Servlet通用的模板,具体应用还要具体对待
``` java
public class *Servlet extends HttpServlet {
    @Override
    public void init(ServletConfig config) throws ServletException {
        super.init(config);
        // 这里可以初始化，在整个Servlet生命周期中都可以用到的配置
    }

   // 我们经常使用的方法，主要的业务逻辑都在这里体现，下面do*，代表各种请求方法的处理
    @Override
    protected void do*(HttpServletRequest req, HttpServletResponse resp)  throws ServletException, IOException {

         // 1. 通过HttpServletRequest获取请求信息，并通过其中的输入流获取请求的body
         // 2. 根据请求信息进行对应的处理
         // 3. 通过HttpServletResponsed对象中输出流，将结果输出到浏览器中
    }

    @Override
    public void destroy() {
        super.destroy();
        // 在Servlet销毁时，需要做的逻辑处理
        // 一般这个方法不会用到
    }
}
```
大体上，Servlet开发都会和上面比较类似，具体的demo后面会演示，下面我们主要关注Servlet的URL配置细节。
### Servlet访问URL映射配置
由于客户端是通过URL地址访问web服务器中的资源，所以Servlet程序若想被外界访问，必须把servlet程序映射到一个URL地址上，这个工作在web.xml文件中使用servlet元素和servlet-mapping元素完成。servlet元素用于注册Servlet，它包含有两个主要的子元素：servlet-name和servlet-class，分别用于设置Servlet的注册名称和Servlet的完整类名。
一个servlet-mapping元素用于映射一个已注册的Servlet的一个对外访问路径，它包含有两个子元素：servlet-name和url-pattern，分别用于指定Servlet的注册名称和Servlet的对外访问路径。例如：
``` xml
    <servlet>
        <servlet-name>这个名称用于后面servlet-mapping进行匹配</servlet-name>
        <servlet-class>对应Servlet实现的全路径</servlet-class>
    </servlet>

    <servlet-mapping>
        <servlet-name>和上面Servlet元素中name对应</servlet-name>
        <url-pattern>匹配的路径</url-pattern>
    </servlet-mapping>
```
同一个Servlet可以被映射到多个URL上，即多个<servlet-mapping>元素的<servlet-name>子元素的设置值可以是同一个Servlet的注册名。 例如：
``` xml
  <servlet>
      <servlet-name>ServletDemo1</servlet-name>
      <servlet-class>Servlet路径</servlet-class>
    </servlet>

  <servlet-mapping>
    <servlet-name>ServletDemo1</servlet-name>
    <url-pattern>/servlet/ServletDemo1</url-pattern>
  </servlet-mapping>
 <servlet-mapping>
    <servlet-name>ServletDemo1</servlet-name>
    <url-pattern>/1.htm</url-pattern>
  </servlet-mapping>
   <servlet-mapping>
    <servlet-name>ServletDemo1</servlet-name>
    <url-pattern>/2.jsp</url-pattern>
  </servlet-mapping>
   <servlet-mapping>
    <servlet-name>ServletDemo1</servlet-name>
    <url-pattern>/3.php</url-pattern>
  </servlet-mapping>
   <servlet-mapping>
    <servlet-name>ServletDemo1</servlet-name>
    <url-pattern>/4.ASPX</url-pattern>
  </servlet-mapping>
```
通过上面的配置，当我们想访问名称是ServletDemo1的Servlet，可以使用如下的几个地址去访问：
```
/servlet/ServletDemo1

/1.htm

/2.jsp

/3.php

/4.ASPX
```
ServletDemo1被映射到了多个URL上，这里省略了访问的域名和端口号，在上面地址前面加上这里个就可以访问到同一个Servlet。

**当然我们也可以使用通配符来进行URL映射：**在Servlet映射到的URL中也可以使用"*"通配符，但是只能有两种固定的格式：一种格式是"*.扩展名"，另一种格式是以正斜杠（/）开头并以"/*"结尾。例如：
``` xml
<!-- 情形1 -->
<servlet-mapping>
  <servlet-name>ServletDemo1</servlet-name>
  <url-pattern>*.do</url-pattern>
</servlet-mapping>

<!-- 情形2-->
<servlet-mapping>
  <servlet-name>ServletDemo1</servlet-name>
  <url-pattern>/action/*</url-pattern>
</servlet-mapping>
```
因为*可以匹配任意的字符，对于上面的情形1，下面路径路径都能匹配
```
/abc/dd.do
/aa.do
```
对于情形2，可以匹配到以**/action/**开头的路由地址，下面路径都能匹配
```
/action/test
/action/test.do
```
从上面就引出来一个问题，**/action/test.do**这个路径俩个都能匹配，那应该匹配哪一个呢，简单的说哪个路径匹配的长度更长，则匹配谁：
对于如下的一些映射关系：
```
　　Servlet1 映射到 /abc/* 
　　Servlet2 映射到 /* 
　　Servlet3 映射到 /abc 
　　Servlet4 映射到 *.do 
```
1. 当请求URL为“/abc/a.html”，“/abc/\*”和“/\*”都匹配，Servlet引擎将调用Servlet1。
2. 当请求URL为“/abc”时，“/abc/\*”和“/abc”都匹配，Servlet引擎将调用Servlet3。
3. 当请求URL为“/abc/a.do”时，“/abc/\*”和“*.do”都匹配，Servlet引擎将调用Servlet1。
4. 当请求URL为“/a.do”时，“/\*”和“*.do”都匹配，Servlet引擎将调用Servlet2。
5. 当请求URL为“/xxx/yyy/a.do”时，“/\*”和“*.do”都匹配，Servlet引擎将调用Servlet2。

还一个比较特殊的URL，仅仅为一个正斜杠（/），如果配置了这个Servlet就成为当前Web应用程序的缺省Servlet。 凡是在web.xml文件中找不到匹配的\<servlet-mapping\>元素的URL，它们的访问请求都将交给缺省Servlet处理，也就是说，缺省Servlet用于处理所有其他Servlet都不处理的访问请求。 例如：
``` xml
<servlet>
    <servlet-name>ServletDemo2</servlet-name>
    <servlet-class>gacl.servlet.study.ServletDemo2</servlet-class>
    <load-on-startup>1</load-on-startup>
  </servlet>
  
  <!-- 将ServletDemo2配置成缺省Servlet -->
  <servlet-mapping>
    <servlet-name>ServletDemo2</servlet-name>
    <url-pattern>/</url-pattern>
  </servlet-mapping>
```