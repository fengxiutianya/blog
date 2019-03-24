---
title: spring源码解析之 20 开启bean的实例化进程
tags:
  - spring源码解析
  - spring
categories:
  - java
  - spring
  - spring 源码分析
  - SpringCore
author: fengxiutianya
abbrlink: 5a89bec2
date: 2019-01-15 03:34:00
---
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
- args：用于构造函数或者工厂方法创建bean实例对象的参数

该抽象方法的默认实现是在类 AbstractAutowireCapableBeanFactory 中实现，如下：

```java
protected Object createBean(String beanName, RootBeanDefinition mbd, 
                @Nullable Object[] args)throws BeanCreationException {
		RootBeanDefinition mbdToUse = mbd;

		// 这个方法主要是解析BeanDefinition中对应的class已经被正确加载，
		// 并将已经加载的Class存储在BeanDefinition中以供后面使用。
		// 如果Class对象不为空，则会将该BeanDefinition进行克隆至mbdToUse，
		// 这样做的主要目的是以为动态解析的Class对象是无法保存到共享的BeanDefinition中。
		// 这个我也不是很理解
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
		} catch (BeanDefinitionValidationException ex) {
		   。。。。省略异常
		}
    
		try {
			// 这个方法主要是处理InstantiationAwareBeanPostProcessor这个扩展
			// 而这个扩展是BeanPostProcessor的一个子接口，
			// 主要的目的是返回一个代理用于代替原来的Bean实例
			Object bean = resolveBeforeInstantiation(beanName, mbdToUse);

			// 如果代理对象不为空，则直接返回代理对象，这一步骤有非常重要的作用，
			// Spring后续实现AOP就是基于这个地方判断的。
			if (bean != null) {
				return bean;
			}
		} catch (Throwable ex) {
			。。。。省略异常
		}
		try {
			// 创建bean实例
			Object beanInstance = doCreateBean(beanName, mbdToUse, args);
			return beanInstance;
		} catch (BeanCreationException | ImplicitlyAppearedSingletonException ex) {
            省略异常
		}
	}
```

过程如下：

- 根据设置的class属性或者根据className来解析class
- 处理 override 属性进行标记及验证
- Bean初始化扩展点的处理，类如后面要说的aop，就会在这里直接初始化一个bean，这后面的操作就不需要进行
- 创建 bean

### **解析指定 BeanDefinition 的 class**

```java
Class<?> resolvedClass = resolveBeanClass(mbd, beanName)
```

这个方法主要是解析BeanDefinition的class 类，并将已经解析的Class存储在beandefinition中以供后面使用。如果解析的Class对象不为空，则会将该 BeanDefinition 进行克隆至mbdToUse，这样做的主要目的是为动态解析的 Class是无法保存到共享的BeanDefinition 中，这一步我是没看懂。

### **处理 override 属性**

大家还记得 lookup-method 和 replace-method 这两个配置功能，在前面博客中已经详细分析了这两个标签的用法和解析过程，知道解析过程其实就是讲这两个配置存放在 BeanDefinition 中的 methodOverrides 属性中，我们知道在 bean 实例化的过程中如果检测到存在methodOverrides，则会动态地位为当前bean生成代理并使用对应的拦截器为bean做增强处理。具体的实现我们后续分析，现在先看 `mbdToUse.prepareMethodOverrides()` 都干了些什么事，如下：

```java
public void prepareMethodOverrides() throws BeanDefinitionValidationException {
    if (hasMethodOverrides()) {
        // 获取所有的MethodOverride对象
        Set<MethodOverride> overrides = getMethodOverrides().getOverrides();
        synchronized (overrides) {
            for (MethodOverride mo : overrides) {
                prepareMethodOverride(mo);
            }
        }
    }
}
```

如果存在methodOverrides则获取所有的MethodOverride ，然后通过迭代的方法调用 `prepareMethodOverride()`来进行预处理，如下：

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

根据方法名称从Class对象中获取该方法个数，如果为 0 则抛出异常，如果为1则设置该重载方法没有被重载。若一个类中存在多个重载方法，则在方法调用的时候还需要根据参数类型来判断到底重载的是哪个方法。在设置重载的时候其实这里做了一个小小优化，那就是当`count == 1` 时，设置 `overloaded = false`，这样表示该方法没有重载，这样在后续调用的时候便可以直接找到方法而不需要进行方法参数的校验。其实 `mbdToUse.prepareMethodOverrides()` 并没有做什么实质性的工作，只是对 methodOverrides 属性做了一些简单的校验而已。

### **实例化的前置处理**

`resolveBeforeInstantiation()` 的作用是给InstantiationAwareBeanPostProcessor后置处理器返回一个代理对象的机会，这个后置处理器是BeanPostProcessor的一个子类，只是这里做了特殊的处理。其实在调用该方法之前Spring 一直都没有创建 bean ，那么这里返回一个 bean 的代理类有什么作用呢？作用体现在后面的 `if` 判断：

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

这个方法核心就在于 `applyBeanPostProcessorsBeforeInstantiation()` 和 `applyBeanPostProcessorsAfterInitialization()` 两个方法，before 为实例化前的后处理器应用，after 为实例化后的后处理器应用，由于本文的主题是创建 bean，关于Bean的增强处理后续会单独出博文来做详细说明。

### **创建 bean**

如果没有代理对象，就只能走常规的路线进行 bean 的创建了，该过程有 `doCreateBean()` 实现，如下：

