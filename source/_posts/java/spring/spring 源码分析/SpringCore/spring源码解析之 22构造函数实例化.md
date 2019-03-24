---
title: ' spring源码解析之 22构造函数实例化'
tags:
  - spring源码解析
categories:
  - java
  - spring
  - spring 源码分析
  - SpringCore
author: fengxiutianya
abbrlink: f83ca2ec
date: 2019-01-15 03:36:00
---
# spring源码解析之 22构造函数实例化

## autowireConstructor()

这个初始化方法我们可以简单理解为是带有参数的初始化 bean 。
<!-- more -->

```java
public BeanWrapper autowireConstructor(String beanName, RootBeanDefinition mbd,
                                       @Nullable Constructor<?>[] chosenCtors, 
                                       @Nullable Object[] explicitArgs) {
    // 实例化BeanWrapper对象
    BeanWrapperImpl bw = new BeanWrapperImpl();
    this.beanFactory.initBeanWrapper(bw);

    Constructor<?> constructorToUse = null;
    ArgumentsHolder argsHolderToUse = null;
    Object[] argsToUse = null;
    // explicit通过getBean方法传入
    // 如果getBean方法调用的时候指定方法参数，那么直接使用
    if (explicitArgs != null) {
        argsToUse = explicitArgs;
    } else {
        // 如果在getBean方法时候没有指定则尝试从配置文件中解析
        Object[] argsToResolve = null;

        // 尝试从缓存中获取获取参数
        synchronized (mbd.constructorArgumentLock) {
            constructorToUse = (Constructor<?>)
                mbd.resolvedConstructorOrFactoryMethod;
            if (constructorToUse != null && mbd.constructorArgumentsResolved) {
                // 缓存中的构造参数
                argsToUse = mbd.resolvedConstructorArguments;
                if (argsToUse == null) {
                    argsToResolve = mbd.preparedConstructorArguments;
                }
            }
        }
        // 如果缓存中存在
        if (argsToResolve != null) {
            // 解析参数类型，如给定方法的构造函数A(int,int)则通过此方法后就会
            // 把配置中("1","1")转换为(1,1)
            // 缓存中的值可能是原始值也可能是最终值，在这里做处理
            argsToUse = resolvePreparedArguments(beanName, mbd,
                                                 bw, constructorToUse, 
                                                 argsToResolve, true);
        }
    }
    // 没有缓存也没有明确指定
    if (constructorToUse == null || argsToUse == null) {
        // Take specified constructors, if any.
        Constructor<?>[] candidates = chosenCtors;

        // 如果参数中没有指定构造函数
        if (candidates == null) {
            // 获取当前bean对应的class对象
            Class<?> beanClass = mbd.getBeanClass();
            try {
                // 获取所有的构造函数
                candidates = (mbd.isNonPublicAccessAllowed() ?
                              beanClass.getDeclaredConstructors() : 
                              beanClass.getConstructors());
            } catch (Throwable ex) {

            }
        }
        // 如果只有默认构造函数并且配置文件中也没有参数配置
        if (candidates.length == 1 && explicitArgs == null 
            && !mbd.hasConstructorArgumentValues()) {
            Constructor<?> uniqueCandidate = candidates[0];
            // 缓存构造函数
            if (uniqueCandidate.getParameterCount() == 0) {
                synchronized (mbd.constructorArgumentLock) {
                    mbd.resolvedConstructorOrFactoryMethod = uniqueCandidate;
                    mbd.constructorArgumentsResolved = true;
                    mbd.resolvedConstructorArguments = EMPTY_ARGS;
                }
                // 使用默认构造函数初始化对象
                bw.setBeanInstance(instantiate(beanName, mbd, 
                                               uniqueCandidate, EMPTY_ARGS));
                return bw;
            }
        }


        // Need to resolve the constructor.
        // 判断是否需要解析构造函数
        boolean autowiring = (chosenCtors != null ||
                              mbd.getResolvedAutowireMode() == 
                              AutowireCapableBeanFactory.AUTOWIRE_CONSTRUCTOR);

        // 用于承载解析后的构造函数的值
        ConstructorArgumentValues resolvedValues = null;

        int minNrOfArgs;
        if (explicitArgs != null) {
            minNrOfArgs = explicitArgs.length;
        } else {
            // 从BeanDefinition中获取构造参数，也就是从配置文件中提取构造函数
            ConstructorArgumentValues cargs = mbd.getConstructorArgumentValues();
            resolvedValues = new ConstructorArgumentValues();
            // 解析构造函数的参数
            // 将该bean的构造函数参数解析为resolvedValues对象，其中会涉及到其它bean
            minNrOfArgs = resolveConstructorArguments(beanName, mbd, bw, 
                                                      cargs, resolvedValues);
        }
        // 对构造函数进行排序处理
        // public 构造函数优先参数数量降序，非public 构造函数参数数量降序
        AutowireUtils.sortConstructors(candidates);
        //  最小参数类型权重
        int minTypeDiffWeight = Integer.MAX_VALUE;
        Set<Constructor<?>> ambiguousConstructors = null;
        LinkedList<UnsatisfiedDependencyException> causes = null;

        // 迭代所有构造函数
        for (Constructor<?> candidate : candidates) {
            // 获取构造函数参数类型
            Class<?>[] paramTypes = candidate.getParameterTypes();
            // 如果已经找到选用的构造函数或者需要的参数个数小于当前的构造函数参数个数，则终止
            // 因为已经按照参数个数降序排列了
            if (constructorToUse != null && argsToUse != null &&
                argsToUse.length > paramTypes.length) {

                break;
            }
            // 参数个数不等，继续
            if (paramTypes.length < minNrOfArgs) {
                continue;
            }

            // 参数持有者
            ArgumentsHolder argsHolder;
            // 有参数
            if (resolvedValues != null) {
                try {
                    // 注解上获取参数名称
                    String[] paramNames = 
                        ConstructorPropertiesChecker.evaluate(candidate, 
                                                              paramTypes.length);

                    if (paramNames == null) {
                        // 获取构造函数、方法参数的探测器
                        ParameterNameDiscoverer pnd = 
                            this.beanFactory.getParameterNameDiscoverer();
                        if (pnd != null) {
                            // 通过探测器获取构造函数的参数名称
                            paramNames = pnd.getParameterNames(candidate);
                        }
                    }
                    // 根据构造函数和构造参数创建参数持有者
                    argsHolder = createArgumentArray(beanName, mbd, 
                                                     resolvedValues, bw, 
                                                     paramTypes, paramNames,
     						getUserDeclaredConstructor(candidate), autowiring, 
                                                     candidates.length == 1);
                } catch (UnsatisfiedDependencyException ex) {

                }
                // Swallow and try next constructor.
                if (causes == null) {
                    causes = new LinkedList<>();
                }
                causes.add(ex);
                continue;
            }
        } else {
            // 构造函数没有参数

            if (paramTypes.length != explicitArgs.length) {
                continue;
            }
            argsHolder = new ArgumentsHolder(explicitArgs);
        }
        //isLenientConstructorResolution判断解析构造函数的时候是否以宽松模式还是严格模式
        // 严格模式：解析构造函数时，必须所有的都需要匹配，否则抛出异常
        // 宽松模式：使用具有"最接近的模式"进行匹配
        // typeDiffWeight：类型差异权重
        int typeDiffWeight = (mbd.isLenientConstructorResolution() ?
                              argsHolder.getTypeDifferenceWeight(paramTypes) :
                              argsHolder.getAssignabilityWeight(paramTypes));
        // Choose this constructor if it represents the closest match.
        // 如果它代表着当前最接近的匹配则选择其作为构造函数
        if (typeDiffWeight < minTypeDiffWeight) {
            constructorToUse = candidate;
            argsHolderToUse = argsHolder;
            argsToUse = argsHolder.arguments;
            minTypeDiffWeight = typeDiffWeight;
            ambiguousConstructors = null;
        } else if (constructorToUse != null &&
                   typeDiffWeight == minTypeDiffWeight) {
            if (ambiguousConstructors == null) {
                ambiguousConstructors = new LinkedHashSet<>();
                ambiguousConstructors.add(constructorToUse);
            }
            ambiguousConstructors.add(candidate);
        }
    }

    if (constructorToUse == null) {
        if (causes != null) {
            UnsatisfiedDependencyException ex = causes.removeLast();
            for (Exception cause : causes) {
                this.beanFactory.onSuppressedException(cause);
            }
            throw ex;
        }

    } else if (ambiguousConstructors != null && 
               !mbd.isLenientConstructorResolution()) {

    }
    // 将构造函数、构造参数保存到缓存中
    if (explicitArgs == null && argsHolderToUse != null) {
        argsHolderToUse.storeCache(mbd, constructorToUse);
    }
}

Assert.state(argsToUse != null, "Unresolved constructor arguments");
// 实例化bean
bw.setBeanInstance(instantiate(beanName, mbd, constructorToUse, argsToUse));
return bw;
}

```

