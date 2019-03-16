---
title: spring源码解析之 16 开启bean的加载
tags:
  - spring源码解析
categories:
  - spring
  - 源码分析
author: fengxiutianya
abbrlink: e7edce6c
date: 2019-01-15 03:30:00
---
# spring源码解析之 16 开启bean的加载

### 概述

1. spring Ioc功能简介
2. spring 获取bean流程及源码分析

### spring Ioc功能简介

![upload successful](/images/pasted-12.png)

(此图来自《Spring 揭秘》)

Spring IOC 容器所起的作用如上图所示，它会以某种方式加载 Configuration Metadata，将其解析注册到容器内部，然后回根据这些信息绑定整个系统的对象，最终组装成一个可用的基于轻量级容器的应用系统。

Spring 在实现上述功能中，将整个流程分为两个阶段：容器初始化阶段和加载bean 阶段。
<!-- more -->

- **容器初始化阶段**：首先通过某种方式加载 Configuration Metadata (主要是依据 Resource、ResourceLoader 两个体系)，然后容器会对加载的 Configuration MetaData 进行解析和分析，并将分析的信息组装成 BeanDefinition，并将其保存注册到相应的 BeanDefinitionRegistry 中。至此，Spring IOC 的初始化工作完成。
- **加载 bean 阶段**：经过容器初始化阶段后，应用程序中定义的 bean 信息已经全部加载到系统中了，当我们显示或者隐式地调用 `getBean()` 时，则会触发加载 bean 阶段。在这阶段，容器会首先检查所请求的对象是否已经初始化完成了，如果没有，则会根据注册的 bean 信息实例化请求的对象，并为其注册依赖，然后将其返回给请求方。至此第二个阶段也已经完成。

第一个阶段前面已经用了 10 多篇博客深入分析了（总结参考[初始化总结](taolove.top/posts/34/)）。所以从这篇开始分析第二个阶段：加载 bean 阶段。当我们显示或者隐式地调用 `getBean()` 时，则会触发加载 bean 阶段。如下：

```java
    public Object getBean(String name) throws BeansException {
        return doGetBean(name, null, null, false);
    }
```

内部调用 `doGetBean()` 方法，其接受四个参数：

- name：要获取 bean 的名字
- requiredType：要获取 bean 的类型
- args：创建 bean 时传递的参数。这个参数仅限于创建 bean 时使用
- typeCheckOnly：是否为类型检查,如果为类型检查，可以不创建bean

下面我们对doGetBean进行分析

### spring 获取bean流程及源码分析

代码有点长，最好复制到编辑器中查看：

