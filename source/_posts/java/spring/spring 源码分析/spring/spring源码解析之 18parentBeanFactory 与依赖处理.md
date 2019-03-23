---
title: spring源码解析之 18parentBeanFactory 与依赖处理
tags:
  - spring源码解析
categories:
  - spring
  - 源码分析
author: fengxiutianya
abbrlink: 86d74f07
date: 2019-01-15 03:32:00
---
从上篇文章中我们可以得知，如果从单例缓存中没有获取到单例 bean，则会说明是下面俩种情况发生：

1. 该bean的scope是singleton ,但是没有初始化完成
2. 该bean的scope不是singleton

本篇文章就来进行这部分的分析，这里先讲循环依赖检测、parentBeanFactory与依赖处理，剩下的scope处理，主要在下一篇文章中讲解，本文所分析的具体源码如下：
<!-- more -->

```java
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
BeanFactory parentBeanFactory = getParentBeanFactory();

// containsBeanDefinition 用于检测当前BeanFactory
// 是否包含beanName的BeanDefinition
if (parentBeanFactory != null && !containsBeanDefinition(beanName)) {
    // 递归到BeanFactory中寻找,这点和下面的创建过程大体类型，只不过委托给父类来查找
    String nameToLookup = originalBeanName(name);
    if (parentBeanFactory instanceof AbstractBeanFactory) {
        return ((AbstractBeanFactory) parentBeanFactory).doGetBean(
            nameToLookup, requiredType, args, typeCheckOnly);
    } else if (args != null) {
        // 带有args的处理
        return (T) parentBeanFactory.getBean(nameToLookup, args);
    } else if (requiredType != null) {
        // 带有特定类型的处理
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
    checkMergedBeanDefinition(mbd, beanName, args);

    // 若存在依赖则需要递归实例化依赖的bean
    // 这里的getDependsOn返回的是对应bean属性depend-on设置的值
    String[] dependsOn = mbd.getDependsOn();
    if (dependsOn != null) {
        for (String dep : dependsOn) {
            if (isDependent(beanName, dep)) {
               。。。。省略异常
            }
            // 缓存依赖调用
            registerDependentBean(dep, beanName);
            try {
                getBean(dep);
            } catch (NoSuchBeanDefinitionException ex) {
                省略异常
            }
        }
    }
```

这段代码主要处理流程如下：

1. 检测当前beanName对应的bean是否是Prototype循环依赖，如果是，则抛出 BeanCurrentlyInCreationException 异常。
2. 如果beanDefinitionMap中不存在beanName对应的BeanDefinition，前面说过BeanFactory是有继承体系的，可以从父BeanFactory中获取，也即是上面尝试从 parentBeanFactory 中加载。
3. 判断是否为类型检查，如果不是，需要标记处理。
4. 从mergedBeanDefinitions中获取beanName对应的RootBeanDefinition，如果这个BeanDefinition是子 Bean的话，则会合并父类的相关属性。
5. 依赖处理，这里的依赖是指depend-on属性指定的依赖，和后面说道的内部依赖不一样。

### **检测当前bean是否是Prototype类型的循环依赖**

在前面就提过，Spring 只解决单例模式下的循环依赖，对于原型模式的循环依赖则是抛出 BeanCurrentlyInCreationException 异常，所以首先检查该 beanName 是否处于原型模式下的循环依赖。如下：

```java
if (isPrototypeCurrentlyInCreation(beanName)) {
    throw new BeanCurrentlyInCreationException(beanName);
}
```

调用 `isPrototypeCurrentlyInCreation()` 判断当前 bean 是否正在创建，如下：

```java
protected boolean isPrototypeCurrentlyInCreation(String beanName) {
    Object curVal = this.prototypesCurrentlyInCreation.get();
    return (curVal != null &&
            (curVal.equals(beanName) || 
             (curVal instanceof Set && ((Set<?>) curVal).contains(beanName))));
}
```

