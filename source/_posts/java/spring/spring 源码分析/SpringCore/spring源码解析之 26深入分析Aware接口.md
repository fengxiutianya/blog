---
title: spring源码解析之 26深入分析Aware接口
tags:
  - spring源码解析
categories:
  - java
  - spring
  - spring 源码分析
  - SpringCore
author: fengxiutianya
abbrlink: fa9db44e
date: 2019-01-15 06:38:00
---
我们经过前面的解析，已经知道了如何创建一个bean。但是在在上一篇博客bean的初始化中，说道bean的初始化initializeBean会做以下三件事，分别是：

1. 激活 Aware 方法
2. 后置处理器的应用
3. 激活自定义的 init 方法

虽然我们分析了这部分的源码，但是没有仔细分析，所以接下来三篇文章，会分别对这三个进行仔细分析。单独拿出来说的原因，是他们都是spring提供给我们可以使用的扩展机制。这里先来分析Aware接口
<!-- more -->

Aware接口定义如下：

```java
/**
 * A marker superinterface indicating that a bean is eligible to be notified by the
 * Spring container of a particular framework object through a callback-style method.
 * The actual method signature is determined by individual subinterfaces but should
 * typically consist of just one void-returning method that accepts a single argument.
 *
 * <p>Note that merely implementing {@link Aware} provides no default functionality.
 * Rather, processing must be done explicitly, for example in a
 * {@link org.springframework.beans.factory.config.BeanPostProcessor}.
 * Refer to {@linkorg.springframework.context.support.ApplicationContextAwareProcessor}
 * for an example of processing specific {@code *Aware} interface callbacks.
 *
 * @author Chris Beams
 * @author Juergen Hoeller
 * @since 3.1
 */
public interface Aware {

}
```

Aware 接口为 Spring 容器的核心接口，是一个具有标识作用的超级接口，实现了该接口的 bean 是具有被 Spring 容器通知的能力，通知的方式是采用回调的方式。

Aware 接口是一个空接口，实际的方法签名由各个子接口来确定，且该接口通常只会有一个接收单参数的 set 方法，该 set 方法的命名方式为 set + 去掉接口名中的 Aware 后缀，即 XxxAware 接口，则方法定义为 setXxx()，例如 BeanNameAware（setBeanName），ApplicationContextAware（setApplicationContext）。

在上面的描述中也特别说明了如果仅仅是实现了Aware接口，是没有任何作用。而我们自己如果想实现一个类似于BeanNameAware的接口，就需要以下几个步骤

1. 自定义一个接口实现Aware，
2. 提供针对这个接口处理的类，类如定义一个bean实现BeanPostProcessor（这个会在下一篇中具体分析），然后在其中实现针对自己实现接口的处理。

spring已经定义的Aware类型的接口，都已经实现了针对这些接口的处理，类如我们前面说到的三个接口，是在`invokeAwareMethods`中进行的处理，代码如下：

```java
 private void invokeAwareMethods(final String beanName, final Object bean) {
  if (bean instanceof Aware) {
   if (bean instanceof BeanNameAware) {
    ((BeanNameAware) bean).setBeanName(beanName);
   }
   if (bean instanceof BeanClassLoaderAware) {
    ClassLoader bcl = getBeanClassLoader();
    if (bcl != null) {
     ((BeanClassLoaderAware) bean).setBeanClassLoader(bcl);
    }
   }
   if (bean instanceof BeanFactoryAware) {
    ((BeanFactoryAware) bean).setBeanFactory(AbstractAutowireCapableBeanFactory.this);
   }
  }
 }
```

下面就这三个接口来做一个简单的演示，先看各自的定义：

