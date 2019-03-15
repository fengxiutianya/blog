abbrlink: 22
title: java 注解 01：基本介绍以及用法
tags:
  - 注解
categories:
  - java
author: fengxiutianya
date: 2019-03-04 07:20:00
---
# java 注解 01：基本介绍以及用法

### 概述

本篇主要对java Annotation进行了整理。理解 Annotation 的关键，是理解Annotation的语法和用法。下面也单独对此进行了详细的介绍。

1. Annotation 架构
2. Annotation 组成部分
3. Annotation 基本语法和java自带注解介绍
4. Annotation 的作用

<!-- more -->

###  **Annotation架构**

下面是Annotation整体的架构图，如果你对这个图感到迷惑，可以跳过这一节直接看Annotation的基本语法，然后回来再看。

![upload successful](/images/pasted-131.png)

下面，我先介绍框架图的左半边(如下图)，即Annotation, RetentionPolicy, ElementType；然后在就Annotation的实现类进行举例说明。

![upload successful](/images/pasted-132.png)

### Annotation组成部分

java annotation 的组成中，有3个非常重要的主干类。它们分别是：

(01) Annotation.java

```java
package java.lang.annotation;
public interface Annotation {

    boolean equals(Object obj);

    int hashCode();

    String toString();

    Class<? extends Annotation> annotationType();
}
```

(02) ElementType.java

```java
package java.lang.annotation;

public enum ElementType {
    TYPE,               /* 类、接口（包括注释类型）或枚举声明  */

    FIELD,              /* 字段声明（包括枚举常量）  */

    METHOD,             /* 方法声明  */

    PARAMETER,          /* 参数声明  */

    CONSTRUCTOR,        /* 构造方法声明  */

    LOCAL_VARIABLE,     /* 局部变量声明  */

    ANNOTATION_TYPE,    /* 注释类型声明  */

    PACKAGE             /* 包声明  */
}
```

(03) RetentionPolicy.java

```java
package java.lang.annotation;
public enum RetentionPolicy {
    SOURCE,            /* Annotation信息仅存在于编译器处理期间，编译器处理完之后就没有该Annotation信息了  */

    CLASS,             /* 编译器将Annotation存储于类对应的.class文件中。默认行为  */

    RUNTIME            /* 编译器将Annotation存储于class文件中，并且可由JVM读入 */
}
```

说明：

1. **Annotation** 是个接口：
   ​      **每1个Annotation** 都与 **1个RetentionPolicy**关联，并且与 **1～n个ElementType**关联。可以通俗的理解为：每1个Annotation对象，都会有唯一的RetentionPolicy属性；至于ElementType属性，则有1~n个。

2. **ElementType** 是个枚举类型，它用来指定Annotation的类型，说明Annotation可以在哪里使用。
    **每1个Annotation** 都与 **1～n个ElementType**关联。

   当Annotation与某个ElementType关联时，就意味着：Annotation有了某种用途。例如，若一个Annotation对象是METHOD类型，则该Annotation只能用来修饰方法。

3. **RetentionPolicy** 是枚举类型，它用来指定Annotation的策略。通俗点说，就是不同RetentionPolicy类型的Annotation的作用域不同。
   ​     **每1个Annotation**都与 **1个RetentionPolicy**关联。

   * 若Annotation的类型为 **SOURCE**，则意味着：Annotation仅存在于编译器处理期间，编译器处理完之后，该Annotation就没用了。
     ​          例如，`@Override`标志就是一个Annotation。当它修饰一个方法的时候，就意味着该方法覆盖父类的方法；并且在编译期间会进行语法检查！编译器处理完后，`@Override`就没有任何作用了。
   *  若Annotation的类型为 **CLASS**，则意味着：编译器将Annotation存储于类对应的.class文件中，它是Annotation的默认行 为。
   *  若Annotation的类型为 **RUNTIME**，则意味着：编译器将Annotation存储于class文件中，并且可由JVM读入。

