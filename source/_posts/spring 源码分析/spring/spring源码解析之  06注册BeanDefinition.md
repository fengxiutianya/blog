abbrlink: 25
title: spring 源码分析之 06注册BeanDefinition
tags:
  - spring源码解析
  - ''
categories:
  - spring
author: fengxiutianya
date: 2019-01-14 04:58:00
---
# spring 源码解析之 06注册BeanDefinition

#### registerBeanDefinitions

获取 Document 对象后，会根据该对象和 Resource 资源对象调用 `registerBeanDefinitions()` 方法，开始注册 BeanDefinitions 之旅。如下：
<!-- more-->

```java
    public int registerBeanDefinitions(Document doc, Resource resource) 
        throws BeanDefinitionStoreException {
        //用DefaultBeanDefinitionDocumentReader实例化BeanDefinitionDocumentReader
        BeanDefinitionDocumentReader documentReader = 
            createBeanDefinitionDocumentReader();
        // 记录注册BeanDefinition之前的个数
        int countBefore = getRegistry().getBeanDefinitionCount();
        // 注册BeanDefinition
        documentReader.registerBeanDefinitions(doc, createReaderContext(resource));
        //记录本次加载BeanDefinition的个数
        return getRegistry().getBeanDefinitionCount() - countBefore;
    }
```

首先调用 `createBeanDefinitionDocumentReader()` 方法实例化 BeanDefinitionDocumentReader 对象，然后获取统计前 BeanDefinition 的个数，最后调用 `registerBeanDefinitions()` 注册 BeanDefinition。

实例化 BeanDefinitionDocumentReader 对象方法如下：

```java
    protected BeanDefinitionDocumentReader createBeanDefinitionDocumentReader() {
        return BeanDefinitionDocumentReader.class.cast(
            BeanUtils.instantiateClass(this.documentReaderClass));
    }
```

注册 BeanDefinition 的方法 `registerBeanDefinitions()` 是在接口 BeanDefinitionDocumentReader 中定义，如下：

```java
    void registerBeanDefinitions(Document doc, XmlReaderContext readerContext)
            throws BeanDefinitionStoreException;
```

**从给定的 Document 对象中解析定义的 BeanDefinition 并将他们注册到注册表中**。方法接收两个参数，待解析的 Document 对象，以及解析器的当前上下文，包括目标注册表和被解析的资源。其中 readerContext 是根据 Resource 来创建的，如下：

```java
    public XmlReaderContext createReaderContext(Resource resource) {
        return new XmlReaderContext(resource, this.problemReporter, this.eventListener,
                this.sourceExtractor, this, getNamespaceHandlerResolver());
    }
```

DefaultBeanDefinitionDocumentReader 对BeanDefinitionDocumentReader默认实现，具体的注册BeanDefinition代码如下：

```java
    public void registerBeanDefinitions(Document doc, XmlReaderContext readerContext) {
        this.readerContext = readerContext;
        logger.debug("Loading bean definitions");
        Element root = doc.getDocumentElement();
        doRegisterBeanDefinitions(root);
    }
```

这个方法的主要目的就是提取root，以便于再次将root作为参数继续BeanDefinition的注册，接着就是注册的核型逻辑，调用 `doRegisterBeanDefinitions()` 开启注册 BeanDefinition 之旅

```java
    protected void doRegisterBeanDefinitions(Element root) {
        BeanDefinitionParserDelegate parent = this.delegate;
        this.delegate = createDelegate(getReaderContext(), root, parent);

        if (this.delegate.isDefaultNamespace(root)) {
             // 处理 profile
            String profileSpec = root.getAttribute(PROFILE_ATTRIBUTE);
            if (StringUtils.hasText(profileSpec)) {
                String[] specifiedProfiles = 
                    StringUtils.tokenizeToStringArray(
                        profileSpec, 
                   BeanDefinitionParserDelegate.MULTI_VALUE_ATTRIBUTE_DELIMITERS);
                if (!getReaderContext().getEnvironment()
                    	.acceptsProfiles(specifiedProfiles)) {
                    if (logger.isInfoEnabled()) {
                        logger.info("Skipped XML bean definition file 
                                    	due to specified profiles [" + 
                                    profileSpec +
                                "] not matching: " + getReaderContext().getResource());
                    }
                    return;
                }
            }
        }

        // 解析前处理
        preProcessXml(root);
        // 解析
        parseBeanDefinitions(root, this.delegate);
        // 解析后处理
        postProcessXml(root);

        this.delegate = parent;
    }
```

程序首先处理 profile属性，profile主要用于我们切换环境，比如切换开发、测试、生产环境，非常方便。然后调用 `parseBeanDefinitions()` 进行解析动作，不过在该方法之前之后分别调用 `preProcessXml()` 和 `postProcessXml()`方法来进行前、后处理，目前这两个方法都是空实现，既然是空的写着还有什么用呢？就像面向对象设计方法学中常说的一句话，一个类要么是面向继承设计的，要么就用final修饰。在DefaultBeanDefinitionDocumentReader中并没有用final修饰，所以它是面向继承而设计的。这俩个方法正是为子类而设计的，如果读者有了解过设计模式，可以很快速地反映出这是模板方法修饰，如果继承自DefaultBeanDefinitionDocumentReader的子类需要在bean解析前后做一些处理的话，那么只需要重写这俩个方法。

