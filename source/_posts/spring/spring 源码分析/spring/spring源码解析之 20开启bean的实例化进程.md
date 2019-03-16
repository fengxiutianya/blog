---
title: spring源码解析之 20 开启bean的实例化进程
tags:
  - spring源码解析
  - spring
categories:
  - spring
  - 源码分析
author: fengxiutianya
abbrlink: 5a89bec2
date: 2019-01-15 03:34:00
---
# spring源码解析之 20 开启bean的实例化进程

在上篇博客中有一个核心方法没有讲到 `createBean()` ，该方法的如下：

```java
protected abstract Object createBean(String beanName, RootBeanDefinition mbd, 
              @Nullable Object[] args) throws BeanCreationException;
```

该方法定义在 AbstractBeanFactory 中。其含义是根据给定的 BeanDefinition 和 args实例化一个 bean 对象，如果该 BeanDefinition 存在父类，则该 BeanDefinition 已经合并了父类的属性。所有 Bean 实例的创建都会委托给该方法实现。
<!-- more -->

方法接受三个参数：

- beanName：bean 的名字
- mbd：已经合并了父类属性的（如果有的话）BeanDefinition
- args：用于构造函数或者工厂方法创建 bean 实例对象的参数

该抽象方法的默认实现是在类 AbstractAutowireCapableBeanFactory 中实现，如下：

```java
   protected Object createBean(String beanName, RootBeanDefinition mbd, 
                               @Nullable Object[] args)
            throws BeanCreationException {

        if (logger.isDebugEnabled()) {
            logger.debug("Creating instance of bean '" + beanName + "'");
        }
        RootBeanDefinition mbdToUse = mbd;

        // 确保此时的 bean 已经被解析了
        // 如果获取的class 属性不为null，则克隆该 BeanDefinition
        // 主要是因为该动态解析的 class 无法保存到到共享的 BeanDefinition
        Class<?> resolvedClass = resolveBeanClass(mbd, beanName);
        if (resolvedClass != null && !mbd.hasBeanClass() 
            && mbd.getBeanClassName() != null) {
            mbdToUse = new RootBeanDefinition(mbd);
            mbdToUse.setBeanClass(resolvedClass);
        }

        try {
            // 对override属性进行标记以及验证
			// 这里用来判断一个类中如果存在若干个重载方法，那么在函数调用以及增强的时候
			// 还需要根据参数类型进行匹配，来最终确认当前调用的到底是哪个函数。
			// 但是如果只有一个，那么就设置该方法没有重载，这个后续调用的时候可以直接使用
			// 找到该方法，而不需要进行方法参数匹配。
            mbdToUse.prepareMethodOverrides();
        }
        catch (BeanDefinitionValidationException ex) {
            throw new BeanDefinitionStoreException(mbdToUse.getResourceDescription(),
                    beanName, "Validation of method overrides failed", ex);
        }

        try {
            // 这个方法的作用是实例化对象之前进行前置处理
            // AOP 的功能就是基于这个地方
            Object bean = resolveBeforeInstantiation(beanName, mbdToUse);
            // 如果代理对象不为空，则直接返回代理对象，这一步骤有非常重要的作用，
			// Spring 后续实现 AOP 就是基于这个地方判断的。
            if (bean != null) {
                return bean;
            }
        }
        catch (Throwable ex) {
            throw new BeanCreationException(mbdToUse.getResourceDescription(), 
                                            beanName,
                    "BeanPostProcessor before instantiation of bean failed", ex);
        }

        try {
            // 执行真正创建 bean 的过程
            Object beanInstance = doCreateBean(beanName, mbdToUse, args);
            if (logger.isDebugEnabled()) {
                logger.debug("Finished creating instance of bean '" + beanName + "'");
            }
            return beanInstance;
        }
        catch (BeanCreationException | ImplicitlyAppearedSingletonException ex) {
            throw ex;
        }
        catch (Throwable ex) {
            throw new BeanCreationException(
                    mbdToUse.getResourceDescription(), beanName, 
                "Unexpected exception during bean creation", ex);
        }
    }
```

