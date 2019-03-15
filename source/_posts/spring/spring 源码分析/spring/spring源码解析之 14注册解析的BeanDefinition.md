abbrlink: 33
title: ' spring 源码解析之 14注册解析的BeanDefinition'
tags:
  - spring
  - spring源码解析
categories:
  - spring
author: fengxiutianya
date: 2019-01-14 05:39:00
---
# spring 源码解析之 14注册解析的BeanDefinition

`DefaultBeanDefinitionDocumentReader.processBeanDefinition()` 完成 Bean 标签解析的核心工作，如下：
<!-- more-->

```java
    protected void processBeanDefinition(Element ele, 
                                         BeanDefinitionParserDelegate delegate) {
        BeanDefinitionHolder bdHolder = delegate.parseBeanDefinitionElement(ele);
        if (bdHolder != null) {
            bdHolder = delegate.decorateBeanDefinitionIfRequired(ele, bdHolder);
            try {
                // Register the final decorated instance.
                BeanDefinitionReaderUtils.registerBeanDefinition(
                    bdHolder, getReaderContext().getRegistry());
            }
            catch (BeanDefinitionStoreException ex) {
                ....省略异常
            }
            // Send registration event.
            getReaderContext().fireComponentRegistered(
                new BeanComponentDefinition(bdHolder));
        }
    }
```

解析工作分为三步：

1. 解析默认标签；
2. 解析默认标签中的自定义属性标签；
3. 注册解析后的 BeanDefinition。

经过前面两个步骤的解析，这时的 BeanDefinition 已经可以满足后续的使用要求了，那么接下来的工作就是将这些 BeanDefinition 进行注册，也就是完成第三步。

注册 BeanDefinition 由 `BeanDefinitionReaderUtils.registerBeanDefinition()` 完成。如下：

```java
public static void registerBeanDefinition(
    BeanDefinitionHolder definitionHolder, BeanDefinitionRegistry registry)
    throws BeanDefinitionStoreException {

    // 注册 beanName
    String beanName = definitionHolder.getBeanName();
    registry.registerBeanDefinition(beanName, 
                                    definitionHolder.getBeanDefinition());

    // 注册 alias 
    String[] aliases = definitionHolder.getAliases();
    if (aliases != null) {
        for (String alias : aliases) {
            registry.registerAlias(beanName, alias);
        }
    }
}
```

首先通过 beanName 注册 BeanDefinition ，然后再注册别名 alias。BeanDefinition 的注册由接口 BeanDefinitionRegistry 定义。

### **通过 beanName 注册**

`BeanDefinitionRegistry.registerBeanDefinition()` 实现通过 beanName 注册 BeanDefinition，如下：

```java
public void registerBeanDefinition(String beanName, BeanDefinition beanDefinition)
    throws BeanDefinitionStoreException {

    // 校验 beanName 与 beanDefinition
    Assert.hasText(beanName, "Bean name must not be empty");
    Assert.notNull(beanDefinition, "BeanDefinition must not be null");

    if (beanDefinition instanceof AbstractBeanDefinition) {
        try {
            // 校验 BeanDefinition
            // 这是注册前的最后一次校验了，主要是对属性 methodOverrides 进行校验
            // 校验methodOverride是否与工厂方法并存或者methodOverrides对应的方法根本不存在
            ((AbstractBeanDefinition) beanDefinition).validate();
        }
        catch (BeanDefinitionValidationException ex) {
            throw new BeanDefinitionStoreException(
                beanDefinition.getResourceDescription(), beanName,
                "Validation of bean definition failed", ex);
        }
    }

    BeanDefinition oldBeanDefinition;

    // 从缓存中获取指定 beanName 的 BeanDefinition
    oldBeanDefinition = this.beanDefinitionMap.get(beanName);
    /**
         * 如果存在
         */
    if (oldBeanDefinition != null) {
        // 如果存在但是不允许覆盖，抛出异常
        if (!isAllowBeanDefinitionOverriding()) {
           。。。。省略抛出异常
        }
        //根据bean的角色来判断这个BeanDefinition是否是用户自定义的，然后覆盖了系统定义的bean
        // 在spring中bean的角色分为
        //  0代表 apllication 用户自定义
        //  1代表 support 	配置，起到支撑作用
        //  2代表 infrastructure 系统运行过程中背后起到支撑的作用
        else if (oldBeanDefinition.getRole() < beanDefinition.getRole()) {

           。。。。省略日志
        }
        // 覆盖 beanDefinition 与 被覆盖的 beanDefinition 不是同类
        else if (!beanDefinition.equals(oldBeanDefinition)) {
        	。。。。省略日志
        }
        else {
            if (this.logger.isDebugEnabled()) {
               。。。。 省略日志
            }
        }

        // 允许覆盖，直接覆盖原有的 BeanDefinition
        this.beanDefinitionMap.put(beanName, beanDefinition);
    }
    //  系统不存在相同的BeanDefinition
    else {
        // 检测创建Bean阶段是否已经开启，如果开启了则需要对beanDefinitionMap进行并发控制
        if (hasBeanCreationStarted()) {
            // beanDefinitionMap 为全局变量，避免并发情况
            synchronized (this.beanDefinitionMap) {
                //
                this.beanDefinitionMap.put(beanName, beanDefinition);
                List<String> updatedDefinitions = 
                    new ArrayList<>(this.beanDefinitionNames.size() + 1);
                updatedDefinitions.addAll(this.beanDefinitionNames);
                updatedDefinitions.add(beanName);
                this.beanDefinitionNames = updatedDefinitions;
                if (this.manualSingletonNames.contains(beanName)) {
                    Set<String> updatedSingletons = 
                        new LinkedHashSet<>(this.manualSingletonNames);
                    updatedSingletons.remove(beanName);
                    this.manualSingletonNames = updatedSingletons;
                }
            }
        }
        else {
            // 不会存在并发情况，直接设置
            this.beanDefinitionMap.put(beanName, beanDefinition);
            this.beanDefinitionNames.add(beanName);
            this.manualSingletonNames.remove(beanName);
        }
        this.frozenBeanDefinitionNames = null;
    }

    if (oldBeanDefinition != null || containsSingleton(beanName)) {
        // 重新设置 beanName 对应的缓存
        resetBeanDefinition(beanName);
    }
}
```

