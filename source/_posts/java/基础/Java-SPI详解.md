---
title: Java SPI详解
categories:
  - java
  - 基础
abbrlink: '22420980'
date: 2019-05-30 10:23:26
tags: 
  - SPI
  - java基础
---
## 什么是SPI
SPI全称为 (Service Provider Interface) ，是JDK内置的一种服务提供发现机制。SPI是一种动态替换发现的机制，比如有个接口，想运行时动态的给它添加实现，你只需要添加一个实现。我们经常遇到的就是java.sql.Driver接口，不同厂商可以针对同一接口做出不同的实现，mysql和postgresql都有不同的实现提供给用户，而Java的SPI机制可以为某个接口寻找服务实现。
![1635dec2151e31e](/images/1635dec2151e31e4)
类图中，接口是定义的抽象SPI接口；实现方实现SPI接口；调用方依赖SPI接口。
SPI接口的定义在调用方，在概念上更依赖调用方；组织上位于调用方所在的包中；实现位于独立的包中。
当接口属于实现方的情况，实现方提供了接口和实现，这个用法很常见，属于API调用。我们可以引用接口来达到调用某实现类的功能。
<!-- more -->
## Java SPI应用案例
当服务的提供者提供了一种接口的实现之后，需要在classpath下的META-INF/services/目录里创建一个以服务接口命名的文件，这个文件里的内容就是这个接口的具体的实现类。当其他的程序需要这个服务的时候，就可以通过查找这个jar包（一般都是以jar包做依赖）的META-INF/services/中的配置文件，配置文件中有接口的具体实现类名，可以根据这个类名进行加载实例化，就可以使用该服务了。JDK中查找服务实现的工具类是：java.util.ServiceLoader。

下面演示一个简单demo，我们知道搜索可以在本地文件搜索，也可以在数据库搜索，当然还有其他的，这个demo定义了一个搜索接口，由不同的实现方来实现不同的搜索方式。具体代码如下
定义搜索接口
``` java
/**************************************
 *      Author : zhangke
 *      Date   : 2018/9/30 09:45
 *      email  : 398757724@qq.com
 *      Desc   : 搜索接口
 ***************************************/
public interface Search {
    public List<String> searchDoc(String keyWord);
}
```
下面是俩个实现了这个接口的类：第一个是基于文件搜索，第二个是基于数据库搜索
``` java
/**************************************
 *      Author : zhangke
 *      Date   : 2018/9/30 09:46
 *      email  : 398757724@qq.com
 *      Desc   : 文件搜索
 ***************************************/
public class FileSearch implements Search {
    @Override
    public List<String> searchDoc(String keyWord) {
        System.out.println("文件搜索 " + keyWord);
        return null;
    }
}
```
基于数据库搜索
``` java
public class DatabaseSearch implements Search {
    @Override
    public List<String> searchDoc(String keyWord) {
        System.out.println("数据库搜索：" + keyWord);
        return null;
    }
}
```
### 增加META-INF目录文件
Resources下面创建META-INF/services目录里创建一个以服务接口命名的文件
![Xnip2019-05-30_11-10-34](/images/Xnip2019-05-30_11-10-34.jpg)

### 调用实现类
```java
    public static void main(String[] args) {
        ServiceLoader<Search> s = ServiceLoader.load(Search.class);
        Iterator<Search> iterator = s.iterator();

        while (iterator.hasNext()) {
            Search search = iterator.next();
            System.out.println(search);
            search.searchDoc("hello world");
        }
    }
``` 
运行结果
```
com.zhangke.service.FileSearch@28ba21f3
文件搜索 hello world
com.zhangke.service.DatabaseSearch@694f9431
数据库搜索：hello world
```
这里是一个非常简单的SPI demo，主要是为了讲解如何使用SPI。

