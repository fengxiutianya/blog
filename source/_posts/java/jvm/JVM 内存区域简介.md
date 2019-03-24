---
title: JVM 内存区域简介
tags:
  - 内存模型
categories:
  - java
  - jvm
abbrlink: 56bd0dd8
date: 2019-03-23 08:01:51
---
JVM内存区域包括计数器、Java虚拟机栈、本地方法栈、堆、方法区。本文主要是介绍各个内存区域的作用性和特性，同时分别阐述各个区域发生内存溢出的可能性和异常类型。

<!-- more -->

## JVM内存区域

Java虚拟机执行Java程序的过程中，会把所管理的内存划分为若干个不同的数据区域。这些内存区域各有各的用途，以及创建和销毁时间。有的区域随着虚拟机进程的启动而存在，有的区域伴随着线程的启动和结束而创建和销毁。

JVM内存区域也成为Java运行时数据区域。其中包括:程序计数器、虚拟机栈、本地方法栈、堆和方法区。

![upload successful](/images/pasted-282.png)

上图中，方法区和堆是线程共享，虚拟机栈、程序计数器和本地方法栈是线程私有。大概的结构如下图：

![upload successful](/images/pasted-283.png)

下面分别介绍每部分的是用来做什么的

### 程序计数器

程序计数器是一块较小的内存空间，它的作用可以看做是当前线程所执行的字节码行号的指示器。字节码解释器在工作时就是通过改变这个计数器的值来选取下一条需要执行的字节码指令。这个内存区域是线程私有的内存。

线程执行java方法时，这个区域记录横在执行的的虚拟机字节码指令地址，如果正在执行Native方法，计数器为空。此内存区域是唯一一个java虚拟机规范中没有规定任何OutOfMemoryError情况的区域。

### Java虚拟机栈

线程私有内存空间，它的生命周期与线程相同。虚拟机栈描述的是**Java方法执行**的内存模型；每个方法在执行的同时都会创建一个栈帧用于存储局部变量表、操作数栈、动态链接和方法出口等消息。每个方法的调用直至执行完成，都对应一个栈帧在虚拟机栈中入栈和出栈的过程。

这里简介一下虚拟机栈中的四中组成元素的功能：

1. 局部变量表：一组变量值的存储空间，用于存储参数和局部变量。
2. 操作数栈：也称操作栈，是一个后入先出栈。对应于java中每个函数中的每条指令。
3. 动态链接：每个栈帧都包含一个指向运行时常量池中所属的方法引用，持有这个引用是为了支持方法调用过程中的动态链接。
4. 方法返回地址：用于存储方法返回的地址，可以是正常返回，如果遇到异常，则是通过异常处理器来确定方法返回地址。

在Java虚拟机规范中，对这个区域规定了两种异常。

* 如果当前线程请求的栈深度大于虚拟机栈所允许的深度，将会抛出 `StackOverflowError` 异常（在虚拟机栈不允许动态扩展的情况下）；
* 如果扩展时无法申请到足够的内存空间，就会抛出 `OutOfMemoryError` 异常。

### 本地方法栈

本地方法栈与虚拟机栈所发挥的作用是非常相似的，他们之间的区别不过是虚拟机栈为虚拟机执行Java方法服务，而本地方法栈则为虚拟机使用到的Native方法服务。此外在虚拟机规范中并没有对本地方法栈中方法使用的语言、使用方法与数据结构做强制的规制，因此具体的虚拟机可以自由实现它。有些虚拟机发行版本(譬如`Sun HotSpot`虚拟机)直接将**本地方法栈**和`Java`**虚拟机**栈合二为一。与虚拟机栈一样，本地方法栈也会抛出`StackOverflowError`和`OutOfMemoryError`异常。

### 堆

Java堆是Java虚拟机所管理的内存中最大的一块。Java堆是被所有线程共享的一块内存区域，虚拟机启动时创建。此内存区域的唯一目的就是存放对象实例，几乎所有的对象实例都在这里分配内存。