```java
public interface BeanClassLoaderAware extends Aware {

 /**
  * 将 BeanClassLoader 提供给 bean 实例回调
  * 在 bean 属性填充之后、初始化回调之前回调，
  * 例如InitializingBean的InitializingBean.afterPropertiesSet（）方法或自定义init方法
  */
 void setBeanClassLoader(ClassLoader classLoader);
}

public interface BeanFactoryAware extends Aware {
    /**
  * 将 BeanFactory 提供给 bean 实例回调
  * 调用时机和 setBeanClassLoader 一样
  */
 void setBeanFactory(BeanFactory beanFactory) throws BeansException;
}

public interface BeanNameAware extends Aware {
 /**
  * 在创建此 bean 的 bean工厂中设置 beanName
  */
 void setBeanName(String name);
}

public interface ApplicationContextAware extends Aware {
 /**
  * 设置此 bean 对象的 ApplicationContext，通常，该方法用于初始化对象
  */
 void setApplicationContext(ApplicationContext applicationContext) throws BeansException;

}
```

下面简单演示下上面四个接口的使用方法：

```java
public class MyApplicationAware implements 
       BeanNameAware,BeanFactoryAware,BeanClassLoaderAware{

    private String beanName;

    private BeanFactory beanFactory;

    private ClassLoader classLoader;

    private ApplicationContext applicationContext;

    @Override
    public void setBeanClassLoader(ClassLoader classLoader) {
        System.out.println("调用了 BeanClassLoaderAware 的 setBeanClassLoader 方法");

        this.classLoader = classLoader;
    }

    @Override
    public void setBeanFactory(BeanFactory beanFactory) throws BeansException {
        System.out.println("调用了 BeanFactoryAware 的 setBeanFactory 方法");

        this.beanFactory = beanFactory;
    }

    @Override
    public void setBeanName(String name) {
        System.out.println("调用了 BeanNameAware 的 setBeanName 方法");

        this.beanName = name;
    }


    public void display(){
        System.out.println("beanName:" + beanName);

        System.out.println("是否为单例：" + beanFactory.isSingleton(beanName));
        
    }
}
```

测试方法如下:

```java
public static void main(String[] args) {
    ClassPathResource resource = new ClassPathResource("spring.xml");
    DefaultListableBeanFactory factory = new DefaultListableBeanFactory();
    XmlBeanDefinitionReader reader = new XmlBeanDefinitionReader(factory);
    reader.loadBeanDefinitions(resource);

    MyApplicationAware applicationAware = (MyApplicationAware) 
        factory.getBean("myApplicationAware");
    applicationAware.display();
}
```

运行结果如下：

```
调用了 BeanNameAware 的 setBeanName 方法
调用了 BeanClassLoaderAware 的 setBeanClassLoader 方法
调用了 BeanFactoryAware 的 setBeanFactory 方法
beanName:myApplicationAware
是否为单例:true
```

从这了我们基本上就可以 Aware 真正的含义是什么了？感知，其实是 Spring 容器在初始化主动检测当前 bean 是否实现了 Aware 接口，如果实现了则回调其 set 方法将相应的参数设置给该 bean ，这个时候该 bean 就从 Spring 容器中取得相应的资源。最后文章末尾列出部分常用的 Aware 子接口，便于日后查询：

- LoadTimeWeaverAware：加载Spring Bean时织入第三方模块，如AspectJ
- BeanClassLoaderAware：加载Spring Bean的类加载器
- BootstrapContextAware：资源适配器BootstrapContext，如JCA,CCI
- ResourceLoaderAware：底层访问资源的加载器
- BeanFactoryAware：声明BeanFactory
- PortletConfigAware：PortletConfig
- PortletContextAware：PortletContext
- ServletConfigAware：ServletConfig
- ServletContextAware：ServletContext
- MessageSourceAware：国际化
- ApplicationEventPublisherAware：应用事件
- NotificationPublisherAware：JMX通知
- BeanNameAware：声明Spring Bean的名字

这里我们已经仔细分析了Aware接口，但是如果我们自己想实现一个自定义的Aware接口，则需要结合下一篇文章将要介绍的BeanPostProcessor，接下来我们一起来仔细分析这个接口。