处理过程如下：

- 首先 BeanDefinition 进行校验，该校验也是注册过程中的最后一次校验了，主要是对 AbstractBeanDefinition 的 methodOverrides 属性进行校验。其中有一点我在这里在说明一下**methodOverrides不能和工厂方法并存，是因为实现methodOverrides需要使用动态代理来改变这个类，如果使用cglib，则需要修改字节码，如果使用了工厂方法，是直接返回bean，而动态代理是无法修改这个对象的**
- 根据 beanName 从缓存中获取 BeanDefinition，如果缓存中存在，则根据 allowBeanDefinitionOverriding 标志来判断是否允许覆盖，如果允许则直接覆盖，否则抛出 BeanDefinitionStoreException 异常
- 若缓存中没有指定 beanName 的 BeanDefinition，则判断当前阶段是否已经开始了 Bean 的创建阶段，如果是，则需要对 beanDefinitionMap 进行加锁控制并发问题，否则直接设置即可。对于 `hasBeanCreationStarted()` 方法后续做详细介绍，这里不过多阐述。
- 若缓存中存在该 beanName 或者单例bean 集合中存在该 beanName，则调用 `resetBeanDefinition()` 重置 BeanDefinition 缓存。

其实整段代码的核心就在于 `this.beanDefinitionMap.put(beanName, beanDefinition);` 。BeanDefinition 的缓存也不是神奇的东西，就是定义 map ，key 为 beanName，value 为 BeanDefinition。

**注册 alias**

`BeanDefinitionRegistry.registerAlias` 完成 alias 的注册。

```java
public void registerAlias(String name, String alias) {
    // 校验 name 、 alias
    Assert.hasText(name, "'name' must not be empty");
    Assert.hasText(alias, "'alias' must not be empty");
    synchronized (this.aliasMap) {
        // name == alias 则去掉alias
        if (alias.equals(name)) {
            this.aliasMap.remove(alias);
        }
        else {
            // 缓存缓存记录
            String registeredName = this.aliasMap.get(alias);
            if (registeredName != null) {
                // 缓存中的相等，则直接返回
                if (registeredName.equals(name)) {
                    // An existing alias - no need to re-register
                    return;
                }
                // 不允许则抛出异常
                if (!allowAliasOverriding()) {
                   。。。省略异常
                }
            }
            // 当 A --> B 存在时，如果再次出现 A --> C --> B 则抛出异常
            checkForAliasCircle(name, alias);
            // 注册 alias
            this.aliasMap.put(alias, name);
        }
    }
}
```

注册 alias 和注册 BeanDefinition 的过程差不多。在最后调用了 `checkForAliasCircle()` 来对别名进行了检测。

```java
public boolean hasAlias(String name, String alias) {
    for (Map.Entry<String, String> entry : this.aliasMap.entrySet()) {
        String registeredName = entry.getValue();
        if (registeredName.equals(name)) {
            String registeredAlias = entry.getKey();
            return (registeredAlias.equals(alias) 
                    || hasAlias(registeredAlias, alias));
        }
    }
    return false;
}
```

如果 (name,alias) 为 （1 、3），加入集合中存在（3,A），（A,1）的情况则会出错。

到此为止BeanDefinition已经注册完成，下一步就是初始化bean。