这时，只需要记住*“每1个Annotation” 都与 “1个RetentionPolicy”关联，并且与 “1～n个ElementType”关联*。学完后面的内容之后，再回头看这些内容，会更容易理解。

### Annoation基本语法和java自带注解介绍

理解了上面的3个类的作用之后，我们接下来可以讲解Annotation实现类的语法定义了。

####  **1 Annotation基本语法**

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
public @interface MyAnnotation1 {

}
```

说明：

上面的作用是定义一个Annotation，它的名字是MyAnnotation1。定义了MyAnnotation1之后，我们可以在代码中通过`@MyAnnotation1`来使用它。
其它的， @Target, @Retention, @interface都是来修饰MyAnnotation1的。下面分别说说它们的含义：

1.  `@interface`
    使用@interface定义注解时，意味着它实现了java.lang.annotation.Annotation接口，即该注解就是一个Annotation。**定义Annotation时，@interface是必须的**
    注意：它和我们通常的implemented实现接口的方法不同。Annotation接口的实现细节都由编译器完成。通过@interface定义注解后，该注解不能继承其他的注解或接口。

2. `@Target(ElementType.TYPE)`
   ​      前面我们说过，ElementType 是Annotation的类型属性。而@Target的作用，就是来指定Annotation的类型属性。 `@Target(ElementType.TYPE)` 的意思就是指定该Annotation的类型是`ElementType.TYPE`。这就意味着，MyAnnotation1是来修饰**类、接口（包括注释类型）或枚举**声明的注解。
   注意： 定义Annotation时，@Target可有可无。若有@Target，则该Annotation只能用于它所指定的地方；若没有@Target，则该Annotation可以用于任何地方。

3. `@Retention(RetentionPolicy.RUNTIME)`
   ​      前面我们说过，RetentionPolicy 是Annotation的策略属性，而`@Retention`的作用，就是指定Annotation的策略属性。` @Retention(RetentionPolicy.RUNTIME) `的意思就是指定该Annotation的策略是`RetentionPolicy.RUNTIME`。这就意味着，编译器会将该Annotation信息保留在.class文件中，并且能被虚拟机读取。

   注意：定义Annotation时，`@Retention`可有可无。若没有`@Retention`，则默认是`RetentionPolicy.CLASS`。

#### 2 .java 中自带的注解

理解了上面java注解的基本语法之后，我们就很容易理解java中自带的Annotation的实现类，即Annotation架构图的右半边。如下图：

![upload successful](/images/pasted-133.png)

**java 常用的Annotation：**

```txt
@Deprecated  -- @Deprecated 所标注内容，不再被建议使用。
@Override    -- @Override 只能标注方法，表示该方法覆盖父类中的方法。
@Documented  -- @Documented 所标注内容，可以出现在javadoc中。
@Inherited   -- @Inherited只能被用来标注“Annotation类型”，它所标注的Annotation具有继承性。
@Retention   -- @Retention只能被用来标注“Annotation类型”，而且它被用来指定Annotation的RetentionPolicy属性。
@Target      -- @Target只能被用来标注“Annotation类型”，而且它被用来指定Annotation的ElementType属性。
@SuppressWarnings -- @SuppressWarnings 所标注内容产生的警告，编译器会对这些警告保持静默。
```

由于`@Deprecated和@Override`类似，`@Documented, @Inherited, @Retention, @Target`类似；下面，我们只对`@Deprecated, @SuppressWarnings`这2个Annotation进行说明，另外我会单独用一篇文章对`@Inherited`进行介绍

**@Deprecated**

@Deprecated 的定义如下：

```java
@Documented
@Retention(RetentionPolicy.RUNTIME)
public @interface Deprecated {
}
```

**说明**：

* @interface -- 它的用来修饰Deprecated，意味着Deprecated实现了java.lang.annotation.Annotation接口；即Deprecated就是一个注解。
*  @Documented -- 它的作用是说明该注解能出现在javadoc中。
*  @Retention(RetentionPolicy.RUNTIME) -- 它的作用是指定Deprecated的策略是		  RetentionPolicy.RUNTIME。这就意味着，编译器会将Deprecated的信息保留在.class文件中，并且能被虚拟机读取。

@Deprecated 注解的作用是：被其所标注内容，不再被建议使用。

**@SuppressWarnings**

@SuppressWarnings 的定义如下：

```java
@Target({TYPE, FIELD, METHOD, PARAMETER, CONSTRUCTOR, LOCAL_VARIABLE})
@Retention(RetentionPolicy.SOURCE)
public @interface SuppressWarnings {