在`Java`中，堆被划分成两个不同的区域：**新生代** (`Young Generation`) 、**老年代** (`Old Generation`) 。**新生代** (`Young`) 又被划分为三个区域：**一个**`Eden`区和**两个**`Survivor`区 - `From Survivor`区和`To Survivor`区。

如果在堆中没有内存完成实例分配，并且堆也无法再扩展时，将会抛出OutOfMemoryError异常。

### 方法区

方法区是各个线程共享的内存区域，它用于存储已被虚拟机加载的类信息、常量、静态变量、即时编译后的代码等数据。如果方法区无法申请到足够的内存空间，就会抛出 `OutOfMemoryError` 异常。

#### 运行时常量池

运行时常量池是方法区的一部分。Class文件除了有类的版本、字段、方法、接口等描述信息外，还有一项信息是常量池，用于存放编译期生成的各种字面量和符号引用，这部分内容将在类加载后，进入方法区的运行时常量池中存放。

JVM 规范对 class 文件结构有着严格的规范，必须符合此规范的 class 文件才会被 JVM 认可和装载。运行时常量池 中保存着一些class文件中描述的符号引用，同时还会将这些符号引用所翻译出来的直接引用存储在运行时常量池 中。
运行时常量池相对于 class 常量池一大特征就是其具有动态性，Java规范并不要求常量只能在编译才能产生，也就是说运行时常量池中的内容并不全部来自 class 常量池，class 常量池并非运行时常量池的唯一数据输入口；在运行时可以通过代码生成常量并将其放入运行时常量池中，这种特性被开发人员利用比较多的便是String类的intern()方法。
同方法区一样，当运行时常量池无法申请到新的内存时，将抛出 OutOfMemoryError 异常。

### 直接内存

这里补充一点，直接内存（Direct Memory）并不是虚拟机运行时数据区的一部分，也不是Java虚拟机规范中定义的内存区域。但是这部分内存也被频繁地使用，而且也可能导致OutOfMemoryError异常出现。

