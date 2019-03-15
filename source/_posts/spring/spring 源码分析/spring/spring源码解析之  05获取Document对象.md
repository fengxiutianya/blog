title: spring源码分析之 05获取Document对象
tags:
  - spring源码解析
  - ''
categories:
  - spring
author: fengxiutianya
date: 2019-01-14 04:52:00
---
# spring源码解析之 05获取Document对象

### 概述

1. LoadDocument源码分析
2. EntityResolver分析

### LoadDocument源码分析:

在 `XmlBeanDefinitionReader.doLoadDocument()` 方法中做了两件事情，一是调用 `getValidationModeForResource()` 获取 XML 的验证模式，二是调用 `DocumentLoader.loadDocument()` 获取 Document 对象。上篇博客已经分析了获取 XML 验证模式，这篇我们分析获取 Document 对象。
<!-- more-->
获取 Document 的策略由接口 DocumentLoader 定义，如下：

```java
public interface DocumentLoader {
    Document loadDocument(
            InputSource inputSource, EntityResolver entityResolver,
            ErrorHandler errorHandler, int validationMode, boolean namespaceAware)
            throws Exception;

}
```

DocumentLoader 中只有一个方法 `loadDocument()` ，该方法接收五个参数：

- inputSource：加载 Document 的 Resource 源
- entityResolver：解析文件的解析器
- errorHandler：处理加载 Document 对象的过程的错误
- validationMode：验证模式
- namespaceAware：命名空间支持。如果要提供对 XML 名称空间的支持，则为true

该方法由 DocumentLoader 的默认实现类 DefaultDocumentLoader 实现，如下：

```java
public Document loadDocument(InputSource inputSource, 
                             EntityResolver entityResolver,
                             ErrorHandler errorHandler, int validationMode,
                             boolean namespaceAware) throws Exception {

    DocumentBuilderFactory factory = 
        createDocumentBuilderFactory(validationMode, namespaceAware);
    
    if (logger.isDebugEnabled()) {
        logger.debug("Using JAXP provider [" + factory.getClass().getName() + "]");
    }
    DocumentBuilder builder =
        createDocumentBuilder(factory, entityResolver, errorHandler);
    return builder.parse(inputSource);
}
```

对于这部分代码并没有太多可以描述的，因为通过SAX解析XML文档的套路大致都差不多，Spring在这里并没有什么特殊的地方。首先调用 `createDocumentBuilderFactory()` 创建 DocumentBuilderFactory ，再通过该 factory创建DocumentBuilder，最后解析InputSource返回Document对象。不过你如果感兴趣可以自己了解一下。

### EntityResolver分析

通过 `loadDocument()` 获取 Document 对象时，有一个参数 entityResolver ，该参数是通过 `getEntityResolver()` 获取的。何为EntityResolver？官网这样解释，如果SAX应用程序需要实现自定义处理外部实体，则必须实现此接口并使用setEntityReslover方法想SAX驱动器注册一个实例。也就是说，对于解析一个XML，SAX首先读取该XML文档上的声明，根据声明去寻找相应的XSD定义，以便对该文档进行一个验证。默认的寻找规则及通过网络（实现上就是声明的XSD的URI地址）来下载相应的XSD声明，并进行验证。下载的过程是一个漫长的过程，而且当网络中断或不可用时，这里会报错，就是因为相应的XSD声明没有被找到的原因。

EntityResolver的作用是项目本省就可以提供一个如何寻找XSD声明的方法，即有程序来实现寻找XSD声明的过程，比如我们将XSD文件放到项目中某处，在实现时直接将此文档读取并返回给SAX即可。这样就避免了通过网络来寻找相应的声明。

首先看entityResolver的接口的方法声明：

InputSource resolveEntity(String publiId,String systemId)

这里，他接受俩个参数publicId和systemId，返回一个InputSource，这个对象不是我们之前介绍的统一资源那个对象，是`org.xml.sax.InputSource`这个对象。下面我们以特定的例子来讲解

