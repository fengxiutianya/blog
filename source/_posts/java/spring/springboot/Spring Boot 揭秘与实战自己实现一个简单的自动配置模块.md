---
title: Spring Boot之实现一个简单的自动配置模块
tags:
  - springboot
categories:
  - java
  - spring
  - springboot
abbrlink: 62b625fe
date: 2019-03-11 06:46:00
---
我们知道在使用springboot的时候，都会我们只需要在application.yml或者application.properties中指定配置参数就可以使用，那这是如何实现的，本篇文章就通过一个简单例子来解释springboot是如何实现自动配置。

<!-- more -->
假设，现在项目需要一个功能，需要自动记录项目发布者的相关信息，我们如何通过 Spring Boot 的自动配置，更好的实现功能呢？
### maven 环境搭建

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.zhangke.www</groupId>
    <artifactId>SimpleDemoSpringBootAutoConfiguration</artifactId>
    <version>1.0-SNAPSHOT</version>

    <properties>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <maven.compiler.source>1.8</maven.compiler.source>
        <maven.compiler.target>1.8</maven.compiler.target>
    </properties>
    <packaging>jar</packaging>
    <!--<name>springboot-action-autoconfig</name>-->
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-autoconfigure</artifactId>
            <version>2.0.4.RELEASE</version>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-test</artifactId>
            <version>2.0.4.RELEASE</version>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <version>4.12</version>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.assertj</groupId>
            <artifactId>assertj-core</artifactId>
            <!-- use 2.9.1 for Java 7 projects -->
            <version>3.11.1</version>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-autoconfigure-processor</artifactId>
            <version>2.0.4.RELEASE</version>
            <optional>true</optional>
        </dependency>
    </dependencies>
    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