其实检测逻辑和单例模式一样，一个集合存放着正在创建的bean，从该集合中进行判断即可，只不过单例模式的集合为Set全局共享 ，而原型模式的则是ThreadLocal，线程私有，这也比较好理解，因为原型毕竟在需要的时候在创建，而且每个线程处理不同的逻辑，所以需要不同的对象，因此用ThreadLocal拉保存当前线程对应的正在创建的bean实例。prototypesCurrentlyInCreation 定义如下：

```java
private final ThreadLocal<Object> prototypesCurrentlyInCreation = 
    	new NamedThreadLocal<>("Prototype beans currently in creation");
```

这里只是判断，你可能会疑惑这是什么时候加入进去的。后面再讲创建不同作用域的bean实例时会说到。

### **检查父类 BeanFactory**

若 `containsBeanDefinition` 中不存在 beanName 相对应的 BeanDefinition，则从 parentBeanFactory 中获取，这个是因为BeanFactory是可以有集成体系。源码如下：

```java
// 获取 parentBeanFactory
BeanFactory parentBeanFactory = getParentBeanFactory();
// parentBeanFactory 不为空且 beanDefinitionMap 中不存该 name 的 BeanDefinition
if (parentBeanFactory != null && !containsBeanDefinition(beanName)) {
    // 确定原始 beanName
    String nameToLookup = originalBeanName(name);
    // 若为 AbstractBeanFactory 类型，委托父类处理
    if (parentBeanFactory instanceof AbstractBeanFactory) {
        return ((AbstractBeanFactory) parentBeanFactory).doGetBean(
            nameToLookup, requiredType, args, typeCheckOnly);
    }
    else if (args != null) {
        // 委托给构造函数 getBean() 处理
        return (T) parentBeanFactory.getBean(nameToLookup, args);
    }
    else {
        // 没有 args，委托给标准的 getBean() 处理
        return parentBeanFactory.getBean(nameToLookup, requiredType);
    }
}
```

整个过程较为简单，都是委托 parentBeanFactory 的 `getBean()` 进行处理，只不过在获取之前对 name 进行简单的处理，主要是想获取原始的beanName，也就是传进来的name如下：

```java
protected String originalBeanName(String name) {
    String beanName = transformedBeanName(name);
    if (name.startsWith(FACTORY_BEAN_PREFIX)) {
        beanName = FACTORY_BEAN_PREFIX + beanName;
    }
    return beanName;
}
```

`transformedBeanName()` 是对 name 进行转换，获取真正的 beanName，因为我们传递的可能是 aliasName（这个过程在上一篇博客中分析 `transformedBeanName()` 有详细说明），如果 name 是以 “&” 开头的，则加上 “&”，因为在 `transformedBeanName()` 将 “&” 去掉了，这里加上。

### **类型检查**

参数 typeCheckOnly 是用来判断调用 `getBean()` 是否为类型检查获取 bean。如果不是仅做类型检查则是创建bean，则需要调用 `markBeanAsCreated()` 记录：

```java
protected void markBeanAsCreated(String beanName) {
    // 没有创建
    if (!this.alreadyCreated.contains(beanName)) {
        // 加上全局锁
        synchronized (this.mergedBeanDefinitions) {
            // 再次检查一次：DCL 双检查模式
            if (!this.alreadyCreated.contains(beanName)) {
                // 从 mergedBeanDefinitions中删除beanName，
                // 并在下次访问时重新创建它。
                clearMergedBeanDefinition(beanName);
                // 添加到已创建bean集合中
                this.alreadyCreated.add(beanName);
            }
        }
    }
}
```

### **获取 RootBeanDefinition**

```java
final RootBeanDefinition mbd = getMergedLocalBeanDefinition(beanName);
```

调用 `getMergedLocalBeanDefinition()` 获取相对应的 BeanDefinition，如下：

```java
protected RootBeanDefinition getMergedLocalBeanDefinition(String beanName) 
    throws BeansException {
    // 快速从缓存中获取，如果不为空，则直接返回
    RootBeanDefinition mbd = this.mergedBeanDefinitions.get(beanName);
    if (mbd != null) {
        return mbd;
    }
    // 获取 RootBeanDefinition，
    // 如果返回的 BeanDefinition 是子类 bean 的话，则合并父类相关属性
    return getMergedBeanDefinition(beanName, getBeanDefinition(beanName));
}
```