1. 如果我们在解析验证模式为XSD的配置文件，代码如下

   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <beans xmlns="http://www.springframework.org/schema/beans"
   	   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   	   xsi:schemaLocation="http://www.springframework.org/schema/beans
          http://www.springframework.org/schema/beans/spring-beans.xsd">
   
   </beans>
   ```

   读到以下俩个参数

   * **publicId**:null

   * **systemId**: http://www.springframework.org/schema/beans/spring-beans.xsd

2. 如果我们在解析验证模式为DTD的配置文件，代码如下

   ```xml
   <!DOCTYPE beans PUBLIC "-//SPRING//DTD BEAN//EN"
   "http://www.springframework.org/dtd/spring-beans.dtd">
   ```

   读取到以下来个参数：

   * **publicId**:"-//SPRING//DTD BEAN//EN"
   * **systemId**：http://www.springframework.org/dtd/spring-beans.dtd


之前已经提到过，验证文件默认的加载方式是通过URL进行网络下载获取，这样会造成延迟，用户体验也不好，一般的做法都是将验证文件防止在自己的工程里，那么怎么做才能将这个URL转换为自己工程里对应的地址文件呢？我们已加载DTD文件为例来看看Spring中是如何实现的。下面先分析`getEntityResolver`，然后具体讲解一下EntityResolver的实现方式

> `getEntityResolver()` 返回指定的解析器，如果没有指定，则构造一个未指定的默认解析器。

```java
    protected EntityResolver getEntityResolver() {
        if (this.entityResolver == null) {
            ResourceLoader resourceLoader = getResourceLoader();
            if (resourceLoader != null) {
                this.entityResolver = new ResourceEntityResolver(resourceLoader);
            }
            else {
                this.entityResolver =
                    	new DelegatingEntityResolver(getBeanClassLoader());
            }
        }
        return this.entityResolver;
    }
```

如果ResourceLoader不为 null，则根据指定的ResourceLoader创建一个ResourceEntityResolver。如果 ResourceLoader为null，则创建一个 DelegatingEntityResolver，该 Resolver 委托给默认的 BeansDtdResolver 和 PluggableSchemaResolver 。

我们就拿DelegatingEntityResolver来具体分析

```java

	public InputSource resolveEntity(String publicId, @Nullable String systemId)
        throws SAXException, IOException {
		if (systemId != null) {
            // 如果是DTD从这里解析
			if (systemId.endsWith(DTD_SUFFIX)) {
				return this.dtdResolver.resolveEntity(publicId, systemId);
			}
            // 如果是XSD，这里进行解析
			else if (systemId.endsWith(XSD_SUFFIX)) {
				return this.schemaResolver.resolveEntity(publicId, systemId);
			}
		}
		return null;
	}