在JDK1.4中新加入了NIO类，引入了一种基于通道(Channel)和缓冲区（buffer）的I/O方式，他可以使用Native函数库直接分配堆外内存，然后通过一个存储在Java堆中的DirectByteBuffer对象作为这块内存的引用进行操作。这样能在一些场景中显著提高性能，因为避免了在Java堆和Native堆中来回复制数据。具体的可以参考这篇文章[直接内存](https://taolove.top/2019/01/14/nio/JAVA%20NIO%E4%B9%8B%E6%B5%85%E8%B0%88%E5%86%85%E5%AD%98%E6%98%A0%E5%B0%84%E6%96%87%E4%BB%B6%E5%8E%9F%E7%90%86%E4%B8%8EDirectBuffer/)

## 常见内存溢出异常

从上面可以看出，除了程序计数器外，Java虚拟机的其他运行区域都有可能发生OutOfMemoryError的异常。下面会分别给出例子。

### java堆溢出

`Java`堆能够存储对象实例。通过不断地创建对象，并保证`GC Roots`到对象有可达路径来避免垃圾回收机制清除这些对象。 当对象数量到达最大堆的容量限制时就会产生`OutOfMemoryError`异常。

设置`JVM`启动参数：`-Xms20M`设置堆的**最小内存**为`20M`，`-Xmx20M`设置堆的**最大内存**和**最小内存**一样，这样可以防止`Java`堆在内存不足时**自动扩容**。 `-XX:+HeapDumpOnOutOfMemoryError`参数可以让虚拟机在出现内存溢出异常时`Dump`出**内存堆**运行时快照。

```java
/**************************************
 *      Author : zhangke
 *      Date   : 2018/1/5 11:24
 *      Desc   : java 堆溢出异常测试
 *      VM Args :
 *      -Xms20m -Xmx20m -XX:+HeapDumpOnOutOfMemoryError
 *
 ***************************************/
public class HeapOOM {
    static class OOMObject{

    }
    public static void main(String[] args) {
        List<OOMObject> list = new ArrayList<>();
        while (true){
            list.add(new OOMObject());
        }
    }
}

```

运行结果：

```java
java.lang.OutOfMemoryError: Java heap space
Dumping heap to java_pid36748.hprof ...
Heap dump file created [27649036 bytes in 0.126 secs]
Exception in thread "main" java.lang.OutOfMemoryError: Java heap space
	at java.util.Arrays.copyOf(Arrays.java:3210)
	at java.util.Arrays.copyOf(Arrays.java:3181)
	at java.util.ArrayList.grow(ArrayList.java:261)
	at java.util.ArrayList.ensureExplicitCapacity(ArrayList.java:235)
	at java.util.ArrayList.ensureCapacityInternal(ArrayList.java:227)
	at java.util.ArrayList.add(ArrayList.java:458)
	at OutOfMemory.HeapOOM.main(HeapOOM.java:22)
```

你可以打开`VisualVM`导入`Heap`内存运行时的`dump`文件，就会出现类似下面这个图：

![upload successful](/images/pasted-334.png)

静态类OOMObject的对象不停地被创建，堆内存使用达到99%。垃圾回收器不断地尝试回收但都以失败告终。

分析：遇到这种情况，通常要考虑**内存泄露**和**内存溢出**两种可能性。

- 如果是内存泄露：

  进一步使用`Java VisualVM`工具进行分析，查看**泄露对象**是通过怎样的`路径`与`GC Roots`关联而导致**垃圾回收器**无法回收的。

- 如果是内存溢出：

  通过`Java VisualVM`工具分析，不存在泄露对象，也就是说**堆内存**中的对象必须得存活着。就要考虑如下措施：

  1. 从代码上检查是否存在某些对象**生命周期过长**、**持续状态时间过长**的情况，尝试减少程序运行期的内存。
  2. 检查虚拟机的**堆参数**(`-Xmx`与`-Xms`)，对比机器的**物理内存**看是否还可以调大。

### 虚拟机和本地方法栈溢出

关于虚拟机栈和本地方法栈，分析内存异常类型可能存在以下两种：

- 如果现场请求的**栈深度**大于虚拟机所允许的**最大深度**，将抛出`StackOverflowError`异常。
- 如果虚拟机在**扩展栈**时无法申请到足够的**内存**空间，可能会抛出`OutOfMemoryError`异常。

可以划分为两类问题，当栈空间无法分配时，到底时栈内存**太小**，还是**已使用**的栈内存**过大**。

#### StackOverflowError异常

- 使用`-Xss`参数减少**栈内存**的容量，异常发生时打印**栈**的深度。
- 定义大量的**本地局部变量**，以达到增大**栈帧**中的**本地变量表**的长度。

测试代码如下：

```java
/**************************************
 *      Author : zhangke
 *      Date   : 2019-03-23 16:29
 *      email  : 398757724@qq.com
 *      Desc   :  StackOverflowError
 *       -Xss128k
 ***************************************/
public class JavaVMStackSOF {
    private int stackLength = 1;

    private void stackLeak() {
        stackLength++;
        stackLeak();
    }

    public static void main(String[] args) {
        JavaVMStackSOF oom = new JavaVMStackSOF();
        try {
            oom.stackLeak();
        } catch (Throwable e) {
            System.out.println("Stack length: " + oom.stackLength);
            throw e;
        }
    }
}
```

测试结果：

```java
Stack length: 18506
Exception in thread "main" java.lang.StackOverflowError
	at OutOfMemory.JavaVMStackSOF.stackLeak(JavaVMStackSOF.java:15)
	at OutOfMemory.JavaVMStackSOF.stackLeak(JavaVMStackSOF.java:15)
	at OutOfMemory.JavaVMStackSOF.stackLeak(JavaVMStackSOF.java:15)
	at OutOfMemory.JavaVMStackSOF.stackLeak(JavaVMStackSOF.java:15)
	at OutOfMemory.JavaVMStackSOF.stackLeak(JavaVMStackSOF.java:15)
	at OutOfMemory.JavaVMStackSOF.stackLeak(JavaVMStackSOF.java:15)
	at OutOfMemory.JavaVMStackSOF.stackLeak(JavaVMStackSOF.java:15)
	at OutOfMemory.JavaVMStackSOF.stackLeak(JavaVMStackSOF.java:15)
	at OutOfMemory.JavaVMStackSOF.stackLeak(JavaVMStackSOF.java:15)
```

分析：在单个线程下，无论是**栈帧太大**还是**虚拟机栈容量太小**，当无法分配内存的时候，虚拟机抛出的都是`StackOverflowError`异常。

#### OutOfMemoryError异常

不停地创建**线程**并保持线程运行状态。测试代码如下

```java
/**
 * VM Args: -Xss2M
 */
public class JavaVMStackOOM {
    private void running() {
        while (true) {
        }
    }

    public void stackLeakByThread() {
        while (true) {
            new Thread(new Runnable() {
                @Override
                public void run() {
                    running();
                }
            }).start();
        }
    }

    public static void main(String[] args) {
        JavaVMStackOOM oom = new JavaVMStackOOM();
        oom.stackLeakByThread();
    }
}
```

**测试结果：**

```
Exception in thread "main" java.lang.OutOfMemoryError: unable to create new native thread
```

上述测试代码运行时存在较大的风险，可能会导致操作系统假死，这里就不亲自测试了，引用作者的测试结果。

### 方法区和运行时常量池溢出

#### 运行时常量池内存溢出测试

**运行时常量**和**字面量**都存放于**运行时常量池**中，常量池又是方法区的一部分，因此两个区域的测试是一样的。 这里采用`String.intern()`进行测试：

> String.intern()是一个native方法，它的作用是：如果字符串常量池中存在一个String对象的字符串，那么直接返回常量池中的这个String对象； 否则，将此String对象包含的字符串放入常量池中，并且返回这个String对象的引用。

设置`JVM`启动参数：通过`-XX:PermSize=10M`和`-XX:MaxPermSize=10M`限制**方法区**的大小为`10M`，从而间接的限制其中**常量池**的容量。测试代码如下：

```java
import java.util.ArrayList;
import java.util.List;

/**************************************
 *      Author : zhangke
 *      Date   : 2019-03-23 16:36
 *      email  : 398757724@qq.com
 *      Desc   : -XX:PermSize=10M -XX:MaxPermSize=10M
 ***************************************/
public class RuntimeConstantPoolOOM {
    public static void main(String[] args) {
        // 使用List保持着常量池的引用，避免Full GC回收常量池
        List<String> list = new ArrayList<>();
        // 10MB的PermSize在Integer范围内足够产生OOM了
        int i = 0;
        while (true) {
            list.add(String.valueOf(i++).intern());
        }
    }
}

```

我第一次在java8虚拟机上运行这份代码，抛出以下异常：

```
Java HotSpot(TM) 64-Bit Server VM warning: ignoring option PermSize=10M; support was removed in 8.0
Java HotSpot(TM) 64-Bit Server VM warning: ignoring option MaxPermSize=10M; support was removed in 8.0
```

这是因为java 8已经移除了永久代，所以上面俩个参数是没有用的。java8将运行时常量池放到堆中，所以我们转换下思路，设置堆的大小，就可以设置运行时常量池的大小,和上面一样，设置`JVM`启动参数：`-Xms20M`设置堆的**最小内存**为`20M`，`-Xmx20M`设置堆的**最大内存**和**最小内存**一样，这样可以防止`Java`堆在内存不足时**自动扩容**。 `-XX:+HeapDumpOnOutOfMemoryError`参数可以让虚拟机在出现内存溢出异常时`Dump`出**内存堆**运行时快照。

运行结果如下

```java
java.lang.OutOfMemoryError: GC overhead limit exceeded
Dumping heap to java_pid43631.hprof ...
Heap dump file created [25098878 bytes in 0.231 secs]
Exception in thread "main" java.lang.OutOfMemoryError: GC overhead limit exceeded
	at java.lang.Integer.toString(Integer.java:401)
	at java.lang.String.valueOf(String.java:3099)
	at OutOfMemory.RuntimeConstantPoolOOM.main(RuntimeConstantPoolOOM.java:19)
```

#### 方法去内存溢出测试

方法区存放`Class`相关的信息，比如**类名**、**访问修饰符**、**常量池**、**字段描述**、**方法描述**等。 对于**方法区的内存溢出**的测试，基本思路是在运行时产生大量**类字节码**区填充**方法区**。

这里引入`Spring`框架的`CGLib`动态代理的**字节码技术**，通过循环不断生成新的**代理类**，达到**方法区**内存溢出的效果。

JavaMethodAreaOOM.java

```java
/**
 * VM Args: -XX:PermSize=10M -XX:MaxPermSize=10M
 */
public class JavaMethodAreaOOM {

    public static void main(String[] args) {
        while (true) {
            Enhancer enhancer = new Enhancer();
            enhancer.setSuperclass(OOMObject.class);
            enhancer.setUseCache(false);
            enhancer.setCallback(new MethodInterceptor() {
                @Override
                public Object intercept(Object obj, Method method, Object[] args, MethodProxy proxy) throws Throwable {
                    return proxy.invokeSuper(obj, args);
                }
            });

            enhancer.create();
        }
    }

    private static class OOMObject {
        public OOMObject() {
        }
    }
}
复制代码
```

`JDK1.6`版本运行结果：

```
Exception in thread "main" java.lang.OutOfMemoryError: PermGen space
    at java.lang.ClassLoader.defineClass1(Native Method)
    at java.lang.ClassLoader.defineClassCond(ClassLoader.java:632)
    at java.lang.ClassLoader.defineClass(ClassLoader.java:616)
复制代码
```

测试结果分析：

`JDK1.6`版本运行结果显示**常量池**会溢出并抛出**永久带**的`OutOfMemoryError`异常。 而`JDK1.7`及以上的版本则不会得到相同的结果，它会一直循环下去。

### 直接内存溢出

本机**直接内存**的容量可通过`-XX:MaxDirectMemorySize`指定，如果不指定，则默认与`Java`堆**最大值**(-Xmx指定)一样。

**测试场景：**直接通过反射获取`Unsafe`实例，通过反射向操作系统申请分配内存：设置`JVM`启动参数：`-Xmx20M`指定`Java`堆的最大内存，`-XX:MaxDirectMemorySize=10M`指定**直接内存**的大小。

```java
/**
 * VM Args: -Xmx20M -XX:MaxDirectMemorySize=10M
 */
public class DirectMemoryOOM {

    private static final int _1MB = 1024 * 1024;

    public static void main(String[] args) throws Exception {
        Field unsafeField = Unsafe.class.getDeclaredFields()[0];
        unsafeField.setAccessible(true);
        Unsafe unsafe = (Unsafe) unsafeField.get(null);
        while (true) {
            unsafe.allocateMemory(_1MB);
        }
    }
}

```

这个是我从作者那复制过来，因为我本机一直没有报错，这个我还没搞懂。等搞懂了会来补上。

由`DirectMemory`导致的内存溢出，一个明显的特征是`Heap Dump`文件中不会看到明显的异常信息。 如果`OOM`发生后`Dump`文件很小，并且程序中直接或者间接地使用了`NIO`，那么就可以考虑一下这方面的问题。

## 总结

本篇文章只是简单的介绍了一下JVM的内存区域划分和每一部分的作用，接着介绍了常见的内存溢出异常。后面会单独写几篇文章来详细介绍上面的内容。

## 参考

1. [JVM系列(二) - JVM内存区域](https://juejin.im/post/5b4de8cbe51d455f5f4cd187#heading-16)