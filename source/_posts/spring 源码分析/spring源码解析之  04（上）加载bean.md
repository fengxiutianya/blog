abbrlink: 23
title: spring 源码解析之 04（上）加载bean
tags:
  - spring源码解析
categories:
  - spring
author: fengxiutianya
date: 2019-01-14 04:46:00
---
# spring 源码解析之 04（上）加载bean

### 概述

1. spring 容器整体介绍
2. 源码分析：loadBeanDefinitions具体实现

### spring容器整体介绍

先看一段熟悉的代码

```java
BeanFactory bf = new XmlBeanFactory(new ClassPathResource("sample02.xml"));
```

这段代码时用来获取IOC容器，只不过现在spring已经不推介这样使用，这种使用方式和下面这段代码其实是一样的效果，而且实现其实也是一样的，只是上面的封装的更加简洁。

```java
ClassPathResource resource = new ClassPathResource("bean.xml");
DefaultListableBeanFactory factory = new DefaultListableBeanFactory();
XmlBeanDefinitionReader reader = new XmlBeanDefinitionReader(factory);
reader.loadBeanDefinitions(resource);
```

至于为什么说上下俩段代码实现是一样的，在后面分析源码时你就会明白。

现在我们首先看看上面代码具体干了些什么

- 创建资源对象（这里还不能确定资源是否存在，在前面spring统一资源加载中有说过为什么）
- 创建 BeanFactory容器
- 根据新建的 BeanFactory 创建一个BeanDefinitionReader对象，该Reader 对象为资源的解析器
- 解析资源 整个过程就分为三个步骤：资源定位、装载、注册，如下：
  - **资源定位**。我们一般用外部资源来描述 Bean 对象，所以在初始化 IOC 容器的第一步就是需要定位这个外部资源。在上一篇博客已经详细说明了资源加载的过程。
  - **装载**。装载就是 BeanDefinition 的载入。BeanDefinitionReader 读取、解析 Resource 资源，也就是将用户定义的 Bean 表示成 IOC 容器的内部数据结构：BeanDefinition。在 IOC 容器内部维护着一个 BeanDefinition Map 的数据结构，在配置文件中每一个 `<bean>` 都对应着一个BeanDefinition对象。
  - **注册**。向IOC容器注册在第二步解析好的 BeanDefinition，这个过程是通过 BeanDefinitionRegistry 接口来实现的。在 IOC 容器内部其实是将第二个过程解析得到的 BeanDefinition 注入到一个 HashMap 容器中，IOC 容器就是通过这个 HashMap 来维护这些 BeanDefinition 的。在这里需要注意的一点是这个过程并没有完成依赖注入，依赖注册是发生在应用第一次调用 `getBean()` 向容器索要 Bean 时。当然我们可以通过设置预处理，即对某个 Bean 设置 lazyinit 属性，那么这个 Bean 的依赖注入就会在容器初始化的时候完成。 资源定位在前面已经分析了，下面我们会直接分析加载。

在分析具体代码之前，我们这俩先来一个整体介绍，有助于后面的理解

