---
title: spring源码解析之 25bean的初始化
tags:
  - spring
  - spring源码解析
categories:
  - spring
  - 源码分析
author: fengxiutianya
abbrlink: 2d7bbce0
date: 2019-01-15 03:57:00
---
# spring源码解析之 25bean的初始化

前面我们已经分析了bean的创建，属性的注入，依赖处理，其实这时bean基本上已经可以用了，不知道你还记不记得我们在xml中还可以配置init-method属性，这个到现在为止还没有处理，这就是最后一步初始化，也就是 `initializeBean()`，所以这篇文章我们分析 `doCreateBean()` 中最后一步：初始化 bean。
<!-- more -->
```java
protected Object initializeBean(final String beanName, final Object bean, 
                                @Nullable RootBeanDefinition mbd) {
    // 这个判断现在可以不理，主要是为了安全，重点是invokeAwareMethods方法
    if (System.getSecurityManager() != null) {
        AccessController.doPrivileged((PrivilegedAction<Object>) () -> {
            invokeAwareMethods(beanName, bean);
            return null;
        }, getAccessControlContext());
    }
    else {
        // 激活 Aware方法，对特殊的bean处理：
        // Aware、BeanClassLoaderAware、BeanFactoryAware
        invokeAwareMethods(beanName, bean);
    }
    Object wrappedBean = bean;
    if (mbd == null || !mbd.isSynthetic()) {
        // 在调用init-method之前的处理也就是BeanPostProcessor前置处理
        wrappedBean = 
            applyBeanPostProcessorsBeforeInitialization(wrappedBean, beanName);
    }

    try {
        // 激活用户自定义的 init 方法
        invokeInitMethods(beanName, wrappedBean, mbd);
    }
    catch (Throwable ex) {
       。。。省略异常
    }
    if (mbd == null || !mbd.isSynthetic()) {
        // bean调用init-method之后的处理也就是BeanPostProcessor后置处理
        wrappedBean = 
            applyBeanPostProcessorsAfterInitialization(wrappedBean, beanName);
    }
    return wrappedBean;
}
```

初始化 bean 的方法其实就是三个步骤的处理，而这三个步骤主要还是根据用户设定的来进行初始化，这三个过程为：

1. 激活 Aware 方法
2. 后置处理器的应用
3. 激活自定义的 init 方法

**激活 Aware 方法**

Aware ,英文翻译是意识到的，感知的，Spring 提供了诸多 Aware 接口用于辅助 Spring Bean 以编程的方式调用 Spring 容器，通过实现这些接口，可以增强 Spring Bean 的功能。

Spring 提供了如下系列的 Aware 接口：

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

`invokeAwareMethods()` 源码如下：

```java
    private void invokeAwareMethods(final String beanName, final Object bean) {
        if (bean instanceof Aware) {
            // 注入beanname
            if (bean instanceof BeanNameAware) {
                ((BeanNameAware) bean).setBeanName(beanName);
            }
            // 注入类加载器
            if (bean instanceof BeanClassLoaderAware) {
                ClassLoader bcl = getBeanClassLoader();
                if (bcl != null) {
                    ((BeanClassLoaderAware) bean).setBeanClassLoader(bcl);
                }
            }
            // 注入beanFactory
            if (bean instanceof BeanFactoryAware) {
                ((BeanFactoryAware) bean)
                	.setBeanFactory(AbstractAutowireCapableBeanFactory.this);
            }
        }
    }
```

这里代码就没有什么好说的，主要是处理 BeanNameAware、BeanClassLoaderAware、BeanFactoryAware。关于 Aware 接口，后面会专门出篇文章对其进行详细分析说明的。

**后置处理器的应用**

BeanPostProcessor 在前面介绍 bean 加载的过程曾多次遇到，相信各位不陌生，这是 Spring 中开放式框架中必不可少的一个亮点。BeanPostProcessor 的作用是：如果我们想要在 Spring 容器完成 Bean 的实例化，配置和其他的初始化后添加一些自己的逻辑处理，那么请使用该接口，这个接口给与了用户充足的权限去更改或者扩展 Spring，是我们对 Spring 进行扩展和增强处理一个必不可少的接口。

