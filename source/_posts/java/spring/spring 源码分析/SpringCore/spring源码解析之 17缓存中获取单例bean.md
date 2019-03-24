---
title: spring源码解析之 17缓存中获取单例bean
tags:
  - spring源码解析
categories:
  - java
  - spring
  - spring 源码分析
  - SpringCore
author: fengxiutianya
abbrlink: cce70190
date: 2019-01-15 03:31:00
---
从这篇博客开始我们开始加载 bean 的第一个步骤，从缓存中获取 bean，代码片段如下：

```java
Object sharedInstance = getSingleton(beanName);
if (sharedInstance != null && args == null) {
    if (logger.isDebugEnabled()) {
        if (isSingletonCurrentlyInCreation(beanName)) {
            。。省略日志
        }
        else {
            。。。省略日志
        }
    }
    bean = getObjectForBeanInstance(sharedInstance, name, beanName, null);
}
```

首先调用 `getSingleton()` 从缓存中获取单例bean，在上篇博客提到过，Spring 对单例模式的bean只会创建一次，后续如果再获取该 bean 则是直接从单例缓存中获取，该过程就体现在 `getSingleton()` 中。如下：

<!-- more -->

```java
public Object getSingleton(String beanName) {
    // 参数true设置表示允许早期依赖
    return getSingleton(beanName, true);
}

@Nullable
protected Object getSingleton(String beanName, boolean allowEarlyReference) {
    // 检查缓存中是否存在实例
    Object singletonObject = this.singletonObjects.get(beanName);
    // 如果为空，并且正在创建这个bean，则锁定存放实例化bean的全局变量并进行处理
    if (singletonObject == null && isSingletonCurrentlyInCreation(beanName)) {
        // 锁住缓存实例化Bean的全局变量，防止出现线程安全问题，
        // 也就是有另外的线程在创建这个bean，这可以阻塞住其他创建的线程，
        // 等待此线程创建完成
        synchronized (this.singletonObjects) {
            // 此处是用来获取正在创建过程中bean，此处可能是没有创建完全的bean，
            // 也就是没有进行依赖注入等操作的bean
            singletonObject = this.earlySingletonObjects.get(beanName);
            // 如果没有正在创建，并且允许提前引用，则进行创建bean，但没有实例化完整的bean
            if (singletonObject == null && allowEarlyReference) {
                // 当某些方法需要提前初始化的时候会调用addSingletonFactory方法将对应的
                // ObjectFactory初始化策略存储在singletonFactories
                // 获取对应的bean的factoryBean,
                ObjectFactory<?> singletonFactory = 
                    this.singletonFactories.get(beanName);
                // 如果创建bean的ObjectFactory不为空，则创建对应的对象
                if (singletonFactory != null) {
                    // 调用预先设定的getObject方法
                    singletonObject = singletonFactory.getObject();
                    // 记录在缓存中earlySingletonObjects和singletonFactories互斥
                    // 这一点可以这样理解如果你用ObjectFactory提前创建了一个对象，
                    // 而此对象是单例的，因此你应该将创建的这个对象放到单例对象缓存队列中
                    // 另外删除这个创建对象的工厂，因为不能在创建此对象，否则就不是单例。
                    this.earlySingletonObjects.put(beanName, singletonObject);
                    this.singletonFactories.remove(beanName);
                }
            }
        }
    }
    // 从上面的过程可以看出此处的bean可能是没有创建完成的bean
    return singletonObject;
}
```

首先解释上面用到的一些变量：

- **singletonObjects** ：存放的是单例 bean，已经完整实例化的bean，对应关系为 `bean name --> bean instance`
- **earlySingletonObjects**：存放的是早期的 bean，对应关系也是 `bean name --> bean instance`。它与 singletonObjects 区别在于 earlySingletonObjects 中存放的 bean 不一定是完整的，从上面过程中我们可以了解，bean 在创建过程中就已经加入到 earlySingletonObjects 中了，所以当在 bean 的创建过程中就可以通过 `getBean()` 方法获取。这个 Map 也是解决循环依赖的关键所在。
- **singletonFactories**：存放的是 ObjectFactory，可以理解为创建单例 bean 的 factory，对应关系是 `bean name --> ObjectFactory`。在代码注释中也说了，这个和前面的earlySingletonObjects是互斥的。
- **registeredSingletons**:这个是用于保存所有已经注册的bean，这里先提前讲，后面会用到

这里先总结一下上面的整个流程