代码与 `instantiateUsingFactoryMethod()` 一样，又长又难懂，但是如果理解了 `instantiateUsingFactoryMethod()` 初始化 bean 的过程，那么 `autowireConstructor()` 也不存在什么难的地方了，一句话概括：首先确定构造函数参数、构造函数，然后调用相应的初始化策略进行 bean 的初始化。关于如何确定构造函数、构造参数，该部分逻辑和 `instantiateUsingFactoryMethod()` 基本一致。所以这里你应该相对会轻松点

1. 构造函数参数的确定

   * 根据explicitArgs参数判断

     如果传入的参数explicitArgs不为空，那边可以直接确定参数，因为explicitArgs参数是在调用bean的时候用户指定的，在BeanFactory类中存在这样的方法：

     ```java
     Object getBean(String name,Object... args) throws BeansException
     ```

     在获取bean的时候，用户不但可以指定bean的名称还可以指定bean对应类的构造函数或者工厂方法的方法参数，主要用于静态工厂方法的调用，而这里需要先给定完全匹配的参数，如果传入参数explicitArg不为空，则可以确定构造函数参数就是它。

   * 缓存中获取

     除此之外，确定参数的办法如果之前已经分析过，也就是说构造参数已经记录在缓存中，那么便可以直接拿来使用。而且，这里要提到的是，在魂村中换粗的可能是参数的最终类型也可能是参数的初始类型。如果是初始类型，则需要进行转换。

   * 配置文件中获取

     如果不能根据传入参数explicitArg确定构造函数的参数也无法在缓存中得到相关信息，那么只能开始新一轮的分析。分析从配置文件中配置的构造函数信息开始，经过之前的分析，我们知道，spring中配置文件中的信息经过转换都会通过BeanDefinition实例承载，也就是参数mbd中包含，那么可以通过调用mdb.getContructorArgumentValues来获取配置的构造函数信息。有了配置中的信息便可以获取对应的参数值信息。获取参数值的信息包括直接指定值，如：直接指定构造函数中某个值为原始类型String类型，或者是一个队其他bean的引用，这里处理委托给resolveConstrucorArguments方法，并返回能解析到的参数的个数