```java
public Object applyBeanPostProcessorsBeforeInitialization(Object existingBean, 
                                String beanName) throws BeansException {

    Object result = existingBean;
    for (BeanPostProcessor beanProcessor : getBeanPostProcessors()) {
        Object current = beanProcessor.postProcessBeforeInitialization(result, 
                                                                       beanName);
        if (current == null) {
            return result;
        }
        result = current;
    }
    return result;
}

@Override
public Object applyBeanPostProcessorsAfterInitialization(Object existingBean, 
                           String beanName) throws BeansException {

    Object result = existingBean;
    for (BeanPostProcessor beanProcessor : getBeanPostProcessors()) {
        Object current = beanProcessor.postProcessAfterInitialization(result, 
                                                                      beanName);
        if (current == null) {
            return result;
        }
        result = current;
    }
    return result;
}
```

其实逻辑就是通过 `getBeanPostProcessors()` 获取定义的 BeanPostProcessor ，然后分别调用其 `postProcessBeforeInitialization()`、`postProcessAfterInitialization()` 进行业务处理。

**激活自定义的 init 方法**

如果熟悉 `<bean>` 标签的配置，一定不会忘记 `init-method` 方法，该方法的执行就是在这里执行的。

```java
protected void invokeInitMethods(String beanName, final Object bean, 
           @Nullable RootBeanDefinition mbd) throws Throwable {
    
    // 首先会检查是否是 InitializingBean ，如果是的话需要调用 afterPropertiesSet()
    boolean isInitializingBean = (bean instanceof InitializingBean);
    if (isInitializingBean && 
        (mbd == null || !mbd.isExternallyManagedInitMethod("afterPropertiesSet"))) 
    {
        if (logger.isDebugEnabled()) {
            // 省略日志
        }
        if (System.getSecurityManager() != null) {
            try {
                AccessController.doPrivileged((PrivilegedExceptionAction<Object>) 
                             () -> {((InitializingBean) bean).afterPropertiesSet();
                                                  return null;
                              }, getAccessControlContext());
            }
            catch (PrivilegedActionException pae) {
                throw pae.getException();
            }
        }
        else {
            // 属性初始化的处理
            ((InitializingBean) bean).afterPropertiesSet();
        }
    }

    if (mbd != null && bean.getClass() != NullBean.class) {
        String initMethodName = mbd.getInitMethodName();
        if (StringUtils.hasLength(initMethodName) &&
            !(isInitializingBean && 
              "afterPropertiesSet".equals(initMethodName)) &&
            !mbd.isExternallyManagedInitMethod(initMethodName)) {
            // 激活用户自定义的 初始化方法
            invokeCustomInitMethod(beanName, bean, mbd);
        }
    }
}
```

首先检查是否为 InitializingBean ，如果是的话需要执行 `afterPropertiesSet()`，因为我们除了可以使用 `init-method`来自定初始化方法外，还可以实现 InitializingBean 接口，该接口仅有一个 `afterPropertiesSet()` 方法，而两者的执行先后顺序是先 `afterPropertiesSet()` 后 `init-method`。

**注册DisposableBean**

spring中不但提供了对于初始化方法的扩展入口同样也提供了销毁方法的扩展入口，对于销毁方法的扩展，处理我们熟知的配置属性destroy-method方法外，用户还可以注册后处理器DestructionAwareBeanpostProcessor来统一处理bean的销毁方法，具体代码如下

```java
protected void registerDisposableBeanIfNecessary(String beanName, Object bean, 
                                                 RootBeanDefinition mbd) {
    AccessControlContext acc = (System.getSecurityManager() != null ? 
                                getAccessControlContext() : null);

    if (!mbd.isPrototype() && requiresDestruction(bean, mbd)) {
        // 单例bean的注册销毁
        if (mbd.isSingleton()) {
            // 在bean销毁之前调用这个destroy-method
            registerDisposableBean(beanName,
         new DisposableBeanAdapter(bean, beanName, mbd, getBeanPostProcessors(), acc));
            // 其他scope bean的注册销毁
        } else {
            Scope scope = this.scopes.get(mbd.getScope());
            if (scope == null) {
                // 抛出异常省略
            }
            scope.registerDestructionCallback(beanName,
                        new DisposableBeanAdapter(bean, beanName, mbd, 
                                  getBeanPostProcessors(), acc));
        }
    }
}
```

其实这个销毁方法对于单例bean来说，扩展在这里我感觉是没有多大作用，因为单例bean的销毁是随着整个容器而销毁，而整个容器的销毁也代表者这个应用销毁，不起作用所以这里掉不掉用销毁方法已经没什么作用。对于其他的scope，是可以起作用的，类如request，session的scope是可以在里面加入一些定制化的逻辑。后面分析springMVC时会具体说道。

