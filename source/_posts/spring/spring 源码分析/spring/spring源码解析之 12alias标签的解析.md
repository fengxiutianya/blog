abbrlink: 31
title: spring源码解析之 12alias、import、beans标签的解析
tags:
  - spring源码解析
categories:
  - spring
author: fengxiutianya
date: 2019-01-14 05:32:00
---
### 概述

1. alias标签解析
2. import标签解析
3. 嵌入式beans标签解析

通过前面较长的篇幅我们终于完成了默认标签中对bean标签的处理，那么我们之前提到过，对配置文件的解析包括对import标签，alias标签、bean标签的处理，而这三个的解析也是围绕着bean标签。下面我们先来看alias标签的解析。

在bean进行定义时，除了使用id属性来制定名称之外，为了提供多个名称，可以使用alias标签来指定，而所有的这些名称都指向统一bean，在某些情况下提供别名非常有用，比如为了让应用的 每一个组件都能更容易地对公共组件进行引用。
<!-- more-->
在xml中可以使用如下格式来指定bean的别名

```xml
<bean  id="testbean" class=""></bean>
<alias name="testbean" alias="test1,test2"></alias>
```

下面我们来深入分析下对于alias标签的解析过程

```java
protected void processAliasRegistration(Element ele) {
    	//获取beannanme
		String name = ele.getAttribute(NAME_ATTRIBUTE);
		// 获取alias
    	String alias = ele.getAttribute(ALIAS_ATTRIBUTE);
		boolean valid = true;
		if (!StringUtils.hasText(name)) {
			getReaderContext().error("Name must not be empty", ele);
			valid = false;
		}
		if (!StringUtils.hasText(alias)) {
			getReaderContext().error("Alias must not be empty", ele);
			valid = false;
		}
		if (valid) {
			try {
                //注册alias
				getReaderContext().getRegistry().registerAlias(name, alias);
			}
			catch (Exception ex) {
				getReaderContext().error("Failed to register alias '" + alias +
						"' for bean with name '" + name + "'", ele, ex);
			}
            //别名注册后通知监听器做响应的处理
			getReaderContext().fireAliasRegistered(name, alias, extractSource(ele));
		}
	}
```

可以发现，跟之前讲过的bean中的alias注册大同小异，都是将别名与beanName组成一对注册到registry中。

### import标签解析

经历过 Spring 配置文件的小伙伴都知道，如果工程比较大，配置文件的维护会让人觉得恐怖，文件太多了，想象将所有的配置都放在一个 spring.xml 配置文件中，哪种后怕感是不是很明显？所有针对这种情况 Spring 提供了一个分模块的思路，利用 import 标签，例如我们可以构造一个这样的 spring.xml。

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="http://www.springframework.org/schema/beans
       http://www.springframework.org/schema/beans/spring-beans.xsd">

    <import resource="spring-student.xml"/>
    <import resource="spring-student-dtd.xml"/>
</beans>
```

spring.xml 配置文件中使用 import 标签的方式导入其他模块的配置文件，如果有配置需要修改直接修改相应配置文件即可，若有新的模块需要引入直接增加 import 即可，这样大大简化了配置后期维护的复杂度，同时也易于管理。

Spring 利用 `importBeanDefinitionResource()` 方法完成对 import 标签的解析。

```java
    protected void importBeanDefinitionResource(Element ele) {
        // 获取 resource 的属性值 
        String location = ele.getAttribute(RESOURCE_ATTRIBUTE);
        // 为空，直接退出
        if (!StringUtils.hasText(location)) {
            getReaderContext().error("Resource location must not be empty", ele);
            return;
        }

        // 解析系统属性，格式如 ："${user.dir}"
        location = getReaderContext().
            	getEnvironment().resolveRequiredPlaceholders(location);

        Set<Resource> actualResources = new LinkedHashSet<>(4);

        // 判断 location 是相对路径还是绝对路径
        boolean absoluteLocation = false;
        try {
            absoluteLocation = ResourcePatternUtils.isUrl(location) || 
                ResourceUtils.toURI(location).isAbsolute();
        }
        catch (URISyntaxException ex) {
            // cannot convert to an URI, considering the location relative
            // unless it is the well-known Spring prefix "classpath*:"
        }

        // 绝对路径
        if (absoluteLocation) {
            try {
                // 直接根据地质加载相应的配置文件
                int importCount = getReaderContext().getReader()
                    	.loadBeanDefinitions(location, actualResources);
                if (logger.isDebugEnabled()) {
                logger.debug("Imported " +  importCount 
                     + " bean definitions from URL location [" + location + "]");
                }
            }
            catch (BeanDefinitionStoreException ex) {
                getReaderContext().error(
                        "Failed to import bean definitions from URL location ["
                    	+ location + "]", ele, ex);
            }
        }
        else {
            // 相对路径则根据相应的地质计算出绝对路径地址
            try {
                int importCount;
                Resource relativeResource = getReaderContext().getResource()
                    							.createRelative(location);
                if (relativeResource.exists()) {
                    importCount = getReaderContext().getReader()
                        				.loadBeanDefinitions(relativeResource);
                    actualResources.add(relativeResource);
                }
                else {
                    String baseLocation = getReaderContext().getResource()
                        					.getURL().toString();
                    importCount = getReaderContext().getReader()
                        	.loadBeanDefinitions(  
                            	StringUtil.applyRelativePath(baseLocation, location),
                        			actualResources);
                }
                if (logger.isDebugEnabled()) {
                    logger.debug("Imported " +  importCount + 
                                 " bean definitions from relative location [" 
                                 	+ location + "]");
                }
            }
            catch (IOException ex) {
                getReaderContext().error("Failed to resolve current resource location", 
                                         	ele, ex);
            }
            catch (BeanDefinitionStoreException ex) {
                getReaderContext().error("Failed to import bean definitions from 
                                         relative location [" + location + "]",
                                         			  ele, ex);
            }
        }
        // 解析成功后，进行监听器激活处理
        Resource[] actResArray = actualResources.toArray(new Resource[0]);
        getReaderContext().fireImportProcessed(location, actResArray, 
                                               extractSource(ele));
    }