2. 构造函数的确定

   经过了第一步后已经确定了构造函数的参数，接下来的任务就是根据构造函数参数在所有构造函数中锁定对应的构造函数，而匹配的方法就是根据参数个数匹配，所以在匹配之前需要先对构造函数按照public构造函数优先参数量降序、feipublic构造函数参数数量降序，这样可以在遍历的情况下循序判断牌子啊后面的构造函数参数个数是否符合条件。

   由于在配置文件中并不是唯一现在使用参数位置索引的方式去创建，同样还支持指定参数名称进行设定参数值的情况，如`<constructor-arg name="aa">`，那么这种情况就需要首先确定构造函数中的参数名称。

   获取参数名称可以有俩种方式，一种是通过注解的方式直接获取，另一种就是使用spring中提供的工具类ParameterNameDiscover来获取，构造函数、参数名称、参数哦类型、参数值都确定后就可以锁定构造函数以及转换对应的参数类型。

3. 根据确定的构造函数转换对应的参数类型

   主要使用spring中提供的类型转换器或者用户提供的自定义类型转换器进行转换。

4. 根据构造函数不确定性的验证

   当然，有时候即使构造函数，参数名称，参数类型、参数值都确定后也不一定会直接锁定构造函数，不同构造函数的参数为父子类型，所以spring在最后有做了一次验证。

   根据实例化策略以及得到的构造函数即构造函数参数实例化bean。下面我们重点分析初始化策略：