## SPI用途
数据库DriverManager、Spring、ConfigurableBeanFactory等都用到了SPI机制，这里以数据库DriverManager为例，看一下其实现的内幕。
DriverManager是jdbc里管理和注册不同数据库driver的工具类。针对一个数据库，可能会存在着不同的数据库驱动实现。我们在使用特定的驱动实现时，不希望修改现有的代码，而希望通过一个简单的配置就可以达到效果。
在使用mysql驱动的时候，会有一个疑问，DriverManager是怎么获得某确定驱动类的？我们在运用Class.forName("com.mysql.jdbc.Driver")加载mysql驱动后，就会执行其中的静态代码把driver注册到DriverManager中，以便后续的使用。
在JDBC4.0之前，连接数据库的时候，通常会用Class.forName("com.mysql.jdbc.Driver")这句先加载数据库相关的驱动，然后再进行获取连接等的操作。而JDBC4.0之后不需要Class.forName来加载驱动，直接获取连接即可，这里使用了Java的SPI扩展机制来实现。
在java中定义了接口java.sql.Driver，并没有具体的实现，具体的实现都是由不同厂商来提供的。
### mysql
在mysql-connector-java-5.1.45.jar中，META-INF/services目录下会有一个名字为java.sql.Driver的文件：
``` java
com.mysql.jdbc.Driver
com.mysql.fabric.jdbc.FabricMySQLDriver
```
### pg
而在postgresql-42.2.2.jar中，META-INF/services目录下会有一个名字为java.sql.Driver的文件：
```
org.postgresql.Driver
```
### 用法
``` java
String url = "jdbc:mysql://localhost:3306/test";
Connection conn = DriverManager.getConnection(url,username,password);
```
上面展示的是mysql的用法，pg用法也是类似。不需要使用Class.forName("com.mysql.jdbc.Driver")来加载驱动。
### Mysql DriverManager实现
上面代码没有了加载驱动的代码，我们怎么去确定使用哪个数据库连接的驱动呢？这里就涉及到使用Java的SPI扩展机制来查找相关驱动的东西了，关于驱动的查找其实都在DriverManager中，DriverManager是Java中的实现，用来获取数据库连接，在DriverManager中有一个静态代码块如下：
``` java
static {
	loadInitialDrivers();
	println("JDBC DriverManager initialized");
}
````
可以看到其内部的静态代码块中有一个loadInitialDrivers方法，loadInitialDrivers用法用到了上文提到的spi工具类ServiceLoader:
```
    public Void run() {

        ServiceLoader<Driver> loadedDrivers = ServiceLoader.load(Driver.class);
        Iterator<Driver> driversIterator = loadedDrivers.iterator();

        /* Load these drivers, so that they can be instantiated.
         * It may be the case that the driver class may not be there
         * i.e. there may be a packaged driver with the service class
         * as implementation of java.sql.Driver but the actual class
         * may be missing. In that case a java.util.ServiceConfigurationError
         * will be thrown at runtime by the VM trying to locate
         * and load the service.
         *
         * Adding a try catch block to catch those runtime errors
         * if driver not available in classpath but it's
         * packaged as service and that service is there in classpath.
         */
        try{
            while(driversIterator.hasNext()) {
                driversIterator.next();
            }
        } catch(Throwable t) {
        // Do nothing
        }
        return null;
    }
```
遍历使用SPI获取到的具体实现，实例化各个实现类。在遍历的时候，首先调用driversIterator.hasNext()方法，这里会搜索classpath下以及jar包中所有的META-INF/services目录下的java.sql.Driver文件，并找到文件中的实现类的名字，此时并没有实例化具体的实现类。

<!-- ## ServiceLoader 源码分析
下面一起看看ServiceLoader的源码，其实相对来说就是要实现以下功能，在`META-INF/services`目录下找到给定的class对应的文件，并将其中每个实现类加载到JVM中。下面我们来看看是如何实现的。
### 创建ServiceLoader对象
```java
  public static <S> ServiceLoader<S> load(Class<S> service,
                                          ClassLoader loader)
  {
      return new ServiceLoader<>(service, loader);
  }
```
主要是调调用上面的方法，然后 -->


## 参考
[Java SPI机制详解](https://juejin.im/post/5af952fdf265da0b9e652de3)