```

解析 import 过程较为清晰，整个过程如下：

1. 获取 source 属性的值，该值表示资源的路径
2. 解析路径中的系统属性，如”${user.dir}”
3. 判断资源路径 location 是绝对路径还是相对路径
4. 如果是绝对路径，则调递归调用 Bean 的解析过程，进行另一次的解析
5. 如果是相对路径，则先计算出绝对路径得到 Resource，然后进行解析
6. 通知监听器，完成解析

**判断路径**

方法通过以下方法来判断 location 是为相对路径还是绝对路径：

```null
absoluteLocation = ResourcePatternUtils.isUrl(location) || ResourceUtils.toURI(location).isAbsolute();
```

判断绝对路径的规则如下：

- 以 classpath*: 或者 classpath: 开头为绝对路径
- 能够通过该 location 构建出 `java.net.URL`为绝对路径
- 根据 location 构造 `java.net.URI` 判断调用 `isAbsolute()` 判断是否为绝对路径

**绝对路径**

如果 location 为绝对路径则调用 `loadBeanDefinitions()`，该方法在 AbstractBeanDefinitionReader 中定义。

```java
    public int loadBeanDefinitions(String location, @Nullable Set<Resource> actualResources) throws BeanDefinitionStoreException {
        ResourceLoader resourceLoader = getResourceLoader();
        if (resourceLoader == null) {
            。。。。异常
        }

        if (resourceLoader instanceof ResourcePatternResolver) {
            // Resource pattern matching available.
            try {
                Resource[] resources = 
                    ((ResourcePatternResolver) resourceLoader).getResources(location);
                int loadCount = loadBeanDefinitions(resources);
                if (actualResources != null) {
                    for (Resource resource : resources) {
                        actualResources.add(resource);
                    }
                }
              
                return loadCount;
            }
            catch (IOException ex) {
               。。。省略异常
            }
        }
        else {
            // Can only load single resources by absolute URL.
            Resource resource = resourceLoader.getResource(location);
            int loadCount = loadBeanDefinitions(resource);
            if (actualResources != null) {
                actualResources.add(resource);
            }
            }
            return loadCount;
        }
    }
```

整个逻辑比较简单，首先获取 ResourceLoader，然后根据不同的 ResourceLoader 执行不同的逻辑，主要是可能存在多个 Resource，但是最终都会回归到 `XmlBeanDefinitionReader.loadBeanDefinitions()` ，所以这是一个递归的过程。

**相对路径**

如果是相对路径则会根据相应的 Resource 计算出相应的绝对路径，然后根据该路径构造一个 Resource，若该 Resource 存在，则调用 `XmlBeanDefinitionReader.loadBeanDefinitions()` 进行 BeanDefinition 加载，否则构造一个绝对 location ，调用 `AbstractBeanDefinitionReader.loadBeanDefinitions()` 方法，与绝对路径过程一样。

至此，import 标签解析完毕，整个过程比较清晰明了：**获取 source 属性值，得到正确的资源路径，然后调用loadBeanDefinitions() 方法进行递归的 BeanDefinition 加载**

### 嵌入式beans标签解析

对于嵌入式的beans标签，有点类似于import标签所提供的解析。无非是递归调用beans的解析过程。因此在这里就不具体分析。