```java
protected <T> T doGetBean(final String name, @Nullable final Class<T> requiredType,
                    @Nullable final Object[] args, boolean typeCheckOnly) 
     throws BeansException {
   // 转换beanName，前面我们已经说过，bean可以有别名，这里就是将别名转换为beanName
   final String beanName = transformedBeanName(name);
    
   Object bean;
   /**
    * 检查缓存中或者实例工厂中是否有对应的实例
    * 为什么首先会使用这段代码呢 ？
    * 因为在创建单例bean的时候会存在依赖注入的情况，而在创建依赖的时候为了避免循环依赖
    * spring创建bean的原则是不等bean创建完成就会创建bean的ObjectFactory提早曝光，
    * （ObjectFactory用于产生对象，相当于一个创建特定对象的工厂） 也就是将ObjectFactory
    * 加入到缓存中，一旦下个bean创建时候需要依赖上个bean则直接使用
    * ObjectFactory：返回对应的object，也就是bean
    *
    */
   // 直接尝试从单例缓存获取或者singletonFactories中的ObjectFactory中获取
   Object sharedInstance = getSingleton(beanName);

   if (sharedInstance != null && args == null) {
      if (logger.isTraceEnabled()) {
         if (isSingletonCurrentlyInCreation(beanName)) {
           。。。省略日志
         } else {
       		。。。 省略日志 
         }
      }
      // 返回对应的实例，有时候存在诸如FactoryBean的情况并不是直接返回实例本身
      // 而是指定方法返回实例 对应这种情况是自定义了一些FactoryBean，本身就是一个bean
      // 可以用来创建特定bean的工厂
      // 还有是工厂bean中定义的factory-method方法返回bean
      bean = getObjectForBeanInstance(sharedInstance, name, beanName, null);
   } else {
      /**
       * 只有个在单例情况下才会尝试解决循环依赖，原型模式情况下，
       * 如果存在A中有B的属性，B中有A的属性，那么当依赖注入的时候，
       * 就会产生当A还未创建完的时候因为B的创建在此返回创建A，造成
       * 循环依赖，也就是下面这种情况
       */
      if (isPrototypeCurrentlyInCreation(beanName)) {
         throw new BeanCurrentlyInCreationException(beanName);
      }

      // 如果beanDefinitionMap中也就是在所有已加载的类中不包括beanName
      // 则会尝试从parentBeanFactory中检测
      // Check if bean definition exists in this factory.
      BeanFactory parentBeanFactory = getParentBeanFactory();
      if (parentBeanFactory != null && !containsBeanDefinition(beanName)) {
         // 递归到BeanFactory中寻找
         // Not found -> check parent.
         String nameToLookup = originalBeanName(name);
         if (parentBeanFactory instanceof AbstractBeanFactory) {
            return ((AbstractBeanFactory) parentBeanFactory).doGetBean(
                  nameToLookup, requiredType, args, typeCheckOnly);
         } else if (args != null) {
            // Delegation to parent with explicit args.
            return (T) parentBeanFactory.getBean(nameToLookup, args);
         } else if (requiredType != null) {
            // No args -> delegate to standard getBean method.
            return parentBeanFactory.getBean(nameToLookup, requiredType);
         } else {
            return (T) parentBeanFactory.getBean(nameToLookup);
         }
      }

      // 如果不是仅仅做类型检查则是创建bean，这里要进行记录
      if (!typeCheckOnly) {
         markBeanAsCreated(beanName);
      }

      try {
         // 将存储xml配置文件的GernericBeanDefinition转换为RootBeanDefinition
         // 如果指定BeanName是子Bean的话同时会合并父类的相关属性
         final RootBeanDefinition mbd = getMergedLocalBeanDefinition(beanName);
       
          // 检查给定的合并的 BeanDefinition
          checkMergedBeanDefinition(mbd, beanName, args);

         // 若存在依赖则需要递归实例化依赖的bean
         // Guarantee initialization of beans that the current bean depends on.
         String[] dependsOn = mbd.getDependsOn();
         if (dependsOn != null) {
            for (String dep : dependsOn) {
               if (isDependent(beanName, dep)) {
                  throw new BeanCreationException(mbd.getResourceDescription(), 
                                                  beanName,
                        "Circular depends-on relationship between '" 
                                                  + beanName + "' and '" + dep + "'");
               }
               // 缓存依赖调用
               registerDependentBean(dep, beanName);
               try {
                  getBean(dep);
               } catch (NoSuchBeanDefinitionException ex) {
                  throw new BeanCreationException(mbd.getResourceDescription(),
                                                  beanName,
                        "'" + beanName + "' depends on missing bean '" + dep + "'",
                                                  ex);
               }
            }
         }
         // Create bean instance.
         // 实例化依赖的bean后便可以实例化mbd本身所代表的bean
         // singleton模式的创建
         if (mbd.isSingleton()) {
            sharedInstance = getSingleton(beanName, () -> {
               try {
                  return createBean(beanName, mbd, args);
               } catch (BeansException ex) {
				// 显示从单例缓存中删除 bean 实例
                // 因为单例模式下为了解决循环依赖，可能他已经存在了，所以销毁它
                  destroySingleton(beanName);
                  throw ex;
               }
            });
            bean = getObjectForBeanInstance(sharedInstance, name, beanName, mbd);
         } else if (mbd.isPrototype()) { 
             // prototype模式的创建

            Object prototypeInstance = null;
            try {
               beforePrototypeCreation(beanName);
               prototypeInstance = createBean(beanName, mbd, args);
            } finally {
               afterPrototypeCreation(beanName);
            }
            bean = getObjectForBeanInstance(prototypeInstance, name, beanName, mbd);
         } else {
            // 指定的scope上实例化bean
            String scopeName = mbd.getScope();
            final Scope scope = this.scopes.get(scopeName);
            if (scope == null) {
               throw new IllegalStateException("No Scope registered for scope name '"
                                               + scopeName + "'");
            }
            try {
               // 从指定的 scope 下创建 bean
               Object scopedInstance = scope.get(beanName, () -> {
                  beforePrototypeCreation(beanName);
                  try {
                     return createBean(beanName, mbd, args);
                  } finally {
                     afterPrototypeCreation(beanName);
                  }
               });
               bean = getObjectForBeanInstance(scopedInstance, name, beanName, mbd);
            } catch (IllegalStateException ex) {
               throw new BeanCreationException(beanName,
                     "Scope '" + scopeName + "' is not active for the current thread;
                                               consider " 
                      +  "defining a scoped proxy for this bean if you intend to refer
                                               to it from a singleton",  ex);
            }
         }
      } catch (BeansException ex) {
         cleanupAfterBeanCreationFailure(beanName);
         throw ex;
      }
   }
   // 检查需要的类型是否符合bean的实际类型
   if (requiredType != null && !requiredType.isInstance(bean)) {
      try {
         T convertedBean = getTypeConverter().convertIfNecessary(bean, requiredType);
         if (convertedBean == null) {
            throw new BeanNotOfRequiredTypeException(name, requiredType, 
                                                     bean.getClass());
         }
         return convertedBean;
      } catch (TypeMismatchException ex) {
         if (logger.isTraceEnabled()) {
            logger.trace("Failed to convert bean '" + name + "' to required type '" +
                  ClassUtils.getQualifiedName(requiredType) + "'", ex);
         }
         throw new BeanNotOfRequiredTypeException(name, requiredType, 
                                                  bean.getClass());
      }
   }
   return (T) bean;
}
```