```java
protected Object doCreateBean(final String beanName, final RootBeanDefinition mbd, 
           final @Nullable Object[] args)throws BeanCreationException {
    BeanWrapper instanceWrapper = null;
    // 如果是单例，查看缓存记录中是否存在BeanName对应的BeanWrapper
    if (mbd.isSingleton()) {
        instanceWrapper = this.factoryBeanInstanceCache.remove(beanName);
    }

    if (instanceWrapper == null) {
        // 根据指定bean使用的对应策略创建新的实例，
        // 如：工厂方法、构造函数自动注入，简单完成初始化实例化bean，
        // 将BeanDefinition转换为BeanWrapper
        // 转换是一个复杂的过程，主要有以下步骤：
        // 如果存在工厂方法则使用工厂方法进行初始化。
        // 一个类有多个构造函数，每个构造函数都有不同的参数，所以需要根据参数锁定构造函数并进行初始化
        // 如果即不存在工厂方法也不存在带有参数的构造函数，则使用默认的构造函数进行bean的实例化。
        instanceWrapper = createBeanInstance(beanName, mbd, args);
    }
    final Object bean = instanceWrapper.getWrappedInstance();
    Class<?> beanType = instanceWrapper.getWrappedClass();

    if (beanType != NullBean.class) {
        mbd.resolvedTargetType = beanType;
    }

    // 应用MergedBeanDefinitionPostProcessors，修改合并的BeanDefinition
    // 这个也是BeanPostProcessor的子类
    synchronized (mbd.postProcessingLock) {
        if (!mbd.postProcessed) {
            try {
                // bean合并后的处理，Autowired注解正式通过此方法实现注入类型的预解析
                applyMergedBeanDefinitionPostProcessors(mbd, beanType, beanName);
            } catch (Throwable ex) {
               。。。省略异常
            }
            mbd.postProcessed = true;
        }
    }
    // 是否可以提前曝光：单例 && 允许循环依赖 && 当前bean正在创建中，则允许
    // 主要是用来解决单例的循环依赖问题。
    boolean earlySingletonExposure = (mbd.isSingleton() 
                                      && this.allowCircularReferences &&
                                      isSingletonCurrentlyInCreation(beanName));
    if (earlySingletonExposure) {
          
        // 为解决单例类型的循环依赖，可以在bean初始化完成前，
        // 创建当前Bean实例的ObjectFactory工厂
        // 放入到singletonFactories中，
        addSingletonFactory(beanName, 
                            () -> getEarlyBeanReference(beanName, mbd, bean));
    }

    // 对实例化的bean进行处理
    Object exposedObject = bean;
    try {
    // 对bean进行填充，将各个属性值注入，其中，可能存在依赖于其他bean的属性，则会递归创建依赖bean
        populateBean(beanName, mbd, instanceWrapper);
        // 调用初始化方法init-method
        exposedObject = initializeBean(beanName, exposedObject, mbd);
    } catch (Throwable ex) {
          。。。省略异常
        }
    }

    if (earlySingletonExposure) {
        Object earlySingletonReference = getSingleton(beanName, false);
        // earlySingletonReference 只有在检测到有循环依赖的情况下才会不为空
        if (earlySingletonReference != null) {
            // 如果exposedObject没有在初始化方法中被改变，也就是没有增强
            if (exposedObject == bean) {
                exposedObject = earlySingletonReference;
            } else if (!this.allowRawInjectionDespiteWrapping 
                       && hasDependentBean(beanName)) {
                String[] dependentBeans = getDependentBeans(beanName);
                Set<String> actualDependentBeans = 
                    new LinkedHashSet<>(dependentBeans.length);

                for (String dependentBean : dependentBeans) {
                    // 检测依赖
                    if (!removeSingletonIfCreatedForTypeCheckOnly(dependentBean)) {
                        actualDependentBeans.add(dependentBean);
                    }
                }
                // 因为bean创建后其所依赖的bean一定是已经创建的
                // actualDependentBeans 不为空则表示当前bean创建后其依赖的bean
                // 却没有完全创建完，这就是说存在循环依赖
                if (!actualDependentBeans.isEmpty()) {
                   。。。省略异常
                }
            }
        }
    }
    // 根据scope注册bean，如果配置了destory-method，这里需要注册以便于销毁时候调用
    try {
        registerDisposableBeanIfNecessary(beanName, bean, mbd);
    } catch (BeanDefinitionValidationException ex) {
      省略异常
    }
    return exposedObject;
}
```

整体的思路：

1. 如果是单例模式，则移除factoryBeanInstanceCache缓存，同时返回 BeanWrapper 实例对象，当然如果存在。
2. 如果缓存中没有BeanWrapper或者不是单例模式，则调用 `createBeanInstance()` 实例化bean，主要是将 BeanDefinition 转换为 BeanWrapper
   1. 如果存在工厂方法，则使用工厂方法进行初始化
   2. 一个类有多个构造函数，每个构造函数都有不同的参数，所以需要根据参数锁定构造函数并进行初始化
   3. 如果既不存在工厂函数也不存在带有参数的构造器函数则使用默认的构造函数进行bean的实例化
3.  MergedBeanDefinitionPostProcessor 的应用，Autowired注解正式通过此方法实现注入类型解析
4. 单例模式的循环依赖处理（后面会重点说到）
5. 调用 `populateBean()` 进行属性填充。将所有属性填充至 bean 的实例中
6.  调用 `initializeBean()` 初始化 bean，也就是init-method
7.  依赖检查，在Spring中只解决单例的循环依赖，这一步判断是否有循环依赖，如果抛出异常
8. 注册 DisposableBean，如果配置了destroy-method。这里需要注册以便于在销毁的时候进行调用。

`doCreateBean()` 完成 bean 的创建和初始化工作，内容太多，这里就只列出整体思路，下文开始将该方法进行拆分进行详细讲解，分布从以下几个方面进行阐述：

- `createBeanInstance()` 实例化 bean
- `populateBean()` 属性填充
- 循环依赖的处理
- `initializeBean()` 初始化 bean