过程如下：

- 根据设置的class属性或者根据className来解析class
- 处理 override 属性进行标记及验证
- 应用初始化前的处理，解析指定的bean是否存在初始化钱的短路操作，类如后面要说的aop，就会在这里直接初始化一个bean，这后面的操作就不需要进行
- 创建 bean

**解析指定 BeanDefinition 的 class**

```java
Class<?> resolvedClass = resolveBeanClass(mbd, beanName)
```

这个方法主要是解析 bean definition 的 class 类，并将已经解析的 Class 存储在 beandefinition 中以供后面使用。如果解析的 class 不为空，则会将该 BeanDefinition 进行克隆至 mbdToUse，这样做的主要目的是为动态解析的 class 是无法保存到共享的 BeanDefinition 中。

**处理 override 属性**

大家还记得 lookup-method 和 replace-method 这两个配置功能？在前面博客中已经详细分析了这两个标签的用法和解析过程，知道解析过程其实就是讲这两个配置存放在 BeanDefinition 中的 methodOverrides 属性中，我们知道在 bean 实例化的过程中如果检测到存在 methodOverrides，则会动态地位为当前 bean 生成代理并使用对应的拦截器为 bean 做增强处理。具体的实现我们后续分析，现在先看 `mbdToUse.prepareMethodOverrides()` 都干了些什么事，如下：

```java
    public void prepareMethodOverrides() throws BeanDefinitionValidationException {
        if (hasMethodOverrides()) {
            Set<MethodOverride> overrides = getMethodOverrides().getOverrides();
            synchronized (overrides) {
                for (MethodOverride mo : overrides) {
                    prepareMethodOverride(mo);
                }
            }
        }
    }
```

如果存在 methodOverrides 则获取所有的 override method ，然后通过迭代的方法一次调用 `prepareMethodOverride()`，如下：

```java
    protected void prepareMethodOverride(MethodOverride mo) 
        throws BeanDefinitionValidationException {
        int count = ClassUtils.getMethodCountForName(getBeanClass(), 
                                                     mo.getMethodName());
        //说明没有对应的代理方法
        if (count == 0) {
            throw new BeanDefinitionValidationException(
                    "Invalid method override: no method with name '"
                    + mo.getMethodName() +
                    "' on class [" + getBeanClassName() + "]");
        }
        else if (count == 1) {
            mo.setOverloaded(false);
        }
    }
```

根据方法名称从 class 中获取该方法名的个数，如果为 0 则抛出异常，如果 为 1 则设置该重载方法没有被重载。若一个类中存在多个重载方法，则在方法调用的时候还需要根据参数类型来判断到底重载的是哪个方法。在设置重载的时候其实这里做了一个小小优化，那就是当 `count == 1` 时，设置 `overloaded = false`，这样表示该方法没有重载，这样在后续调用的时候便可以直接找到方法而不需要进行方法参数的校验。

诚然，其实 `mbdToUse.prepareMethodOverrides()` 并没有做什么实质性的工作，只是对 methodOverrides 属性做了一些简单的校验而已。

**实例化的前置处理**

`resolveBeforeInstantiation()` 的作用是给 BeanPostProcessors 后置处理器返回一个代理对象的机会，其实在调用该方法之前 Spring 一直都没有创建 bean ，那么这里返回一个 bean 的代理类有什么作用呢？作用体现在后面的 `if` 判断：

```java
if (bean != null) {
    return bean;
}
```

如果代理对象不为空，则直接返回代理对象，这一步骤有非常重要的作用，Spring 后续实现 AOP 就是基于这个地方判断的。