上面的代码很长、逻辑也挺复杂，但是可以初略的看到spring加载bean的过程，下面对于整个加载过程进行总结。

**1.获取 beanName**

```java
final String beanName = transformedBeanName(name);
```

这里传递的是 name，不一定就是 beanName，可能是 aliasName，也有可能是 FactoryBean，所以这里需要调用 `transformedBeanName()` 方法对 name 进行一番转换，主要如下：

```java
    protected String transformedBeanName(String name) {
        return canonicalName(BeanFactoryUtils.transformedBeanName(name));
    }

    // 去除 FactoryBean 的修饰符
    public static String transformedBeanName(String name) {
        Assert.notNull(name, "'name' must not be null");
        String beanName = name;
        while (beanName.startsWith(BeanFactory.FACTORY_BEAN_PREFIX)) {
            beanName = beanName.substring(BeanFactory.FACTORY_BEAN_PREFIX.length());
        }
        return beanName;
    }

    // 转换 aliasName
    public String canonicalName(String name) {
        String canonicalName = name;
        // Handle aliasing...
        String resolvedName;
        do {
            resolvedName = this.aliasMap.get(canonicalName);
            if (resolvedName != null) {
                canonicalName = resolvedName;
            }
        }while (resolvedName != null);
        return canonicalName;
    }
```

主要处理过程包括两步：

1. 去除 FactoryBean 的修饰符。如果 name 以 “&” 为前缀，那么会去掉该 “&”，例如，`name = "&studentService"`，则会是 `name = "studentService"`。
2. 取指定的 alias 所表示的最终 beanName。主要是一个循环获取 beanName 的过程，例如别名 A 指向名称为 B 的 bean 则返回 B，若 别名 A 指向别名 B，别名 B 指向名称为 C 的 bean，则返回 C。

**2.从单例 bean 缓存中获取 bean**

对应代码段如下：

```java
Object sharedInstance = getSingleton(beanName);
if (sharedInstance != null && args == null) {
    if (logger.isDebugEnabled()) {
        if (isSingletonCurrentlyInCreation(beanName)) {
            ...省略日志文件
        }
        else {
            。。。 省略日志文件
        }
    }
    bean = getObjectForBeanInstance(sharedInstance, name, beanName, null);
}
```

我们知道单例模式的 bean 在整个过程中只会被创建一次，第一次创建后会将该 bean 加载到缓存中，后面在获取 bean 就会直接从单例缓存中获取。如果从缓存中得到了 bean，则需要调用 `getObjectForBeanInstance()` 对 bean 进行实例化处理，因为缓存中记录的是最原始的 bean 状态，我们得到的不一定是我们最终想要的 bean。