```

可以看到，对不同的验证模式，spring使用了不同的解析器解析。这里简单描述一下原理，比如加载DTD类型的BeansDtdResolver的resolveEntity是直接截取systemId最后的xx.dtd然后去当前路径下寻找，而加载XSD类型的PluggableSchemaResolver类的resolveEntity是默认到`META-INF/spring.schemas`文件中找到systemId所对应的XSD文件并加载。

BeansDtdResolver 的解析过程如下:

```java
public InputSource resolveEntity(String publicId, @Nullable String systemId) 
    throws IOException {
    if (logger.isTraceEnabled()) {
        logger.trace("Trying to resolve XML entity with public ID [" + publicId +
                     "] and system ID [" + systemId + "]");
    }
    if (systemId != null && systemId.endsWith(DTD_EXTENSION)) {
        int lastPathSeparator = systemId.lastIndexOf('/');
        int dtdNameStart = systemId.indexOf(DTD_NAME, lastPathSeparator);
        if (dtdNameStart != -1) {
            String dtdFile = DTD_NAME + DTD_EXTENSION;
            if (logger.isTraceEnabled()) {
                logger.trace("Trying to locate [" + dtdFile 
                             + "] in Spring jar on classpath");
            }
            try {
                Resource resource = new ClassPathResource(dtdFile, getClass());
                InputSource source = new InputSource(resource.getInputStream());
                source.setPublicId(publicId);
                source.setSystemId(systemId);
                if (logger.isDebugEnabled()) {
                    logger.debug("Found beans DTD [" + 
                                 systemId + "] in classpath: " + dtdFile);
                }
                return source;
            }
            catch (IOException ex) {
                if (logger.isDebugEnabled()) {
                    logger.debug("Could not resolve beans DTD [" + 
                                 systemId + "]: not found in classpath", ex);
                }
            }
        }
    }
    return null;
}
```

从上面的代码中我们可以看到加载 DTD 类型的 `BeansDtdResolver.resolveEntity()` 只是对 systemId 进行了简单的校验（从最后一个 / 开始，内容中是否包含 `spring-beans`），然后构造一个 InputSource 并设置 publicId、systemId，然后返回。

PluggableSchemaResolver 的解析过程如下:

```java
public InputSource resolveEntity(String publicId, @Nullable String systemId)
    throws IOException {
    if (logger.isTraceEnabled()) {
        logger.trace("Trying to resolve XML entity with public id [" + publicId +
                     "] and system id [" + systemId + "]");
    }

    if (systemId != null) {
        String resourceLocation = getSchemaMappings().get(systemId);
        if (resourceLocation != null) {
            Resource resource = 
                new ClassPathResource(resourceLocation, this.classLoader);
            try {
                InputSource source = new InputSource(resource.getInputStream());
                source.setPublicId(publicId);
                source.setSystemId(systemId);
                if (logger.isDebugEnabled()) {
                    logger.debug("Found XML schema [" + 
                                 systemId + "] in classpath: " + resourceLocation);
                }
                return source;
            }
            catch (FileNotFoundException ex) {
                if (logger.isDebugEnabled()) {
                    logger.debug("Couldn't find XML schema [" 
                                 + systemId + "]: " + resource, ex);
                }
            }
        }
    }
    return null;
}
```

首先调用 getSchemaMappings() 获取一个映射表(systemId 与其在本地的对照关系)，然后根据传入的 systemId 获取该 systemId 在本地的路径 resourceLocation，最后根据 resourceLocation 构造 InputSource 对象。

下面是getSchemaMappings源码

```java
private Map<String, String> getSchemaMappings() {
   Map<String, String> schemaMappings = this.schemaMappings;
   if (schemaMappings == null) {
      synchronized (this) {
         schemaMappings = this.schemaMappings;
         if (schemaMappings == null) {
            if (logger.isTraceEnabled()) {
               logger.trace("Loading schema mappings from [" + 
                            this.schemaMappingsLocation + "]");
            }
            try {
                //加载XSD的配置，默认存储在META-INF/spring.schemas，
                // 你也可以更改这个默认存储，不过一般用不到
               Properties mappings =
             	 PropertiesLoaderUtils.loadAllProperties
                		   (this.schemaMappingsLocation, this.classLoader);
               if (logger.isTraceEnabled()) {
                  logger.trace("Loaded schema mappings: " + mappings);
               }
               schemaMappings = new ConcurrentHashMap<>(mappings.size());
               CollectionUtils.mergePropertiesIntoMap(mappings, schemaMappings);
               this.schemaMappings = schemaMappings;
            }
            catch (IOException ex) {
               throw new IllegalStateException(
                     "Unable to load schema mappings from location [" + 
                   this.schemaMappingsLocation + "]", ex);
            }
         }
      }
   }
   return schemaMappings;
}
```

从上面可以看到，先去加载指定目录下的所有XSD键值对，然后和当前已经存在XSD键值对合并，然后返回一个ConcurrentHashMap来方便查找同时保证了线程安全。

下面简单整理一下上面用到的类：

- ResourceEntityResolver：继承自 EntityResolver ，通过 ResourceLoader 来解析实体的引用。
- DelegatingEntityResolver：EntityResolver 的实现，分别代理了 dtd 的 BeansDtdResolver 和 xml schemas 的 PluggableSchemaResolver。
- BeansDtdResolver ： spring bean dtd 解析器。EntityResolver 的实现，用来从 classpath 或者 jar 文件加载 dtd。
- PluggableSchemaResolver：使用ConcurrentHashMap存储 schema url和本地文件的位置，并将 schema url 解析到本地 classpath 资源，也就是我们自定义标签存放XSD文件的位置，后面我们说解析自定义标签会在说道这里。