```java
    protected void preProcessXml(Element root) {
    }

    protected void postProcessXml(Element root) {
    }
```

#### profile属性的作用

从上面的代码可以注意到。在注册Bean的最开始是对PROFILE_ATTRIBUTE属性的解析，可能对于我们来说，profile并不是很常用，所以首先了解一下这个属性。

分析profile💰我们先了解下profile的用法，示例如下：

```java
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
	   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	   xsi:schemaLocation="http://www.springframework.org/schema/beans
       http://www.springframework.org/schema/beans/spring-beans.xsd">
	<bean id="dateFoo" class="com.zhangke.common.DateFoo">
		<property name="date">
			<value>2007/10/1</value>
		</property>
	</bean>

	<beans profile="dev">
		<!-- dev开发环境下定义-->
	</beans>
	<beans profile="production">
		<!-- production测试环境下定义-->
	</beans>
</beans>
```

集成到web环境时，在webx.xml中加入以下代码：

```xml
<context-param>
	<param-name>Spring.profiles.active</param-name>
    <param-value>dev</param-value>
</context-param>
```

从上可以看出，有了这个特性，可以同时在配置文件中部署俩套配置来使用与生产环境和开发环境，这样可以方便的进行切换开发、部署环境，这在开发过程中经常使用到，最常用的莫过于更换不同的数据库。

从上面你应该大体上了解profile的使用，下面我们着重分析一下上面在解析BeanDefinition前的profile的处理。首先程序会获取当前节点的命名空间是否是默认命名空间，也就是spring官方提供的节点定义，（这里不包括context，util这些节点，默认命名空间可以去看我前面的博客[spring源码分析之获取xml的验证模型]()）,然后就检测beans节点是否定义了profile属性，如果定义了则会需要到开发环境变量中去寻找，所以这里县断言profile属性值不可能为空，如果为空，则代表着所有的环境都需要包含此配置。因为profile是可以同时制定多个的，需要程序对其拆分，并解析多个profile中是否有符合环境变量中定义的，不定义则不会去解析。

#### 解析并注册BeanDefinition

处理了profile后就可以进行XML的读取，`parseBeanDefinitions()` 定义如下：

```java
    protected void parseBeanDefinitions(Element root, 
                                        	BeanDefinitionParserDelegate delegate) {
        // 对beans的处理
        if (delegate.isDefaultNamespace(root)) {
            NodeList nl = root.getChildNodes();
            for (int i = 0; i < nl.getLength(); i++) {
                Node node = nl.item(i);
                if (node instanceof Element) {
                    Element ele = (Element) node;
                    // 默认环境节点的处理
                    if (delegate.isDefaultNamespace(ele)) {
                        parseDefaultElement(ele, delegate);
                    }
                    else {
                        // 自定义节点的处理
                        delegate.parseCustomElement(ele);
                    }
                }
            }
        }
        else {
            // 自定义节点处理
            delegate.parseCustomElement(root);
        }
    }
```

最终解析动作落地在两个方法处：`parseDefaultElement(ele, delegate)` 和 `delegate.parseCustomElement(root)`。我们知道在 Spring 有两种 Bean 声明方式：

- 配置文件式声明：`<bean id="studentService" class="org.springframework.core.StudentService"/>`
- 自定义注解方式：`<tx:annotation-driven>`

两种方式的读取和解析都存在较大的差异，所以采用不同的解析方法，如果采用Spring默认的配置，Spring当然知道该怎么做，但是如果是自定义的，那么就需要用户实现一些借口即配置了。如果根节点或者子节点采用默认命名空间的话，则调用 `parseDefaultElement()` 进行解析，否则调用 `delegate.parseCustomElement()` 方法对自定义命名空间进行解析。而判断是否默认空间还是自定义四命名空间的办法其实使用node.getNAmespaceURI获取命名空间，并与Spring中固定的命名空间`http://www.Springframework.org/schema/beans`进行比对。如果一直则认为是默认，否则就认为是自定义。其实你可以这样简单里面，如果是默认空间写法如下

```xml
<属性名> 属性值 </属性名>
```

自定义写法如下:

```xml
<命名空间：属性名> 属性值 </命名空间：属性名>
```

因为默认命名空间，xml规定可以在属性名前面不用写命名空间。所以你现在可以很容易的分辨你写的xm中哪些是自定义哪些是默认。

再多说一点，在springframework官方文档中，[Appendix](https://docs.spring.io/spring/docs/current/spring-framework-reference/core.html#appendix)中定义了几个方便开发的xml Schema，原理就是在这。不过后面会讲如何自定义属性，这里只是简单提一下。

至此，`doLoadBeanDefinitions()` 中做的三件事情已经全部分析完毕，下面将对 Bean 的解析过程做详细分析说明。