**3.原型模式依赖检查与 parentBeanFactory**

对应代码段

```java
            if (isPrototypeCurrentlyInCreation(beanName)) {
                throw new BeanCurrentlyInCreationException(beanName);
            }

            // Check if bean definition exists in this factory.
            BeanFactory parentBeanFactory = getParentBeanFactory();
            if (parentBeanFactory != null && !containsBeanDefinition(beanName)) {
                // Not found -> check parent.
                String nameToLookup = originalBeanName(name);
                if (parentBeanFactory instanceof AbstractBeanFactory) {
                    return ((AbstractBeanFactory) parentBeanFactory).doGetBean(
                            nameToLookup, requiredType, args, typeCheckOnly);
                }
                else if (args != null) {
                    // Delegation to parent with explicit args.
                    return (T) parentBeanFactory.getBean(nameToLookup, args);
                }
                else {
                    // No args -> delegate to standard getBean method.
                    return parentBeanFactory.getBean(nameToLookup, requiredType);
                }
            }
```

Spring 只处理单例模式下得循环依赖，对于原型模式的循环依赖直接抛出异常。主要原因还是在于 Spring 解决循环依赖的策略有关。对于单例模式 Spring 在创建 bean 的时候并不是等 bean 完全创建完成后才会将 bean 添加至缓存中，而是不等 bean 创建完成就会将创建 bean 的 ObjectFactory 提早加入到缓存中，这样一旦下一个 bean 创建的时候需要依赖 bean 时则直接使用 ObjectFactroy。但是原型模式我们知道是没法使用缓存的，所以 Spring 对原型模式的循环依赖处理策略则是不处理（关于循环依赖后面会有单独文章说明）。

如果容器缓存中没有相对应的 BeanDefinition 则会尝试从父类工厂（parentBeanFactory）中加载，然后再去递归调用 `getBean()`。

**4. 将存储xml配置文件中的GenericBeanDefinition转换为RootBeanDefinition**

前面也说过，从xml文件中获取读取到的bean信息是存储在GenericBeanDefinition中的，但是所有的bean后续处理都是针对于RootBeanDefinition的，所以这里需要进行一个转换，转的同时如果父类Bean不为空的话，则会合并父类的属性。

**5. 依赖处理**

对应源码如下：

```java
                String[] dependsOn = mbd.getDependsOn();
                if (dependsOn != null) {
                    for (String dep : dependsOn) {
                        if (isDependent(beanName, dep)) {
                            throw new 
                                BeanCreationException(mbd.getResourceDescription(), 
                                                            beanName,
                                    "Circular depends-on relationship between '" 
                                       + beanName + "' and '" + dep + "'");
                        }
                        registerDependentBean(dep, beanName);
                        try {
                            getBean(dep);
                        }
                        catch (NoSuchBeanDefinitionException ex) {
                            throw new 
                                BeanCreationException(mbd.getResourceDescription(), 
                                  beanName,"'" + beanName 
                                + "' depends on missing bean '" + dep + "'", ex);
                        }
                    }
                }
```

每个 bean 都不是单独工作的，它会依赖其他 bean，其他 bean 也会依赖它，对于依赖的 bean ，它会优先加载，所以在 Spring 的加载顺序中，在初始化某一个 bean 的时候首先会初始化这个 bean 的依赖。

**6 作用域处理**

Spring bean 的作用域默认为 singleton，当然还有其他作用域，如prototype、request、session 等，不同的作用域会有不同的初始化策略。

**7 类型转换**

在调用 `doGetBean()` 方法时，有一个 requiredType 参数，该参数的功能就是将返回的 bean 转换为 requiredType 类型。当然就一般而言我们是不需要进行类型转换的，也就是 requiredType 为空（比如 `getBean(String name)`），但有可能会存在这种情况，比如我们返回的 bean 类型为 String，我们在使用的时候需要将其转换为 Integer，那么这个时候 requiredType 就有用武之地了。当然我们一般是不需要这样做的。

至此 `getBean()` 过程讲解完了。后续将会对该过程进行拆分，更加详细的说明，弄清楚其中的来龙去脉，所以这篇博客只能算是 Spring bean 加载过程的一个概览。