    String[] value();

}
```

**说明**：

* @interface -- 它的用来修饰SuppressWarnings，意味着SuppressWarnings实现了java.lang.annotation.Annotation接口；即SuppressWarnings就是一个注解。
* @Retention(RetentionPolicy.SOURCE) -- 它的作用是指定SuppressWarnings的策略是RetentionPolicy.SOURCE。这就意味着，SuppressWarnings信息仅存在于编译器处理期间，编译器处理完之后SuppressWarnings就没有作用了。
*  @Target({TYPE, FIELD, METHOD, PARAMETER, CONSTRUCTOR, LOCAL_VARIABLE}) -- 它的作用是指定SuppressWarnings的类型同时包括`TYPE, FIELD, METHOD, PARAMETER, CONSTRUCTOR,LOCAL_VARIABLE。`
  ​       TYPE意味着，它能标注“类、接口（包括注释类型）或枚举声明”。
  ​       FIELD意味着，它能标注“字段声明”。
  ​       METHOD意味着，它能标注“方法”。
  ​       PARAMETER意味着，它能标注“参数”。
  ​       CONSTRUCTOR意味着，它能标注“构造方法”。
  ​       LOCAL_VARIABLE意味着，它能标注“局部变量”。
* String[] value(); 意味着，SuppressWarnings能指定参数

 SuppressWarnings 的作用是，让编译器对**它所标注的内容”的某些警告保持静默**。例如，`@SuppressWarnings(value={"deprecation", "unchecked"})`表示对它所标注的内容中的 “deprecation不再建议使用警告”和“未检查的转换时的警告”保持沉默。

补充：**SuppressWarnings 常用的关键字的表格**

```
deprecation  -- 使用了不赞成使用的类或方法时的警告
unchecked    -- 执行了未检查的转换时的警告，例如当使用集合时没有用泛型 (Generics) 来指定集合保存的类型。
fallthrough  -- 当 Switch 程序块直接通往下一种情况而没有 Break 时的警告。
path         -- 在类路径、源文件路径等中有不存在的路径时的警告。
serial       -- 当在可序列化的类上缺少 serialVersionUID 定义时的警告。
finally      -- 任何 finally 子句不能正常完成时的警告。
all          -- 关于以上所有情况的警告。
```

### **Annotation 的作用**

1. **编译检查**:

   通过代码里标识的元数据让编译器能实现基本的编译检查。

   例如，@SuppressWarnings, @Deprecated和@Override都具有编译检查作用。
   关于@SuppressWarnings和@Deprecated，已经在“第3部分”中详细介绍过了。这里就不再举例说明了。
   若某个方法被 @Override的 标注，则意味着该方法会覆盖父类中的同名方法。如果有方法被@Override标示，但父类中却没有“被@Override标注”的同名方法，则编译器会报错。

2. **根据Annotation生成帮助文档**

   通过给Annotation注解加上@Documented标签，能使该Annotation标签出现在javadoc中。

3. **在反射中使用Annotation**

   通过代码里标识的注解对代码进行分析。跟踪代码依赖性，实现替代配置文件功能。比较常见的是spring开始的基于注解配置。作用就是减少配置。现在的框架基本都使用了这种配置来减少配置文件的数量。