1. 如果从singletonObjects中获取到的bean不为空，则进入最后一步，
2. 如果获取到的bean为空，并且正在进行创建，则进入下一步，否则直接进入最后一步。
3. 先锁住singletonObjects，防止其他线程插入同一个bean的不同对象，然后从earlySingletonObjects获取对应的bean，如果不为空则进入最后一步。否则进入下一步
4. 如果从earlySingletonObjects获取到的对象为空，并且允许提前暴露bean对象，则从singletonFactories获取对应的创建bean的工厂，如果不为空，则创建bean对象，并将此插入到earlySingletonObjects中，然后从singletonFactories移除。
5. 返回singletonObject对象。

下面我们来看看上面存放键值对的Map种类，代码如下

```java
/**
* Cache of singleton objects: bean name to bean instance.
* 用于保存beanName和创建bean之间的关系，这里的bean是已经实例化完全的
*/
private final Map<String, Object> singletonObjects = new ConcurrentHashMap<>(256);

/**
* Cache of singleton factories: bean name to ObjectFactory.
* 用于保存beanMame和创建bean的工厂之间的关系
*/
private final Map<String, ObjectFactory<?>> singletonFactories = new HashMap<>(16);

	/**
	 * Cache of early singleton objects: bean name to bean instance.
	 * 也是保存BeanName和创建bean实例之间的关系，与singletonObjects的不同之处在于
	 * 当一个单例bean被放到这里后，那么当bean还在创建过程中，就可以通过getBean方法
	 * 获取到，其目的是用来检测循环引用，这里面的bean还没有实例化完成
	 */
private final Map<String, Object> earlySingletonObjects = new HashMap<>(16);

	/**
	 * Set of registered singletons, containing the bean names in registration order.
	 * 拿来保存当前已注册的bean
	 */
private final Set<String> registeredSingletons = new LinkedHashSet<>(256);
```

从上面可以看出，singletonObjects为了确保线程安全，使用的是ConcurrentHashMap。其他的是通过Synchronized关键字来保证的线程安全。

在上面代码中还有一个非常重要的检测方法 `isSingletonCurrentlyInCreation(beanName)`，该方法用于判断该 beanName对应的bean是否在创建过程中，注意这个过程讲的是整个IOC中。如下：

```java
public boolean isSingletonCurrentlyInCreation(String beanName) {
    return this.singletonsCurrentlyInCreation.contains(beanName);
}
```

从这段代码中我们可以预测，在bean创建过程中会将其加入到 singletonsCurrentlyInCreation 集合中，具体是在什么时候加的，我们后面分析。

到这里从缓存中获取 bean 的过程已经分析完毕了，我们再看开篇的代码段，从缓存中获取 bean 后，若其不为 null 且 args 为空，则会调用 `getObjectForBeanInstance()` 处理。

为什么会有这么一段呢？因为我们从缓存中获取的 bean 是最原始的 bean 并不一定使我们最终想要的 bean，所以需要调用 `getObjectForBeanInstance()` 进行处理，该方法的定义为获取给定 bean 实例的对象，该对象要么是 bean 实例本身，要么就是 FactoryBean 创建的对象，如下：

```java
protected Object getObjectForBeanInstance(
			Object beanInstance, String name, String beanName, @Nullable RootBeanDefinition mbd) {

        // 根据传进来的name，这个是用户传进来的原始值，没有经过转换
		// 判断是否是获取FactoryBean，如果是，则判断beanInstance
		// 是不是FactoryBean类型，如果不是抛出异常
		if (BeanFactoryUtils.isFactoryDereference(name)) {
			// 如果创建的bean是null类型，则直接返回
			if (beanInstance instanceof NullBean) {
				return beanInstance;
			}
			if (!(beanInstance instanceof FactoryBean)) {
				  。。。。省略异常
			}
		}
		// 如果用户确实想得到的是FactoryBean，则返回当前Bean实例
		if (!(beanInstance instanceof FactoryBean) || 
            BeanFactoryUtils.isFactoryDereference(name)) {
			return beanInstance;
		}

		// 加载FactoryBean，通过上面的排除，已经确定是要获取bean而不是FactoryBean
		
		Object object = null;
		
		// mbd为null，可能这个bean已经被创建，尝试从缓存中获取beanName对应的Bean，
		if (mbd == null) {
			//  缓存单例类型的bean，并且里面的bean是由FactoryBean创建，
            //  键值对：FactoryBean name ---> bean实例
			//	private final Map<String, Object> factoryBeanObjectCache
            //      = new ConcurrentHashMap<>(16);
			object = getCachedObjectForFactoryBean(beanName);
		}
		
		if (object == null) {
			// 到这里已经确定beanInstance是FactoryBean类型，进行强转
			FactoryBean<?> factory = (FactoryBean<?>) beanInstance;
			// 获取bean对应的BeanDefinition
			if (mbd == null && containsBeanDefinition(beanName)) {
				// 将存在XML配置文件的GernericBeanDefinition转换为RootBeanDefinition
				// 如果指定BeanName是子Bean的话同时会合并父类的相关属性
				mbd = getMergedLocalBeanDefinition(beanName);
			}
			// 判断是否是用户定义的而不是应用程序本身定义的
			boolean synthetic = (mbd != null && mbd.isSynthetic());
			// 从FactoryBean中获取bean的工作委托给getObjectFromFactoryBean
			object = getObjectFromFactoryBean(factory, beanName, !synthetic);
		}
		return object;
	}

```