对于初始化策略，首先是获取实例化 bean 的策略，如下：

```java
final InstantiationStrategy strategy = beanFactory.getInstantiationStrategy();
```

然后是调用其 `instantiate()`方法，该方法在 SimpleInstantiationStrategy 中实现，如下：

```java
public Object instantiate(RootBeanDefinition bd, 
                          @Nullable String beanName, BeanFactory owner) {
    // 没有覆盖
    // 直接使用反射实例化即可
    if (!bd.hasMethodOverrides()) {
        // 重新检测获取下构造函数
        // 该构造函数是经过前面 N 多复杂过程确认的构造函数
        Constructor<?> constructorToUse;
        synchronized (bd.constructorArgumentLock) {
            // 获取已经解析的构造函数
            constructorToUse = (Constructor<?>) 
                bd.resolvedConstructorOrFactoryMethod;
            // 如果为 null，从 class 中解析获取，并设置
            if (constructorToUse == null) {
                final Class<?> clazz = bd.getBeanClass();
                if (clazz.isInterface()) {
                  。。。。省略异常
                }
                try {
                    if (System.getSecurityManager() != null) {
                        constructorToUse = AccessController.doPrivileged(
                            (PrivilegedExceptionAction<Constructor<?>>) 
                            clazz::getDeclaredConstructor);
                    }
                    else {
                        constructorToUse =  clazz.getDeclaredConstructor();
                    }
                    bd.resolvedConstructorOrFactoryMethod = constructorToUse;
                }
                catch (Throwable ex) {
                  。。。省略异常
                }
            }
        }

        // 通过BeanUtils直接使用构造器对象实例化bean
        return BeanUtils.instantiateClass(constructorToUse);
    }
    else {
        // 生成CGLIB创建的子类对象
        return instantiateWithMethodInjection(bd, beanName, owner);
    }
}
```

如果该 bean 没有配置 lookup-method、replaced-method 标签或者 @Lookup 注解，则直接通过反射的方式实例化 bean 即可，方便快捷，但是如果存在需要覆盖的方法或者动态替换的方法则需要使用 CGLIB 进行动态代理，因为可以在创建代理的同时将动态方法织入类中。

**反射**

调用工具类 BeanUtils 的 `instantiateClass()` 方法完成反射工作：

```java
public static <T> T instantiateClass(Constructor<T> ctor, Object... args)
    throws BeanInstantiationException {
    Assert.notNull(ctor, "Constructor must not be null");
    try {
        ReflectionUtils.makeAccessible(ctor);
        return (KotlinDetector.isKotlinType(ctor.getDeclaringClass()) ?
                KotlinDelegate.instantiateClass(ctor, args) : 
                ctor.newInstance(args));
    }
    // 省略一些 catch 
}
```

**CGLIB**

```java
protected Object instantiateWithMethodInjection(RootBeanDefinition bd,
        @Nullable String beanName, BeanFactory owner) {
    throw new UnsupportedOperationException("Method Injection not supported in 
                                            SimpleInstantiationStrategy");
}
```

方法默认是没有实现的，具体过程由其子类 CglibSubclassingInstantiationStrategy 实现：

