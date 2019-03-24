---
title: 'spring源码解析之 07bean标签:开启解析进程'
tags:
  - spring源码解析
categories:
  - java
  - spring
  - spring 源码分析
  - SpringCore
author: fengxiutianya
abbrlink: 6a25672f
date: 2019-01-14 05:11:00
---
# spring 源码解析之bean标签:开启解析进程

### 概述

1. parseDefaultElement
2. processBeanDefinition (bean标签的解析即注册)
3. 解析BeanDefinition
<!-- more-->

### parseDefaultElement

Spring 中有两种解析 Bean 的方式。如果根节点或者子节点采用默认命名空间的话，则调用 `parseDefaultElement()` 进行默认标签解析，否则调用 `delegate.parseCustomElement()` 方法进行自定义解析。下面就这两个方法进行详细分析说明，先从默认标签解析过程开始，源码如下：

```java
private void parseDefaultElement(Element ele, 
                                 BeanDefinitionParserDelegate delegate) {
    // 对 import 标签的解析
    if (delegate.nodeNameEquals(ele, IMPORT_ELEMENT)) {
        importBeanDefinitionResource(ele);
    }
    // 对 alias 标签的解析
    else if (delegate.nodeNameEquals(ele, ALIAS_ELEMENT)) {
        processAliasRegistration(ele);
    }
    // 对 bean 标签的解析
    else if (delegate.nodeNameEquals(ele, BEAN_ELEMENT)) {
        processBeanDefinition(ele, delegate);
    }
    // 对 beans 标签的解析
    else if (delegate.nodeNameEquals(ele, NESTED_BEANS_ELEMENT)) {
        // recurse
        doRegisterBeanDefinitions(ele);
    }
}
```

方法的功能一目了然，分别是对四种不同的标签进行解析，分别是 import、alias、bean、beans。咱门从常用的标签bean 开始，如果能理解此标签的解析过程，其他的标签的解析自然会迎刃而解。

### processBeanDefinition (bean标签的解析即注册)