1. DefaultListableBeanFactory

   DefaultListableBeanFactory是整个bean加载核心部分，是spring注册及加载bean的默认实现，DefaultListableBeanFactory继承了AbstractAutowireCapableBeanFactory并实现了ConfigurableListableBeanFactory以及BeanDefinitionRegistry接口。下面是DefaultListableBeanFactory继承关系图。

   ![DefaultListableBeanFactory](/images/pasted-9.png)

   这里先简单介绍一下上面类图中各个类的作用

   * AliasRegistry: 定义对alias的简单增删改操作，也就是定义对别名的操作。
   * SimpleAliasRegistry:主要使用map最为alias的缓存，并实现接口AliasRegistry。
   * SingletonBeanRegistry：定义对单例的注册及获取。
   * BeanFactory：定义获取bean及bean的各种属性。
   * DefaultSingletonBeanRegistry：实现接口SingletonBeanRegistry
   * HierarchicalBeanFactory:继承BeanFactory，在此基础上增加了BeanFactory继承体系，增加了对parentFactory的支持
   * BeanDefinitionRegistry：定义对BeanDefinition的各种增删改操作。
   * FactoryBeanRegistrySupport：继承DefaultSingletonBeanRegistry，并在此基础上增加了对FactoryBean的特殊处理功能。
   * ConfigurableBeanFactory：提供配置BeanFactory的各种方法。
   * ListableBeanFactory：根据各种条件获取bean的配置清单
   * AbstractBeanFactory：综合FactoryBeanRegistrySupport和ConfigurableBeanFactory的功能，提供默认实现，方便后面实现
   * AutowireCapableBeanFactory:提供创建bean、自动注入、初始化以及应用bean的后处理器(也就是扩展bean，在spring官方文档中提到过，容器的扩展点，也就是在创建bean前后对bean的处理）。
   * AbstractAutowireCapableBeanFactory:继承AbstractBeanFactory并实现AutowireCapableBeanFactory
   * ConfigurableListableBeanFactory：BeanFactory配置清单，指定忽略类型及接口等。
   * DefaultListableBeanFactory：综合上面所有功能，主要是对bean注册后的处理。

   在进行源码分析之前，先来解决上面遗留的一个问题，也就是上面俩段代码为什么说实现是一样的？

   XmlBeanFactory 是继承字自DefaultListableBeanFactory，而继承中只添加了一个属性XmlBeanDefinitionReader类型reader属性，然后利用此reader加载bean。具体代码如下

   ```java
   public class XmlBeanFactory extends DefaultListableBeanFactory {
   	private final XmlBeanDefinitionReader reader = new 
           				XmlBeanDefinitionReader(this);
   	public XmlBeanFactory(Resource resource) throws BeansException {
   		this(resource, null);
   	}
   
   	public XmlBeanFactory(Resource resource, BeanFactory parentBeanFactory) 
     			throws BeansException {
           
   		super(parentBeanFactory);
   		// 解析资源
   		this.reader.loadBeanDefinitions(resource);
   	}
   }
   ```

   通过上面的分析可以看出，XmlBeanFactory就是帮我们写的四步合并成一步直接实现。

   ### 源码分析：loadBeanDefinitions具体实现

   `reader.loadBeanDefinitions(resource)` 才是加载资源的真正实现，所以我们直接从该方法入手。

   ```java
       public int loadBeanDefinitions(Resource resource)
       		throws BeanDefinitionStoreException {
           return loadBeanDefinitions(new EncodedResource(resource));
       }
   ```

   从指定的 xml 文件加载 Bean Definition，这里会先对 Resource 资源封装成 EncodedResource。这里为什么需要将 Resource 封装成 EncodedResource呢？主要是为了对 Resource 进行编码，保证内容读取的正确性。封装成 EncodedResource 后，调用`loadBeanDefinitions()`，这个方法才是真正的逻辑实现。如下：

   ```java
       public int loadBeanDefinitions(EncodedResource encodedResource) 
       			throws BeanDefinitionStoreException {
           Assert.notNull(encodedResource, "EncodedResource must not be null");
           if (logger.isInfoEnabled()) {
               logger.info("Loading XML bean definitions from " 
                           	+ encodedResource.getResource());
           }
   
           // 获取已经加载过的资源
           Set<EncodedResource> currentResources = 
               		this.resourcesCurrentlyBeingLoaded.get();
           if (currentResources == null) {
               currentResources = new HashSet<>(4);
               this.resourcesCurrentlyBeingLoaded.set(currentResources);
           }
   
           // 将当前资源加入记录中
           if (!currentResources.add(encodedResource)) {
               throw new BeanDefinitionStoreException(
                       "Detected cyclic loading of " + encodedResource 
                   			+ " - check your import definitions!");
           }
           try {
        // 从 EncodedResource 获取封装的 Resource 并从 Resource 中获取其中的 InputStream
               InputStream inputStream = 
                   		encodedResource.getResource().getInputStream();
               try {
                   InputSource inputSource = new InputSource(inputStream);
                   // 设置编码
                   if (encodedResource.getEncoding() != null) {
                       inputSource.setEncoding(encodedResource.getEncoding());
                   }
                   // 核心逻辑部分
                   return doLoadBeanDefinitions(inputSource, 
                                                encodedResource.getResource());
               }
               finally {
                   inputStream.close();
               }
           }
           catch (IOException ex) {
               throw new BeanDefinitionStoreException(
                       "IOException parsing XML document from " + 
                   		encodedResource.getResource(), ex);
           }
           finally {
               // 从缓存中剔除该资源
               currentResources.remove(encodedResource);
               if (currentResources.isEmpty()) {
                   this.resourcesCurrentlyBeingLoaded.remove();
               }
           }
       }
   ```

   首先通过`resourcesCurrentlyBeingLoaded.get()` 来获取已经加载过的资源，然后将 encodedResource 加入其中，如果 resourcesCurrentlyBeingLoaded 中已经存在该资源，则抛出 BeanDefinitionStoreException 异常。完成后从 encodedResource 获取封装的 Resource 资源并从 Resource 中获取相应的 InputStream ，最后将 InputStream 封装为 InputSource 调用 `doLoadBeanDefinitions()`。方法 `doLoadBeanDefinitions()` 为从 xml 文件中加载 Bean Definition 的真正逻辑，如下:

   ```java
   protected int doLoadBeanDefinitions(InputSource inputSource, Resource resource)
               throws BeanDefinitionStoreException {
           try {
               // 获取 Document 实例
               Document doc = doLoadDocument(inputSource, resource);
               // 根据 Document 实例注册 Bean信息
               return registerBeanDefinitions(doc, resource);
           }
           catch (BeanDefinitionStoreException ex) {
               throw ex;
           }
           catch (SAXParseException ex) {
               throw new XmlBeanDefinitionStoreException(resource.getDescription(),
                       "Line " + ex.getLineNumber() + " in XML document from " + resource + " is invalid", ex);
           }
           catch (SAXException ex) {
               throw new XmlBeanDefinitionStoreException(resource.getDescription(),
                       "XML document from " + resource + " is invalid", ex);
           }
           catch (ParserConfigurationException ex) {
               throw new BeanDefinitionStoreException(resource.getDescription(),
                       "Parser configuration exception parsing XML from " + resource, ex);
           }
           catch (IOException ex) {
               throw new BeanDefinitionStoreException(resource.getDescription(),
                       "IOException parsing XML document from " + resource, ex);
           }
           catch (Throwable ex) {
               throw new BeanDefinitionStoreException(resource.getDescription(),
                       "Unexpected exception parsing XML document from " + resource, ex);
           }
       }
   ```

   核心部分就是 try 块的两行代码。

   1. 调用 `doLoadDocument()` 方法，根据 xml 文件获取 Document 实例。
   2. 根据获取的 Document 实例注册 Bean 信息。

   其实在`doLoadDocument()`方法内部还获取了 xml 文件的验证模式。如下:

   ```
       protected Document doLoadDocument(InputSource inputSource, Resource resource) 
       	throws Exception {
           return this.documentLoader.loadDocument(inputSource, getEntityResolver(), 
           this.errorHandler,getValidationModeForResource(resource),isNamespaceAware());
       }
   ```

   调用`getValidationModeForResource()` 获取指定资源（xml）的验证模式。所以 `doLoadBeanDefinitions()`主要就是做了三件事情。

   1. 调用 `getValidationModeForResource()` 获取 xml 文件的验证模式
   2. 调用 `loadDocument()` 根据 xml 文件获取相应的 Document 实例。
   3. 调用 `registerBeanDefinitions()` 注册 Bean 实例。