该方法主要是进行检测工作的，主要如下：

1. 根据name判断获取的bean实例是否为FactoryBean（以 & 开头），如果是，会进行如下检测

   1. 检测beanInstance是否为NullBean 类型，这个是spring定义的null类型，如果是则直接返回，
   2. 如果beanInstance不是FactoryBean类型则抛出 BeanIsNotFactoryException 异常。

   这里主要是校验 beanInstance 的正确性。

2. 判断当前beanInstance不是FactoryBean，如果不是则直接返回，如果是则判断用户是否希望获取的是FactoryBean类型的bean。如果是直接返回。这里有一点需要主要的是，FactoryBean创建的bean会单独存放在factoryBeanObjectCache，不会存放在singletonObjects中。

3. 从factoryBeanObjectCache中获取对应的bean，如果获取到的对象不为空，则返回

4. 如果获取到的对象为空，则需要委托getObjectFromFactoryBean来进一步处理。

再继续分析`getObjectFromFactoryBean`之前，我们先介绍一下FactoryBean，感觉很相似，因为我们前面经常说BeanFactory，简单说一下他们的区别。 BeanFactory和FactoryBean其实没有什么比较性的，只是两者的名称特别接近，所以有时候会拿出来比较一番，BeanFactory是提供了IOC容器最基本的形式，给具体的IOC容器的实现提供了规范，FactoryBean可以说为IOC容器中Bean的实现提供了更加灵活的方式，FactoryBean在IOC容器的基础上给Bean的实现加上了一个简单工厂模式和装饰模式，我们可以在getObject()方法中灵活配置。具体的可以看这篇文章[BeanFactory和FactoryBean的区别](https://blog.csdn.net/wangbiao007/article/details/53183764)

从上面可以看出 `getObjectForBeanInstance()` 主要是返回给定的 bean 实例对象，当然该实例对象为非 FactoryBean类型，对于FactoryBean类型的 bean，则是委托 `getObjectFromFactoryBean()` 从FactoryBean获取 bean 实例对象。

```java
protected Object getObjectFromFactoryBean(FactoryBean<?> factory,
                                          String beanName, boolean shouldPostProcess) {
    // 如果此beanName对应的FactoryBean是单例bean，
    if (factory.isSingleton() && containsSingleton(beanName)) {
        // singletonObjects进行
        synchronized (getSingletonMutex()) {
            // 从缓存中获取对应的bean
            Object object = this.factoryBeanObjectCache.get(beanName);
            if (object == null) {
                // 创建bean
                object = doGetObjectFromFactoryBean(factory, beanName);
                // 下面这种情况是为了避免由于循环引用导致提前创建了一个一样的bean
                // 为了一致，则抛弃当前的bean
                Object alreadyThere = this.factoryBeanObjectCache.get(beanName);
                if (alreadyThere != null) {
                    object = alreadyThere;
                } else {
                    if (shouldPostProcess) {
                        // 若该 bean 处于创建中，则返回非处理对象，而不是存储它
                        if (isSingletonCurrentlyInCreation(beanName)) {
                            return object;
                        }
                        beforeSingletonCreation(beanName);
                        try {
                            object = postProcessObjectFromFactoryBean(object, beanName);
                        } catch (Throwable ex) {
                           省略异常
                        } finally {
                            afterSingletonCreation(beanName);
                        }
                    }
                    if (containsSingleton(beanName)) {
                        this.factoryBeanObjectCache.put(beanName, object);
                    }
                }
            }
            return object;
        }
        // 非单例创建直接返回不需要存储
    } else {
        Object object = doGetObjectFromFactoryBean(factory, beanName);
        if (shouldPostProcess) {
            try {
                object = postProcessObjectFromFactoryBean(object, beanName);
            } catch (Throwable ex) {
                 。。。省略异常
            }
        }
        return object;
    }
}
```

主要分为俩种情况，一种是，FactoryBean为单例，另一种不是单例

先说第一种情况，FactoryBean为单例

1. 为了线程安全，获取同步锁（其实我们在前面篇幅中发现了大量的同步锁，锁住的对象都是 this.singletonObjects， 主要是因为在单例模式中必须要保证全局唯一），然后从factoryBeanObjectCache从获取beanName对应的bean。判断是否为空

2. 不为空直接返回。

3. 如果为空，则调用doGetObjectFromFactoryBean进行创建，如果创建之后检测到factoryBeanObjectCache已经有，则抛弃当前的bean。如果没有，则需要对当前创建的bean进行后续处理。

   如果需要后续处理，则进行进一步处理，步骤如下：

   - 若该 bean 处于创建中（isSingletonCurrentlyInCreation），则返回非处理对象，而不是存储它。这个是因为后面即将讲到的循环依赖所以你的，由于bean之间的依赖，会造成一些bean还没有初始化完成就提前创建出该对象的ObjectFactory对象，然后来生成对应bean，让正在创建的bean创建能继续处理，这里先理解个大概，后面会仔细说。
   - 调用 `beforeSingletonCreation()` 进行创建之前的处理。默认实现将该 bean 标志为当前创建的。
   - 调用 `postProcessObjectFromFactoryBean()` 对从 FactoryBean 获取的 bean 实例对象进行后置处理，默认实现是按照原样直接返回，具体实现是在 AbstractAutowireCapableBeanFactory 中实现的，当然子类也可以重写它，比如应用后置处理
   - 调用 `afterSingletonCreation()` 进行创建 bean 之后的处理，默认实现是将该 bean 标记为不再在创建中。

   - 最后加入到 FactoryBeans 缓存中。

第二种情况，不是单例

1. 根据传进来的factory创建出对应的bean实例
2. 进行后置处理，然后返回

该方法应该就是创建 bean 实例对象中的核心方法之一了。方法`doGetObjectFromFactoryBean`内部就是调用FactoryBean.get返回对应的bean，比较简单所以就不仔细说明。这里我们关注三个方法： `beforeSingletonCreation()` 、 `afterSingletonCreation()` 、 `postProcessObjectFromFactoryBean()`。可能有小伙伴觉得前面两个方法不是很重要，可以肯定告诉你，这两方法是非常重要的操作，因为**他们记录着 bean 的加载状态，是检测当前 bean 是否处于创建中的关键之处，对解决 bean 循环依赖起着关键作用**。before 方法用于标志当前 bean 处于创建中，after 则是移除。其实在这篇博客刚刚开始就已经提到了 `isSingletonCurrentlyInCreation()` 是用于检测当前 bean 是否处于创建之中，如下：

```java
public boolean isSingletonCurrentlyInCreation(String beanName) {
    return this.singletonsCurrentlyInCreation.contains(beanName);
}
```

是根据 singletonsCurrentlyInCreation 集合中是否包含了 beanName，集合的元素则一定是在 `beforeSingletonCreation()` 中添加的，如下：

```java
protected void beforeSingletonCreation(String beanName) {
    if (!this.inCreationCheckExclusions.contains(beanName) && 
        !this.singletonsCurrentlyInCreation.add(beanName)) {
        throw new BeanCurrentlyInCreationException(beanName);
    }
}
```

`afterSingletonCreation()` 为移除，则一定就是对 singletonsCurrentlyInCreation 集合 remove 了，如下：

```java
protected void afterSingletonCreation(String beanName) {
    if (!this.inCreationCheckExclusions.contains(beanName) && 
        !this.singletonsCurrentlyInCreation.remove(beanName)) {
        throw new IllegalStateException("Singleton '" +
                                        beanName + "' isn't currently in creation");
    }
}
```

`postProcessObjectFromFactoryBean()` 是对从 FactoryBean 处获取的 bean 实例对象进行后置处理，其默认实现是直接返回 object 对象，不做任何处理，子类可以重写，例如应用后处理器。AbstractAutowireCapableBeanFactory 对其提供了实现，如下：

```java
protected Object postProcessObjectFromFactoryBean(Object object, String beanName) {
    return applyBeanPostProcessorsAfterInitialization(object, beanName);
}
```

该方法的定义为：对所有的 postProcessAfterInitialization 进行回调注册BeanPostProcessors，让他们能够后期处理从 FactoryBean 中获取的对象。下面是具体实现：

```java
public Object applyBeanPostProcessorsAfterInitialization(Object existingBean, 
                         String beanName) throws BeansException {

    Object result = existingBean;
    for (BeanPostProcessor beanProcessor : getBeanPostProcessors()) {
        Object current = 
            beanProcessor.postProcessAfterInitialization(result, beanName);
        if (current == null) {
            return result;
        }
        result = current;
    }
    return result;
}
```

对于后置处理器，这里我们不做过多阐述，后面会专门的博文进行详细介绍，这里我们只需要记住一点：尽可能保证所有 bean 初始化后都会调用注册的 `BeanPostProcessor.postProcessAfterInitialization()` 方法进行处理，在实际开发过程中大可以针对此特性设计自己的业务逻辑。

