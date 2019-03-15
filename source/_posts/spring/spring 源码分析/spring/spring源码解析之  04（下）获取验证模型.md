abbrlink: 35
title: spring源码解析之 04（下）获取验证模型
tags:
  - spring源码解析
categories:
  - spring
author: fengxiutianya
date: 2019-01-14 04:47:00
---
# spring源码解析之 04(下)获取验证模型

## 概述

1. DTD与XSD的区别
2. getValidationModeForResource() 分析

上一篇博客我们已经提到过，在核心逻辑方法 `doLoadBeanDefinitions()`中主要是做三件事情。

1. 调用 `getValidationModeForResource()` 获取 xml 文件的验证模式
2. 调用 `loadDocument()` 根据 xml 文件获取相应的 Document 实例。
3. 调用 `registerBeanDefinitions()` 注册 Bean 实例。

这篇博客主要来分析获取xml文件的验证模式

<!-- more -->

## DTD与XSD的区别

了解XML文件的读者都应该知道XML文件的验证模式保证了XML文件的正确性，而比较常用的验证模式有俩种：DTD和XSD。

### DTD

DTD(Document Type Definition)，即文档类型定义，为 XML 文件的验证机制，属于 XML 文件中组成的一部分。DTD 是一种保证XML文档格式正确的有效验证方式，它定义了相关XML文档的元素、属性、排列方式、元素的内容类型以及元素的层次结构。其实 DTD 就相当于XML中的 “词汇”和“语法”，我们可以通过比较XML文件和DTD文件来看文档是否符合规范，元素和标签使用是否正确。

要在 Spring 中使用DTD，需要在Spring XML文件头部声明：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE beans PUBLIC  "-//SPRING//DTD BEAN//EN"  "http://www.springframework.org/dtd/spring-beans.dtd">
```

DTD在一定的阶段推动了XML的发展，但是它本身存在着一些缺陷：

1. 它没有使用XML格式，而是自己定义了一套格式，相对解析器的重用性较差；而且 DTD 的构建和访问没有标准的编程接口，因而解析器很难简单的解析DTD文档。
2. DTD对元素的类型限制较少；同时其他的约束力也叫弱。
3. DTD 扩展能力较差。
4. 基于正则表达式的 DTD 文档的描述能力有限。

### XSD

对 DTD 的缺陷，W3C在2001年推出XSD。XSD（XML Schemas Definition）即XML Schema语言。XML Schema描述了XML文档的结构。可以用一个指定的XML Schema来验证某个XML文档，以检查该XML文档是否符合其要求。文档设计者可以通过Xml Schema指定一个XML文档所允许的结构和内容，并可据此检查一个XML文档是否有效。XML Schema 本身就是一个 XML文档，使用的是 XML 语法，因此可以很方便的解析 XSD 文档。相对于 DTD，XSD 具有如下优势：

- XML Schema基于XML,没有专门的语法
- XML Schema可以象其他XML文件一样解析和处理
- XML Schema比DTD提供了更丰富的数据类型.
- XML Schema提供可扩充的数据模型。
- XML Schema支持综合命名空间
- XML Schema支持属性组。

在使用XML Schema文档对XML示例文档进行校验，除了要声明名称空间外，还必须指定该名称空间所对应的XML Schema文档的存储位置。通过schmaLocation属性来制定名称空间所对应的XML Schema文档的存储位置，它包含俩个部分，一部分是名称空间URI，另一部分就是该名称空间所表示的XML Schema文件位置或URL地址。如果对这一块不是很懂，可以看下面这篇文章

[关于XML文档的xmlns、xmlns:xsi和xsi:schemaLocation](https://my.oschina.net/itblog/blog/390001)

spring配置文件中经常使用的例子

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
	   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	   xsi:schemaLocation="http://www.springframework.org/schema/beans
       http://www.springframework.org/schema/beans/spring-beans.xsd">


</beans>
```

经过上面的介绍，你应该对xml的验证模式有了基本的了解，下面一起看spring中验证模式获取

##  getValidationModeForResource() 分析

```java
protected int getValidationModeForResource(Resource resource) {
		int validationModeToUse = getValidationMode();
		// 如果用户已经设置，则使用用户设置的验证模式
		if (validationModeToUse != VALIDATION_AUTO) {
			return validationModeToUse;
		}
		// 根据资源查找验证模式
		int detectedMode = detectValidationMode(resource);
		if (detectedMode != VALIDATION_AUTO) {
			return detectedMode;
		}
		// 如果没有查找到具体的验证模式，也就是代表在查找到跟标记之前没有出现DTD，
        // 就默认设置成XSD验证模式
		return VALIDATION_XSD;
	}
```

如果指定了 XML 文件的的验证模式（调用`XmlBeanDefinitionReader.setValidating(boolean validating)`）则直接返回指定的验证模式，否则调用 `detectValidationMode()` 获取相应的验证模式，如下：

```java
protected int detectValidationMode(Resource resource) {
    // 资源已经打开过，则抛出异常
    if (resource.isOpen()) {
        。。。。省略异常代码
    }

    InputStream inputStream;
    
    try {
        // 获取资源
        inputStream = resource.getInputStream();
    }
    catch (IOException ex) {
      	。。。省略异常代码
    }

    try {
        // 核心方法
        return this.validationModeDetector.detectValidationMode(inputStream);
    }
    catch (IOException ex) {
    	 。。。。省略异常代码
    }
}
```

前面一大堆的代码，核心在于 `this.validationModeDetector.detectValidationMode(inputStream)`，validationModeDetector 定义为 `XmlValidationModeDetector`,所以验证模式的获取委托给 `XmlValidationModeDetector` 的 `detectValidationMode()` 方法。

```java
public int detectValidationMode(InputStream inputStream) throws IOException {
    BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream));
    try {
        boolean isDtdValidated = false;
        String content;
        // 一行一行读取 xml 文件的内容
        while ((content = reader.readLine()) != null) {
            content = consumeCommentTokens(content);
            // 如果为注释，则跳过
            if (this.inComment || !StringUtils.hasText(content)) {
                continue;
            }
            // 包含 DOCTYPE 为 DTD 模式
            if (hasDoctype(content)) {
                isDtdValidated = true;
                break;
            }
            // 读取 < 开始符号，验证模式一定会在 < 符号之前
            if (hasOpeningTag(content)) {
                // End of meaningful data...
                break;
            }
        }
        // 为 true 返回 DTD，否则返回 XSD
        return (isDtdValidated ? VALIDATION_DTD : VALIDATION_XSD);
    }
    catch (CharConversionException ex) {
        // 出现异常，为 XSD
        return VALIDATION_AUTO;
    }
    finally {
        reader.close();
    }
}
```

从代码中看，主要是通过读取 XML 文件的内容，判断内容中是否包含有DOCTYPE ，如果是则为DTD，否则为 XSD，当然只会读取到第一个`<` 处，因为验证模式一定会在第一个`<`之前。如果当中出现了 `CharConversionException`异常，则为XSD模式。

好了，XML 文件的验证模式分析完毕，下篇分析 `doLoadBeanDefinitions()` 的第二个步骤：获取 Document 实例。