```java
protected Object instantiateWithMethodInjection(RootBeanDefinition bd, 
                    @Nullable String beanName, BeanFactory owner) {
    return instantiateWithMethodInjection(bd, beanName, owner, null);
}

protected Object instantiateWithMethodInjection(RootBeanDefinition bd, 
              @Nullable String beanName, BeanFactory owner,
              @Nullable Constructor<?> ctor, @Nullable Object... args) {

    // 通过CGLIB生成一个子类对象
    return new CglibSubclassCreator(bd, owner).instantiate(ctor, args);
}
```

创建一个 CglibSubclassCreator 对象，调用其 `instantiate()` 方法生成其子类对象：

```java
public Object instantiate(@Nullable Constructor<?> ctor, @Nullable Object... args) 
{
    // 通过 Cglib 创建一个代理类
    Class<?> subclass = createEnhancedSubclass(this.beanDefinition);
    Object instance;
    // 没有构造器，通过 BeanUtils 使用默认构造器创建一个bean实例
    if (ctor == null) {
        instance = BeanUtils.instantiateClass(subclass);
    }
    else {
        try {
            // 获取代理类对应的构造器对象，并实例化 bean
            Constructor<?> enhancedSubclassConstructor = 
                subclass.getConstructor(ctor.getParameterTypes());
            instance = enhancedSubclassConstructor.newInstance(args);
        }
        catch (Exception ex) {

        }
    }

    // 为了避免memory leaks异常，直接在bean实例上设置回调对象
    Factory factory = (Factory) instance;
    factory.setCallbacks(new Callback[] {NoOp.INSTANCE,
                 new CglibSubclassingInstantiationStrategy
                     .LookupOverrideMethodInterceptor(this.beanDefinition, this.owner),
                                         new CglibSubclassingInstantiationStrategy
			.ReplaceOverrideMethodInterceptor(this.beanDefinition, this.owner)});
    return instance;
}
```

到这类 CGLIB 的方式分析完毕了，当然这里还没有具体分析 CGLIB 生成子类的详细过程，具体的过程等后续分析 AOP 的时候再详细地介绍。

## instantiateBean()

```java
   protected BeanWrapper instantiateBean(final String beanName,
                                         final RootBeanDefinition mbd) {
        try {
            Object beanInstance;
            final BeanFactory parent = this;
            if (System.getSecurityManager() != null) {
                beanInstance = AccessController.doPrivileged(
                    (PrivilegedAction<Object>) () ->
                                getInstantiationStrategy().instantiate(mbd,
                                   beanName, parent),
                        getAccessControlContext());
            }
            else {
                beanInstance = getInstantiationStrategy()
                    		.instantiate(mbd, beanName, parent);
            }
            BeanWrapper bw = new BeanWrapperImpl(beanInstance);
            initBeanWrapper(bw);
            return bw;
        }
        catch (Throwable ex) {
          	、、。。。
        }
    }
```

这个方法相比于 `instantiateUsingFactoryMethod()` 、 `autowireConstructor()` 方法相对简单，因为它没有参数，所以不需要确认经过复杂的过来来确定构造器、构造参数，所以这里就不过多阐述了。

对于 `createBeanInstance()` 而言，他就是选择合适实例化策略来为 bean 创建实例对象，具体的策略有：Supplier 回调方式、工厂方法初始化、构造函数自动注入初始化、默认构造函数注入。其中工厂方法初始化和构造函数自动注入初始化两种方式最为复杂，主要是因为构造函数和构造参数的不确定性，Spring 需要花大量的精力来确定构造函数和构造参数，如果确定了则好办，直接选择实例化策略即可。当然在实例化的时候会根据是否有需要覆盖或者动态替换掉的方法，因为存在覆盖或者织入的话需要创建动态代理将方法织入，这个时候就只能选择 CGLIB 的方式来实例化，否则直接利用反射的方式即可，方便快捷。

到这里 `createBeanInstance()` 的过程就已经分析完毕了，下篇介绍 `doCreateBean()` 方法中的第二个过程：属性填充。