```java
    protected Object resolveBeforeInstantiation(String beanName,
                                                RootBeanDefinition mbd) {
        Object bean = null;
        if (!Boolean.FALSE.equals(mbd.beforeInstantiationResolved)) {
            if (!mbd.isSynthetic() && hasInstantiationAwareBeanPostProcessors()) {
                Class<?> targetType = determineTargetType(beanName, mbd);
                if (targetType != null) {
                    bean = applyBeanPostProcessorsBeforeInstantiation
                        (targetType, beanName);
                    if (bean != null) {
                        bean = applyBeanPostProcessorsAfterInitialization
                            (bean, beanName);
                    }
                }
            }
            mbd.beforeInstantiationResolved = (bean != null);
        }
        return bean;
    }
```

这个方法核心就在于 `applyBeanPostProcessorsBeforeInstantiation()` 和 `applyBeanPostProcessorsAfterInitialization()` 两个方法，before 为实例化前的后处理器应用，after 为实例化后的后处理器应用，由于本文的主题是创建 bean，关于 Bean 的增强处理后续会单独出博文来做详细说明。

**创建 bean**

如果没有代理对象，就只能走常规的路线进行 bean 的创建了，该过程有 `doCreateBean()` 实现，如下：

```java
   protected Object doCreateBean(final String beanName, final RootBeanDefinition mbd, 
                                 final @Nullable Object[] args)
            throws BeanCreationException {

        // BeanWrapper是对Bean的包装，其接口中所定义的功能很简单包括设置获取被包装的对象，
       // 获取被包装bean的属性描述器
        BeanWrapper instanceWrapper = null;
       
        // 单例模型，则从未完成的 FactoryBean 缓存中删除
        if (mbd.isSingleton()) {
            anceWrapper = this.factoryBeanInstanceCache.remove(beanName);
        }

           // 根据指定bean使用的对应策略创建新的实例，如：工厂方法、构造函数自动注入，简单完成初始化
			// 实例化bean，将BeanDefinition转换为BeanWrapper
			// 转换是一个复杂的过程，主要有以下步骤：
			// 如果存在工厂方法则使用工厂方法进行初始化。
			// 一个类有多个构造函数，每个构造函数都有不同的参数，所以需要根据参数
       		//锁定构造函数并进行初始化
			// 如果即不存在工厂方法也不存在带有参数的构造函数，
           // 则使用默认的构造函数进行bean的实例化。
        if (instanceWrapper == null) {
            instanceWrapper = createBeanInstance(beanName, mbd, args);
        }

        // 包装的实例对象
        final Object bean = instanceWrapper.getWrappedInstance();
        // 包装的实例对象的类型
        Class<?> beanType = instanceWrapper.getWrappedClass();
        if (beanType != NullBean.class) {
            mbd.resolvedTargetType = beanType;
        }

        // 检测是否有后置处理
        // 如果有后置处理，则允许后置处理修改 BeanDefinition
        synchronized (mbd.postProcessingLock) {
            if (!mbd.postProcessed) {
                try {
                    // applyMergedBeanDefinitionPostProcessors
                    // 后置处理修改 BeanDefinition
                    applyMergedBeanDefinitionPostProcessors(mbd, beanType, beanName);
                }
                catch (Throwable ex) {
                    throw new BeanCreationException(mbd.getResourceDescription(), 
                                                    beanName,
                            "Post-processing of merged bean definition failed", ex);
                }
                mbd.postProcessed = true;
            }
        }

        // 解决单例模式的循环依赖
        // 单例模式 & 运行循环依赖&当前单例 bean 是否正在被创建
        boolean earlySingletonExposure = (mbd.isSingleton()
                                          && this.allowCircularReferences &&
                isSingletonCurrentlyInCreation(beanName));
        if (earlySingletonExposure) {
            if (logger.isDebugEnabled()) {
                logger.debug("Eagerly caching bean '" + beanName +
                        "' to allow for resolving potential circular references");
            }
           // 为避免后期循环依赖，可以在bean初始化完成前将创建实例的ObjectFactory键入工厂
			// getEarlyBeanReference的作用
			// 对bean再一次依赖引用，主要应用SmartInstantiationAwareBeanPostProcessor
		// 其中我们熟知的AOP就是在这里将advice动态植入bean中，若没有则直接返回bean不做任何处理
            addSingletonFactory(beanName, 
                                () -> getEarlyBeanReference(beanName, mbd, bean));
        }

        /*
         * 开始初始化 bean 实例对象
         */
        Object exposedObject = bean;
        try {
            // 对 bean 进行填充，将各个属性值注入，其中，可能存在依赖于其他 bean 的属性
            // 则会递归初始依赖 bean
            populateBean(beanName, mbd, instanceWrapper);
            // 调用初始化方法
            exposedObject = initializeBean(beanName, exposedObject, mbd);
        }
        catch (Throwable ex) {
            if (ex instanceof BeanCreationException && 
                beanName.equals(((BeanCreationException) ex).getBeanName())) {
                throw (BeanCreationException) ex;
            }
            else {
                throw new BeanCreationException(
                        mbd.getResourceDescription(), beanName,
                    "Initialization of bean failed", ex);
            }
        }

        /**
         * 循环依赖处理
         */
        if (earlySingletonExposure) {
            // 获取 earlySingletonReference
            Object earlySingletonReference = getSingleton(beanName, false);
            // 只有在存在循环依赖的情况下，earlySingletonReference 才不会为空
            if (earlySingletonReference != null) {
                // 如果 exposedObject 没有在初始化方法中被改变，也就是没有被增强
                if (exposedObject == bean) {
                    exposedObject = earlySingletonReference;
                }
                // 处理依赖
                else if (!this.allowRawInjectionDespiteWrapping && 
                         hasDependentBean(beanName)) {
                    String[] dependentBeans = getDependentBeans(beanName);
                    Set<String> actualDependentBeans =
                        new LinkedHashSet<>(dependentBeans.length);
                    for (String dependentBean : dependentBeans) {
                        if (!removeSingletonIfCreatedForTypeCheckOnly(dependentBean))
                        {
                            actualDependentBeans.add(dependentBean);
                        }
                    }
                    if (!actualDependentBeans.isEmpty()) {
                     	// 省略异常处理
                    }
                }
            }
        }
        try {
            // 注册 bean
            registerDisposableBeanIfNecessary(beanName, bean, mbd);
        }
        catch (BeanDefinitionValidationException ex) {
    		// 省略异常
        }

        return exposedObject;
    }
```

