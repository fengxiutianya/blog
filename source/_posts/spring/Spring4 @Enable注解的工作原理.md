---
title: Spring4 @Enable*注解的工作原理
tags:
  - spring
categories:
  - java
abbrlink: 5d34b48
date: 2019-03-11 06:46:00
---
---
# Spring4 @Enable*注解的工作原理

## 概述

1. 简介
2. 实现原理

## 简介

在使用SpringBoot的时候，我们经常看到一些`@Enable*`之类的开启对某些特性的支持。类如下面举的例子

1. @EnableAspectJAutoProxy 开启对AspectJ自动代理的支持
2. @EnableAsync 开启异步方法的支持
3. @EnableScheduling 开启计划任务的支持
4. @EnableWebMvc 开启Web MVC的配置支持。
5. @EnableConfigurationProperties开启对@ConfigurationProperties注解配置Bean的支持。
6. @EnableJpaRepositories 开启对Spring Data JPA Repository的支持。
7. @EnableTransactionManagement 开启注解式事务的支持。
8. @EnableCaching开启注解式的缓存支持。

通过简单的`@Enable*`来开启一项功能的支持，从而避免自己配置大量的代码，大大降低使用难度。那么这个神奇的功能的实现原理是什么呢？下面来研究一下。
<!-- more -->

## 实现原理

通过观察这些`@Enable*`注解的源码，发现所有的注解都有一个`@Import`注解，`@Import`是用来导入配置类的，这也就意味着这些自动开启的实现其实是导入了一些自动配置的Bean。这些导入的配置主要分为以下三种类型：

1. 直接导入配置类

2.  依据条件选择配置类
3.  动态注册Bean

下面我们来分别介绍这个类型

### 直接导入配置类

比较直接的就是`@EnableScheduling`,这个注解的源码如下

```java
@Target({java.lang.annotation.ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Import({SchedulingConfiguration.class})
@Documented
public @interface EnableScheduling
{
}
```

可以看到`EnableScheduling`注解直接导入配置类`SchedulingConfiguration`，这个类注解了`@Configuration`，且注册了一个`scheduledAnnotationProcessor`的Bean，`SchedulingConfiguration`的源码如下：

```java
@Configuration
public class SchedulingConfiguration {

    @Bean(name = TaskManagementConfigUtils.SCHEDULED_ANNOTATION_PROCESSOR_BEAN_NAME)
    @Role(BeanDefinition.ROLE_INFRASTRUCTURE)
    public ScheduledAnnotationBeanPostProcessor scheduledAnnotationProcessor() {
        return new ScheduledAnnotationBeanPostProcessor();
    }

}
```

### 依据条件选择配置类

这里可以看看`@EnableAsync`这个注解，源码如下

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Import(AsyncConfigurationSelector.class)
public @interface EnableAsync {

    Class<? extends Annotation> annotation() default Annotation.class;

    boolean proxyTargetClass() default false;

    AdviceMode mode() default AdviceMode.PROXY;

    int order() default Ordered.LOWEST_PRECEDENCE;
}
```

`AsyncConfigurationSelectort`通过条件来选择需要导入的配置类。`AsyncConfigurationSelector`的根接口为`ImportSelector`,这个接口需要重写`selectImports`方法，在此方法内进行事先条件判断。此例中，若`adviceMode`为`PROXY`，则返回`ProxyAsyncConfiguration`这个配置类；若`adviceMode`为`ASPECTJ`，则返回`AspectJAsyncConfiguration`配置类，源码如下：

```java
public class AsyncConfigurationSelector extends AdviceModeImportSelector<EnableAsync> {

    private static final String ASYNC_EXECUTION_ASPECT_CONFIGURATION_CLASS_NAME =
            "org.springframework.scheduling.aspectj.AspectJAsyncConfiguration";

    /**
     * {@inheritDoc}
     * @return {@link ProxyAsyncConfiguration} or {@code AspectJAsyncConfiguration} for
     * {@code PROXY} and {@code ASPECTJ} values of {@link EnableAsync#mode()}, respectively
     */
    @Override
    public String[] selectImports(AdviceMode adviceMode) {
        switch (adviceMode) {
            case PROXY:
                return new String[] { ProxyAsyncConfiguration.class.getName() };
            case ASPECTJ:
                return new String[] { ASYNC_EXECUTION_ASPECT_CONFIGURATION_CLASS_NAME };
            default:
                return null;
        }
    }

}
```

### 动态注册Bean

这里拿`@EnableAspectJAutoProxy`来举例，源码如下

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Import(AspectJAutoProxyRegistrar.class)
public @interface EnableAspectJAutoProxy {

    /**
     * Indicate whether subclass-based (CGLIB) proxies are to be created as opposed
     * to standard Java interface-based proxies. The default is {@code false}.
     */
    boolean proxyTargetClass() default false;

}
```

`AspectJAutoProxyRegistrar`实现了`ImportBeanDefinitionRegistrar`接口，`ImportBeanDefinitionRegistrar`的作用是在运行时自动添加Bean到已有的配置类，通过重写方法：

```java
public void registerBeanDefinitions(AnnotationMetadata importingClassMetadata, BeanDefinitionRegistry registry)
```

其中，`AnnotationMetadata`参数用来获得当前配置类上的注解，`BeanDefinitionRegistry `参数用来注册Bean。源码如下：

```java
class AspectJAutoProxyRegistrar implements ImportBeanDefinitionRegistrar {

    /**
     * Register, escalate, and configure the AspectJ auto proxy creator based on the value
     * of the @{@link EnableAspectJAutoProxy#proxyTargetClass()} attribute on the importing
     * {@code @Configuration} class.
     */
    @Override
    public void registerBeanDefinitions(
            AnnotationMetadata importingClassMetadata, BeanDefinitionRegistry registry) {

        AopConfigUtils.registerAspectJAnnotationAutoProxyCreatorIfNecessary(registry);

        AnnotationAttributes enableAJAutoProxy =
                AnnotationConfigUtils.attributesFor(importingClassMetadata, EnableAspectJAutoProxy.class);
        if (enableAJAutoProxy.getBoolean("proxyTargetClass")) {
            AopConfigUtils.forceAutoProxyCreatorToUseClassProxying(registry);
        }
    }

}
```

## 总结

其实就是将原先在xml中配置的一些类，现在统一的转换成对应的类，然后通过以上三种方法，将这些类导入到spring容器中。

## 参考

1. [Spring4.x高级话题(六):@Enable*注解的工作原理](http://blog.longjiazuo.com/archives/1366)