首先直接从mergedBeanDefinitions缓存中获取相应的RootBeanDefinition，如果存在则直接返回，不存在则调用 `getMergedBeanDefinition()` 获取RootBeanDefinition，若获取的 BeanDefinition 为子 BeanDefinition，则需要合并父类的相关属性。具体的合并过程这里就不细说，如果你感兴趣的话可以仔细研究。

### **处理depend-on依赖**

如果一个bean有依赖bean的话，那么在初始化该bean时是需要先初始化它所依赖的 bean。

```java
// 获取依赖。
// 在初始化 bean 时解析 depends-on 标签时设置
String[] dependsOn = mbd.getDependsOn();
if (dependsOn != null) {
    // 迭代依赖
    for (String dep : dependsOn) {
        // 检验依赖的bean 是否已经注册给当前bean获取其他传递依赖bean
        if (isDependent(beanName, dep)) {
           。。。。异常
        }
        // 注册到依赖bean中
        registerDependentBean(dep, beanName);
        try {
            // 调用 getBean 初始化依赖bean
            getBean(dep);
        }
        catch (NoSuchBeanDefinitionException ex) {
          。。。。省略异常
        }
    }
}
```

这段代码逻辑是：通过迭代的方式依次对依赖 bean 进行检测、校验，如果检测通过，则调用 `getBean()` 实例化依赖 bean。

`isDependent()` 是校验是否存在循环依赖，也就是A->B，B->C，C->A这种情况。

```java
protected boolean isDependent(String beanName, String dependentBeanName) {
    synchronized (this.dependentBeanMap) {
        return isDependent(beanName, dependentBeanName, null);
    }
}
```

同步加锁给 dependentBeanMap 对象，然后调用 `isDependent()` 校验。dependentBeanMap 对象保存的是依赖之间的映射关系：beanName – > 依赖beanName的集合

```java
private boolean isDependent(String beanName, String dependentBeanName,
                            @Nullable Set<String> alreadySeen) {
    if (alreadySeen != null && alreadySeen.contains(beanName)) {
        return false;
    }
    String canonicalName = canonicalName(beanName);
    Set<String> dependentBeans = this.dependentBeanMap.get(canonicalName);
    if (dependentBeans == null) {
        return false;
    }
    if (dependentBeans.contains(dependentBeanName)) {
        return true;
    }
    for (String transitiveDependency : dependentBeans) {
        if (alreadySeen == null) {
            alreadySeen = new HashSet<>();
        }
        alreadySeen.add(beanName);
        if (isDependent(transitiveDependency, dependentBeanName, alreadySeen)) {
            return true;
        }
    }
    return false;
}
```

如果不存在循环依赖，则调用 `registerDependentBean()` 将该依赖进行记录，便于在销毁依赖bean之前对其进行销毁。

```java
public void registerDependentBean(String beanName, String dependentBeanName) {
    String canonicalName = canonicalName(beanName);

    synchronized (this.dependentBeanMap) {
        Set<String> dependentBeans =
            this.dependentBeanMap.computeIfAbsent(canonicalName, 
                                                  k -> new LinkedHashSet<>(8));
        if (!dependentBeans.add(dependentBeanName)) {
            return;
        }
    }

    synchronized (this.dependenciesForBeanMap) {
        Set<String> dependenciesForBean =
            this.dependenciesForBeanMap.computeIfAbsent(dependentBeanName,
                                                        k -> new LinkedHashSet<>(8));
        dependenciesForBean.add(canonicalName);
    }
}
```

其实将就是该映射关系保存到两个集合中：dependentBeanMap、dependenciesForBeanMap。

最后调用 `getBean()` 实例化依赖 bean。

至此，加载 bean 的第二个部分也分析完毕了，下篇开始分析第三个部分：不同作用域bean的创建。