整体的思路：

1. 如果是单例模式，则清除 factoryBeanInstanceCache 缓存，同时返回 BeanWrapper 实例对象，当然如果存在。
2. 如果缓存中没有 BeanWrapper 或者不是单例模式，则调用 `createBeanInstance()` 实例化 bean，主要是将 BeanDefinition 转换为 BeanWrapper
   1. 如果存在工厂方法，则使用工厂方法进行初始化
   2. 一个类有多个构造函数，每个构造函数都有不同的参数，所以需要根据参数锁定构造函数并进行初始化
   3. 如果既不存在工厂函数也不存在带有参数的构造器函数则使用默认的构造函数进行bean的实例化
3.  MergedBeanDefinitionPostProcessor 的应用，Autowired注解正式通过此方法实现注入类型解析
4. 单例模式的循环依赖处理（后面会重点说到）
5. 调用 `populateBean()` 进行属性填充。将所有属性填充至 bean 的实例中
6.  调用 `initializeBean()` 初始化 bean
7.  依赖检查，在SPring中只解决单例的循环依赖，这一步判断是否有循环依赖，如果抛出异常
8. 注册 DisposableBean，如果配置了destroy-method。这里需要注册以便于在销毁的时候进行调用。

`doCreateBean()` 完成 bean 的创建和初始化工作，内容太多，这里就只列出整体思路，下文开始将该方法进行拆分进行详细讲解，分布从以下几个方面进行阐述：

- `createBeanInstance()` 实例化 bean
- `populateBean()` 属性填充
- 循环依赖的处理
- `initializeBean()` 初始化 bean