开发自动配置模块，需要引入spring-boot-autoconfigure这个模块，具体的可以参考[spring boot 官网](https://docs.spring.io/spring-boot/docs/2.0.5.RELEASE/reference/htmlsingle/#boot-features-developing-auto-configuration)

### 参数配置

回想一下，当我们在spring中是如何使用数据库，首先需要创建一个数据库Datasource的Bean，但是我们需要填入数据库连接需要的配置选项，类如数据库用户名，密码等。

参数配置就有点类似于数据库连接中的配置选项，这里的配置参数，可以通过application.yml中直接设置。然后我们可以在需要的地点使用这个配置bean。

具体demo代码如下

```java
@ConfigurationProperties(prefix = "custom")
public class AuthorProperties {
    public static final String DEFAULT_AUTHOR = "LiangGzone";
    public String author = DEFAULT_AUTHOR;
    public String getAuthor() {
        return author;
    }
    public void setAuthor(String author) {
        this.author = author;
    }
}
```

看到上面你应该能想到如何在application.yml配置参数的时候，向下面这样配置，这个属性bean就能正确读到配置

```yaml
custom:
	author = zhangke
```

### 简单服务类--自动记录项目发布者的相关信息

```java
public class AuthorServer {
    public String author;
    
    public String getAuthor() {
        return author;
    }
    public void setAuthor(String author) {
        this.author = author;
    }
}
```

这段代码没什么高级的地点，就是简单的写了一个bean用来记录信息。

### 自动配置的核心 - 自动配置类

```java
@Configuration
@ConditionalOnClass({ AuthorServer.class })
@EnableConfigurationProperties(AuthorProperties.class)
public class AuthorAutoConfiguration {
    
    @Resource
    private AuthorProperties authorProperties;
    
    @Bean
    @ConditionalOnMissingBean(AuthorServer.class)
    public AuthorServer authorResolver() {
        AuthorServer authorServer = new AuthorServer();
      authorServer.setAuthor(authorProperties.getAuthor());
        return authorServer;
    }
}
```

我们一起来看这段代码，首先是类上面的注解：

* **@Configuration ：** 这个没什么好解释的，表明这是一个注解
* **@ConditionalOnClass：**参数中对应的类在 classpath 目录下存在时，才会去解析对应的配置类。因此，我们需要配置 AuthorServer 。
* **@EnableConfigurationProperties：** 用来加载配置参数，所以它应该就是属性参数类 AuthorProperties。

然后看一下类中的注解

* **@Resource:** 将指定的bean添加进来
* **@ConditionalOnMissingBean**,用来确定当IOC容器中没有指定类型的Bean，才会去创建对应的bean
*  **@ConditionalOnProperty**这个主要是用来检测配置文件中`custom.author.enabled`的值是否和

authorResolver方法的作用，即 AuthorProperties 的参数赋值到AuthorServer 中。

从上面我们可以看到，使用了几个`@ConditionalOn*`的注解，这几个注解主要是用来检测某一个条件是否匹配

比较常用的还有下面几个类：

```java
@ConditionalOnWebApplication : web环境
@ConditionalOnNotWebApplication : 条件是当前不是web应用
@ConditionalOnProperty : 检查特定属性是否已经配置了特定值
@ConditionalOnResource : 检查特定的资源是否已经在类路径下
@ConditionalOnMissingClass : 不包含某个类
@ConditionalOnSingleCandidate: 表示只能有一个候选bean，如果超过一个，可以使用@Primary指定首选，这样才不会抛出异常
```

### spring.factories 不要遗漏

我们需要实现自定义自动装配，就需要自定义 spring.factories 参数。所以，我们需要在 `src/main/resources/ META-INF/spring.factories `中配置信息，值得注意的是，这个文件要自己创建。

```yml
# CUSTOM
org.springframework.boot.autoconfigure.EnableAutoConfiguration=\
替换成你当前的包名.AuthorAutoConfiguration表示的是
```

如果你知道SPI，那么就能很容易的理解这段代码，其实就是指定需要加载的类，只不过这个是spring自己实现的一套类似于SPI的标准。spring启动时，会自动解析这个文件。根据条件加载对应的自动配置类。

###  功能打包与配置依赖

好了，我们已经实现了一个简单的自动配置功能。那么，我们需要将这个项目打成 jar 包部署在我们的本地或者私服上。然后，就可以用了。

我们在另外一个项目中，配置 Maven 依赖。

```
<dependency>
    <groupId>com.zhangke.www</groupId>
    <artifactId>springboot-action-autoconfig</artifactId>
    <version>1.0-SNAPSHOT</version>
</dependency>
```

###  测试，测试

第一种测试方法，是你在写一个springboot的web应用，然后写下面这个控制器，检测自动配置是否已经正确实现。

```
@RestController
@EnableAutoConfiguration
public class AuthorAutoConfigDemo {

    @Resource
    private AuthorServer authorServer;

    @RequestMapping("/custom/author")
    String home() {
        return "发布者："+ authorServer.getAuthor();
    }
}
```

运行起来，我们看下打印的发布者信息是什么？

我们在 application.properties 中配置一个信息。

```
#custom
custom.author = zhangke
```

还有一种是springboot2.0新增加的一个特性，直接在当前的项目中写一个测试来判断自动配置功能是否成功。

具体代码如下，

```java
public class autoConfigureTest {

    private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(AuthorAutoConfiguration.class))
            .withPropertyValues("custom.author=zhangke", "custom.author.enabled=true");

    @Test
    public void test() {
        this.contextRunner.run((context) -> {
            assertThat(context).hasSingleBean(AuthorServer.class);
          assertThat(context.getBean(AuthorServer.class).getAuthor()).isEqualTo("zhangke");

        });
    }

}
```

### 继续完善代码--配置元数据

回想一下，当我们在使用IDE编辑application.yml文件时，会有自动提示。这是怎么做出来呢，其实很简单，只需要创建如下文件`src/main/resources/ META-INF/spring-configuration-metadata.json`

具体内容如下

```json
{
  "groups": [
    {
      "name": "custom",
      "type": "simpleDemo.AuthorProperties",
      "sourceType": "simpleDemo.AuthorProperties"
    }
  ],
  "properties": [
    {
      "sourceType": "simpleDemo.AuthorProperties",
      "name": "custom.author",
      "type": "java.lang.String"
    }
  ]
}
```

具体配置可以参考如下链接

[spring boot 官网配置元数据](https://docs.spring.io/spring-boot/docs/current/reference/html/configuration-metadata.html#configuration-metadata-additional-metadata)

[配置元数据](https://blog.csdn.net/L_Sail/article/details/70342023)

另外我们有一些参数可能在配置的时候不需要，并且也很少用到，或者有一些需要废除的配置选项，可以创建如下文件`src/main/resources/ META-INF/additional-spring-configuration-metadata.json`,然后按照上面的格式写上对应的信息。

### 参考

[Spring Boot 揭秘与实战 自己实现一个简单的自动配置模块](https://juejin.im/post/586a6bc4da2f600055be89be)

[spring boot 官网配置元数据](https://docs.spring.io/spring-boot/docs/current/reference/html/configuration-metadata.html#configuration-metadata-additional-metadata)

[配置元数据](https://blog.csdn.net/L_Sail/article/details/70342023)