如果遇到标签为 bean 则调用 `processBeanDefinition()` 方法进行 bean 标签解析，如下：

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
        
        getReaderContext().fireComponentRegistered(
            new BeanComponentDefinition(bdHolder));                                
    }
}
```

整个过程分为四个步骤

1. 调用 `BeanDefinitionParserDelegate.parseBeanDefinitionElement()` 进行元素解析，解析过程中如果失败，返回 null，错误由 `ProblemReporter` 处理。如果解析成功则返回 BeanDefinitionHolder 实例 bdHolder。BeanDefinitionHolder是对BeanDefinition简单装饰，里面持有bean name 和alias的 BeanDefinition。
2. 若实例bdHolder不为空，则调用 `BeanDefinitionParserDelegate.decorateBeanDefinitionIfRequired()`进行自定义标签处理
3. 解析完成后，则调用 `BeanDefinitionReaderUtils.registerBeanDefinition()` 对 bdHolder 进行注册
4. 发出响应事件，通知相关的监听器，完成 Bean 标签解析

### 解析BeanDefinition

下面我们就针对各个操作做具体分析。首先我们从元素解析即信息提取开始，也就是`BeanDefinitionHolder bdHolder = delegate.parseBeanDefinitionElement(ele);` 进入BeanDefinitionDelegate类的parseBeanDefinitionElement方法。

```java
@Nullable
public BeanDefinitionHolder parseBeanDefinitionElement(Element ele, 
                              @Nullable BeanDefinition containingBean) {
    // 解析id属性
    String id = ele.getAttribute(ID_ATTRIBUTE);
    // 解析name属性
    String nameAttr = ele.getAttribute(NAME_ATTRIBUTE);
    // 分割name属性，同一个name属性中可以指定多个name，用分割符改开
    List<String> aliases = new ArrayList<>();
    if (StringUtils.hasLength(nameAttr)) {
        String[] nameArr = StringUtils.tokenizeToStringArray(nameAttr, 
				MULTI_VALUE_ATTRIBUTE_DELIMITERS);
        aliases.addAll(Arrays.asList(nameArr));
    }

    // 设置beanName 如果有id，则设置id值，如果不存在，则使用name属性值的第一个元素
    String beanName = id;
    if (!StringUtils.hasText(beanName) && !aliases.isEmpty()) {
        beanName = aliases.remove(0);
        if (logger.isTraceEnabled()) {
            logger.trace("No XML 'id' specified - using '" + beanName +
                         "' as bean name and " + aliases + " as aliases");
        }
    }

    // 检查name的唯一性,也包括对别名的检查，不为空则说明是第二次解析，这个后面说道循环应用会讲解
    if (containingBean == null) {
        checkNameUniqueness(beanName, aliases, ele);
    }
    // 解析属性，构造 AbstractBeanDefinition
    AbstractBeanDefinition beanDefinition = parseBeanDefinitionElement(ele,
                                         beanName, containingBean);
    if (beanDefinition != null) {
        // 如果 beanName 不存在，则根据条件构造一个 beanName
        if (!StringUtils.hasText(beanName)) {
            try {
                if (containingBean != null) {
                    beanName = BeanDefinitionReaderUtils.generateBeanName(
                        beanDefinition, this.readerContext.getRegistry(), 
                        true);
                }
                else {
                    beanName = this.readerContext.generateBeanName(beanDefinition);
                    // 如果此bean的className没有使用，则注册此bean的className
                    // 为此bean的别名
                    String beanClassName = beanDefinition.getBeanClassName();
                    if (beanClassName != null &&
                        beanName.startsWith(beanClassName) &&
                        beanName.length() > beanClassName.length() &&
                        !this.readerContext.getRegistry().isBeanNameInUse(beanClassName)
                       ) {
                        aliases.add(beanClassName);
                    }
                }
                if (logger.isTraceEnabled()) {
                    logger.trace("Neither XML 'id' nor 'name' specified - " +
                                 "using generated bean name [" + beanName + "]");
                }
            }
            catch (Exception ex) {
                error(ex.getMessage(), ele);
                return null;
            }
        }
        String[] aliasesArray = StringUtils.toStringArray(aliases);
        // 封装BeanDefinitionHolder
        return new BeanDefinitionHolder(beanDefinition, beanName, aliasesArray);
    }
    return null;
}
```

这个方法还没有对Bean标签进行解析，只是在解析动作之前做了一些功能架构，主要的工作有：

- 解析 id、name 属性，确定 alias 集合，检测 beanName 是否唯一
- 调用方法 `parseBeanDefinitionElement()` 对属性进行解析并封装成 GenericBeanDefinition实例 beanDefinition
- 如果检测到bean没有指定beanName，那么使用默认规则为此Bean生成beanName
- 根据所获取的信息（beanName、aliases、beanDefinition）构造 BeanDefinitionHolder 实例对象并返回。

这里有必要说下 beanName 的命名规则：

1. 如果 id 不为空，则 beanName = id。
2. 如果 id 为空，但是 alias 不空，则 beanName 为 alias 的第一个元素。
3. 如果两者都为空，则根据默认规则来设置 beanName。

上面三个步骤第二个步骤为核心方法，它主要承担解析 Bean 标签中所有的属性值。如下：

```java
public AbstractBeanDefinition parseBeanDefinitionElement(
    Element ele, String beanName, @Nullable BeanDefinition containingBean) {

    // 设置当前BeanDefinition正在被解析
    this.parseState.push(new BeanEntry(beanName));

    String className = null;
    // 解析 class 属性
    if (ele.hasAttribute(CLASS_ATTRIBUTE)) {
        className = ele.getAttribute(CLASS_ATTRIBUTE).trim();
    }
    String parent = null;

    // 解析 parent 属性
    if (ele.hasAttribute(PARENT_ATTRIBUTE)) {
        parent = ele.getAttribute(PARENT_ATTRIBUTE);
    }

    try {
        // 创建用于承载属性的 GenericBeanDefinition 实例
        AbstractBeanDefinition bd = createBeanDefinition(className, parent);

        // 解析默认 bean 的各种属性
        parseBeanDefinitionAttributes(ele, beanName, containingBean, bd);

        // 提取 description
        bd.setDescription(DomUtils.getChildElementValueByTagName(ele, 
                                                                 DESCRIPTION_ELEMENT));
        // 解析元数据
        parseMetaElements(ele, bd);

        // 解析 lookup-method 属性
        parseLookupOverrideSubElements(ele, bd.getMethodOverrides());

        // 解析 replaced-method 属性
        parseReplacedMethodSubElements(ele, bd.getMethodOverrides());

        // 解析构造函数参数
        parseConstructorArgElements(ele, bd);

        // 解析 property 子元素
        parsePropertyElements(ele, bd);

        // 解析 qualifier 子元素
        parseQualifierElements(ele, bd);

        bd.setResource(this.readerContext.getResource());
        bd.setSource(extractSource(ele));

        return bd;
    }
    catch (ClassNotFoundException ex) {
        。。。。省略异常
    }
    finally {
        // 弹出当前正在解析BeanDefinition，说明已经解析完成
        this.parseState.pop();
    }
    return null;
}
```

到这里，Bean标签的所有属性我们都可以看到其解析的过程，也就说到这里我们已经解析一个基本可用的 BeanDefinition。

由于篇幅有点长，在下面文章中将对此进行仔细分析。