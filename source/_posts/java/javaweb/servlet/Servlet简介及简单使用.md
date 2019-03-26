---
title: Servlet简介以及简单使用
abbrlink: d42e6e40
categories:
  - java
  - javaweb
  - servlet
date: 2019-03-24 20:30:34
tags: 
  - servlet
copyright:
---
## Servlet简介
如果你打开Java EE官方文档，你就会看看Servlet其实就是一个接口，只不过这个接口是由Java委员会预先定义好的，如果你想使用java开发web程序，就必须遵守这个约定。按照一种约定俗成的称呼习惯，通常我们也把实现了servlet接口的java程序，称之为Servlet。所以Servlet没什么神秘的，你可以简单的把它当做一个普通的类，只不过这个类实现了Servlet接口。

本文会按照如下思路来进行讲解，首先写一个Servlet版的Hello World，然后介绍servlet的运行流程以及生命周期，为后面文章打下基础。
<!-- more -->
## Servlet简单使用
``` java
public class Hello extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        
        PrintWriter p = resp.getWriter();
        p.write("hello world!");
        p.flush();
    }
}
```
上面代码演示了一个简单的Servlet，打印“hello Wworld!”到浏览器。从上面的doGet函数中，我们可以看出，其实就是通过IO流向外输出内容，只不过这次输出流比较特殊，是向网络输出流。但是这样写完，是访问不了的，还需要为这个Servlet配置访问路径，配置的方式是在Web.xml文件中，而web.xml文件是Java web项目中的一个配置文件，主要用于配置欢迎页、Filter、Listener、Servlet等。下面我们来配置上面Servlet对应的访问路径。源码如下：
``` xml
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns="http://xmlns.jcp.org/xml/ns/javaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee
         http://xmlns.jcp.org/xml/ns/javaee/web-app_3_1.xsd"
         version="3.1" metadata-complete="true">

    <servlet>
        <servlet-name>hello</servlet-name>
        <servlet-class>controller.Hello</servlet-class>
    </servlet>

    <servlet-mapping>
        <servlet-name>hello</servlet-name>
        <url-pattern>/</url-pattern>
    </servlet-mapping>
</web-app>
```
这里先不解释Web.xml中所有的配置，我们讲到Servlet对应部分的时候，会讲其相对应的在Web.xml中如何配置，这样便于理解，最后在完整的讲解Web.xml中的配置，具体的可以看这篇文章[web.xml配置详解](/posts/85b1c334/)。

将上面的代码打包部署到java的web容器中，就可以访问。效果如下：
![Xnip2019-03-25_14-48-05](/images/Xnip2019-03-25_14-48-05.jpg)
这里我省略了如何部署项目，其实很简单，在网上搜一下就会明白，因此就不在这里具体的讲解。

从上面的小demo中可以看出，用户若想开发一个动态web资源(即开发一个Java程序向浏览器输出数据)，需要完成以下2个步骤：
1. 编写一个Java类，实现servlet接口。
2. 把开发好的Java类部署到web服务器中。

## Servlet运行流层以及生命周期
我们先来看看，一个Servlet是如何在Web服务器中被调用的，如果理解了这个流程，那么就很容易明白Servlet的生命周期。在web应用服务器接收到客户端的请求后，会按照以下流程来调用相对应的Servlet程序：
1. Web服务器首先检查是否已经装载并创建了该Servlet的实例对象。如果是，则直接执行第④步，否则，执行第②步。
2. 装载并创建该Servlet的一个实例对象。 
3. 调用Servlet实例对象的init()方法。
4. 创建一个用于封装HTTP请求消息的HttpServletRequest对象和一个代表HTTP响应消息的HttpServletResponse对象，然后调用Servlet的service()方法并将请求和响应对象作为参数传递进去。
5. WEB应用程序被停止或重新启动之前，Servlet引擎将卸载Servlet，并在卸载之前调用Servlet的destroy()方法。 

