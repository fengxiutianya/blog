---
title: spring源码解析之 11bean标签：解析自定义标签
tags:
  - spring源码解析
categories:
  - spring
  - 源码分析
author: fengxiutianya
abbrlink: 20cd1d0c
date: 2019-01-14 05:25:00
---
# spring源码解析之 11bean标签：解析自定义标签

bean标签解析涉及很多的知识点，这里我们先看看最开始解析bean的那段代码，回顾一下
<!-- more-->

```java
    protected void processBeanDefinition(Element ele,
                                         BeanDefinitionParserDelegate delegate) {
        BeanDefinitionHolder bdHolder = delegate.parseBeanDefinitionElement(ele);
        if (bdHolder != null) {
            bdHolder = delegate.decorateBeanDefinitionIfRequired(ele, bdHolder);
            try {
                // Register the final decorated instance.
                BeanDefinitionReaderUtils.registerBeanDefinition(bdHolder,                 
      								 getReaderContext().getRegistry());
            }
            catch (BeanDefinitionStoreException ex) {
                getReaderContext().error(
                    "Failed to register bean definition with name '" +
                        bdHolder.getBeanName() + "'", ele, ex);
            }
            // Send registration event.
            getReaderContext().fireComponentRegistered(
                new BeanComponentDefinition(bdHolder));                                
        }
    }
```

`processBeanDefinition()` 负责 Bean 标签的解析，在解析过程中首先调用`BeanDefinitionParserDelegate.parseBeanDefinitionElement()` 完成默认标签的解析，如果解析成功（返回的 bdHolder != null ），则首先调用 `BeanDefinitionParserDelegate.decorateBeanDefinitionIfRequired()` 完成自定义标签元素解析，前面文章已经分析了默认标签的解析，所以这篇文章分析自定义标签的解析。首先大致了解下这句话的作用，其实我们可以从语义上分析：如果需要的话就对beanDefinition进行装饰，那这句话代码到底是什么功能呢？在bean属性解析过程中，有俩种类型：一种是默认类型的解析，另一种是自定义类型的解析，这里就是自定义类型的解析。前面我们也说过自定义标签的解析，为什么会在默认类型解析中单独添加一个方法处理呢？这个是因为，我们之前见过的那种类型是bean标签一级的自定义标签解析，这里我们看到的自定义类型其实是属性。就像下面这样：

```xml
<bean id="" name="">
	<myBean:user username="aaa"/>
</bean>
```

当spring中的bean使用的是默认的标签配置，但是其中的子元素却是用了自定义的配置，这句代码便会起作用。

```java
public BeanDefinitionHolder decorateBeanDefinitionIfRequired(Element ele, 
                   BeanDefinitionHolder definitionHolder) {
    return decorateBeanDefinitionIfRequired(ele, definitionHolder, null);
}
```

调用 `decorateBeanDefinitionIfRequired()` ：

```java
    public BeanDefinitionHolder decorateBeanDefinitionIfRequired(
            Element ele, BeanDefinitionHolder definitionHolder, 
        	@Nullable BeanDefinition containingBd) {

        BeanDefinitionHolder finalDefinition = definitionHolder;

        // 遍历所有的属性，查看是否有适用于装饰的属性
        NamedNodeMap attributes = ele.getAttributes();
        for (int i = 0; i < attributes.getLength(); i++) {
            Node node = attributes.item(i);
            finalDefinition = decorateIfRequired(node, finalDefinition, containingBd);
        }

        // 遍历子节点，查看是否有适用于修饰的子元素
        NodeList children = ele.getChildNodes();
        for (int i = 0; i < children.getLength(); i++) {
            Node node = children.item(i);
            if (node.getNodeType() == Node.ELEMENT_NODE) {
                finalDefinition = 
                    decorateIfRequired(node, finalDefinition, containingBd);
            }
        }
        return finalDefinition;
    }
```

上面代码，看到函数分别对元素和所有属性以及子节点进行了decorateIfRequired函数的调用，

遍历节点（子节点），调用 `decorateIfRequired()` 装饰节点（子节点）。

```java
    public BeanDefinitionHolder decorateIfRequired(
            Node node, BeanDefinitionHolder originalDef,
        	@Nullable BeanDefinition containingBd) {
        // 获取自定义标签的命名空间
        String namespaceUri = getNamespaceURI(node);
        // 过滤掉默认命名标签
        if (namespaceUri != null && !isDefaultNamespace(namespaceUri)) {
            // 获取相应的处理器
            NamespaceHandler handler = 
                this.readerContext.getNamespaceHandlerResolver().resolve(namespaceUri);
            if (handler != null) {
                // 进行装饰处理
                BeanDefinitionHolder decorated =
                        handler.decorate(node, originalDef,
                          new ParserContext(this.readerContext, this, containingBd));
                if (decorated != null) {
                    return decorated;
                }
            }
            else if (namespaceUri.startsWith("http://www.springframework.org/")) {
                error("Unable to locate Spring NamespaceHandler 
                      	for XML schema namespace [" + 
                     namespaceUri + "]", node);
            }
            else {
                if (logger.isDebugEnabled()) {
                    logger.debug("No Spring NamespaceHandler 
                   	  found for XML schema namespace [" + namespaceUri + "]");
                }
            }
        }
        return originalDef;
    }
```

首先获取自定义标签的命名空间，如果不是默认的命名空间则根据该命名空间获取相应的处理器，最后调用处理器的 `decorate()` 进行装饰处理。具体的装饰过程这里不进行讲述，在后面分析自定义标签时会做详细说明。

至此，Bean 的解析过程已经全部完成了，下面做一个简要的总结。

解析 BeanDefinition 的入口在 `DefaultBeanDefinitionDocumentReader.parseBeanDefinitions()` 。该方法会根据命令空间来判断标签是默认标签还是自定义标签，其中默认标签由 `parseDefaultElement()` 实现，自定义标签由 `parseCustomElement()` 实现。在默认标签解析中，会根据标签名称的不同进行 import 、alias 、bean 、beans 四大标签进行处理，其中 bean 标签的解析为核心，它由 `processBeanDefinition()` 方法实现。`processBeanDefinition()` 开始进入解析核心工作，分为三步：

1. 解析默认标签：`BeanDefinitionParserDelegate.parseBeanDefinitionElement()`
2. 解析默认标签下的自定义标签：`BeanDefinitionParserDelegate.decorateBeanDefinitionIfRequired()`
3. 注册解析的 BeanDefinition：`BeanDefinitionReaderUtils.registerBeanDefinition`

在默认标签解析过程中，核心工作由 `parseBeanDefinitionElement()` 方法实现，该方法会依次解析 Bean 标签的属性、各个子元素，解析完成后返回一个 GenericBeanDefinition 实例对象。