与上面步骤相对应的流程图如下：
![311054556978749](/images/311054556978749.png)
### Servlet生命周期
有了上面Servlet调用的整个过程，Servlet生命周期就相对来说好理解写。Servlet生命周期可被定义为从创建直到毁灭的整个过程。以下是Servlet遵循的过程：
1. Servlet 通过调用 init () 方法进行初始化。
2. Servlet 调用 service() 方法来处理客户端的请求。
3. Servlet 通过调用 destroy() 方法终止（结束）。
4. 最后，Servlet 是由 JVM 的垃圾回收器进行垃圾回收的。

现在让我们详细讨论生命周期的方法。
#### init() 方法
init方法被设计成只调用一次。它在第一次创建Servlet对象时被调用，在后续每次用户请求时不再调用。因此，它是用于一次性初始化。

Servlet创建于用户第一次调用对应于该Servlet对应的URL时，但是您也可以指定Servlet在服务器第一次启动时被加载，后面会讲解。

当用户调用一个Servlet时，就会创建一个Servlet实例,但如果已经创建过该Servlet对应的S对象。就不会在创建，因此，在整个web应用的声明周期中（其实就是开启应用到关闭应用），每一个Servlet只会创建一次对象，以后都复用之前的对象。有点像单例模式。init()方法简单地创建或加载一些数据，这些数据将被用于Servlet的整个生命周期。

init 方法的定义如下：
``` java
public void init() throws ServletException {
  // 初始化代码...
}
```
#### service() 方法
service()方法是执行实际任务的主要方法。Servlet容器（即Web服务器）调用service()方法来处理来自客户端（浏览器)的请求，并把格式化的响应写回给客户端。

每次服务器接收到一个Servlet请求时，服务器会产生一个新的线程并调用服务。service()方法检查HTTP请求类型（GET、POST、PUT、DELETE 等），并在适当的时候调用 doGet、doPost、doPut，doDelete 等方法。

下面是该方法的特征：
``` java
public void service(ServletRequest request, 
                    ServletResponse response) 
      throws ServletException, IOException{
}
```
service()方法由容器调用，service方法在适当的时候调用doGet、doPost、doPut、doDelete等方法。所以，您不用对 service() 方法做任何动作，您只需要根据来自客户端的请求类型来重写doGet()或doPost()即可。

doGet()和 doPost()方法是每次服务请求中最常用的方法。下面是这两种方法的特征。

##### doGet() 方法
GET请求来自于一个URL的正常请求，或者来自于一个未指定METHOD的HTML表单，它由doGet() 方法处理。
``` java
public void doGet(HttpServletRequest request,
                  HttpServletResponse response)
    throws ServletException, IOException {
    // Servlet 代码
}
```
##### doPost() 方法
POST请求来自于一个特别指定了METHOD为POST的HTML表单，它由doPost()方法处理。
``` java
public void doPost(HttpServletRequest request,
                   HttpServletResponse response)
    throws ServletException, IOException {
    // Servlet 代码
}
```
#### destroy() 方法
destroy()方法只会被调用一次，在Servlet生命周期结束时被调用。destroy()方法可以让您的Servlet关闭数据库连接、停止后台线程、把Cookie列表或点击计数器写入到磁盘，并执行其他类似的清理活动。

在调用destroy()方法之后，servlet对象被标记为垃圾回收。destroy方法定义如下所示：
``` java
  public void destroy() {
    // 终止化代码...
  }
```
#### Servlet架构图
1. 第一个到达服务器的HTTP请求被委派到 Servlet 容器。
2. Servlet容器在调用service()方法之前加载Servlet。
3. 然后Servlet容器使用一个请求对应一个线程的方案来处理请求，每个线程执行一个单一的 Servlet实例的service()方法，前面已经说过，如果当前请求的Servlet对象已经创建，则复用此对象，因此会出现多个线程操作同一个Servlet对象的情况，因此需要考虑线程安全问题。
![Servlet-LifeCycle](/images/Servlet-LifeCycle.jpg)

## 参考
1. [javaweb学习总结(五)——Servlet开发(一)](https://www.cnblogs.com/xdp-gacl/p/3760336.html)
2. [Servlet 生命周期](http://www.runoob.com/servlet/servlet-life-cycle.html)