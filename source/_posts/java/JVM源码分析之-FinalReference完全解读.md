---
title: JVM源码分析之 FinalReference 完全解读
tags:
  - java
categories:
  - java
  - 引用
abbrlink: 53c15109
date: 2019-01-04 10:24:00
---
# JVM源码分析之 FinalReference完全解读

## 概述

Java对象引用体系除了强引用之外，出于对性能、可扩展性等方面考虑还特地实现了4种其他引用：`SoftReference`、`WeakReference`、`PhantomReference`、`FinalReference`，本文主要想讲的是`FinalReference`，因为当使用内存分析工具，比如zprofiler、mat等，分析一些oom的heap时，经常能看到 `java.lang.ref.Finalizer`占用的内存大小远远排在前面，而这个类占用的内存大小又和我们这次的主角`FinalReference`有着密不可分的关系。

`FinalReference`及关联的内容可能给我们留下如下印象：

- 自己代码里从没有使用过；
- 线程dump之后，会看到一个叫做`Finalizer`的Java线程；
- 偶尔能注意到`java.lang.ref.Finalizer`的存在；
- 在类里可能会写`finalize`方法。

那`FinalReference`到底存在的意义是什么，以怎样的形式和我们的代码相关联呢？这是本文要理清的问题。
<!-- more -->

## JDK中的FinalReference

首先我们看看`FinalReference`在JDK里的实现：

```
class FinalReference&lt;T&gt; extends Reference&lt;T&gt; {

    public FinalReference(T referent, ReferenceQueue&lt;? super T&gt; q) {
        super(referent, q);
    }

}
```

大家应该注意到了类访问权限是package的，这也就意味着我们不能直接去对其进行扩展，但是JDK里对此类进行了扩展实现`java.lang.ref.Finalizer`，这个类在概述里提到的过，而此类的访问权限也是package的，并且是final的，意味着它不能再被扩展了，接下来的重点我们围绕`java.lang.ref.Finalizer`展开。(PS：后续讲的`Finalizer`其实也是在说`FinalReference`。)

```
final class Finalizer extends FinalReference { 
   /* Package-private; must be in same package as the 
   Referenceclass */
   
   /* A native method that invokes an arbitrary object's  
   finalize method is  required since the finalize method is 
   protected*/
    static native void invokeFinalizeMethod(Object o) throws Throwable;

    private static ReferenceQueue queue = new ReferenceQueue();
    private static Finalizer unfinalized = null;
    private static final Object lock = new Object();

    private Finalizer
        next = null,
        prev = null;

    private Finalizer(Object finalizee) {
        super(finalizee, queue);
        add();
    }

    /* Invoked by VM */
    static void register(Object finalizee) {
        new Finalizer(finalizee);
    }  

    private void add() {
        synchronized (lock) {
            if (unfinalized != null) {
                this.next = unfinalized;
                unfinalized.prev = this;
            }
            unfinalized = this;
        }
    }

    ...

   }    
```

### Finalizer的构造函数

`Finalizer`的构造函数提供了以下几个关键信息：

- `private`：意味着我们无法在当前类之外构建这类的对象；
- `finalizee`参数：`FinalReference`指向的对象引用；
- 调用`add`方法：将当前对象插入到`Finalizer`对象链里，链里的对象和`Finalizer`类静态关联。言外之意是在这个链里的对象都无法被GC掉，除非将这种引用关系剥离（因为`Finalizer`类无法被unload）。

虽然外面无法创建`Finalizer`对象，但是它有一个名为`register`的静态方法，该方法可以创建这种对象，同时将这个对象加入到`Finalizer`对象链里，这个方法是被vm调用的，那么问题来了，vm在什么情况下会调用这个方法呢？

## Finalizer对象何时被注册到Finalizer对象链里

类的修饰有很多，比如final，abstract，public等，如果某个类用final修饰，我们就说这个类是final类，上面列的都是语法层面我们可以显式指定的，在JVM里其实还会给类标记一些其他符号，比如`finalizer`，表示这个类是一个`finalizer`类（为了和`java.lang.ref.Fianlizer`类区分，下文在提到的`finalizer`类时会简称为f类），GC在处理这种类的对象时要做一些特殊的处理，如在这个对象被回收之前会调用它的`finalize`方法。

#### 如何判断一个类是不是一个final类

在讲这个问题之前，我们先来看下`java.lang.Object`里的一个方法

```
    protected void finalize() throws Throwable { }
```

在`Object`类里定义了一个名为`finalize`的空方法，这意味着Java里的所有类都会继承这个方法，甚至可以覆写该方法，并且根据方法覆写原则，如果子类覆盖此方法，方法访问权限至少protected级别的，这样其子类就算没有覆写此方法也会继承此方法。

而判断当前类是否是f类的标准并不仅仅是当前类是否含有一个参数为空，返回值为void的`finalize`方法，还要求`finalize方法必须非空`，因此Object类虽然含有一个`finalize`方法，但它并不是f类，Object的对象在被GC回收时其实并不会调用它的`finalize`方法。

需要注意的是，类在加载过程中其实就已经被标记为是否为f类了。（JVM在类加载的时候会遍历当前类的所有方法，包括父类的方法，只要有一个参数为空且返回void的非空`finalize`方法就认为这个类是f类。）

### f类的对象何时传到Finalizer.register方法

对象的创建其实是被拆分成多个步骤的，比如`A a=new A(2)`这样一条语句对应的字节码如下：

```
0: new           #1                  // class A
3: dup
4: iconst_2
5: invokespecial #11                 // Method "&lt;init&gt;":(I)V
```

先执行new分配好对象空间，然后再执行invokespecial调用构造函数，JVM里其实可以让用户在这两个时机中选择一个，将当前对象传递给`Finalizer.register`方法来注册到`Finalizer`对象链里，这个选择取决于是否设置了`RegisterFinalizersAtInit`这个vm参数，默认值为true，也就是在构造函数返回之前调用`Finalizer.register`方法，如果通过`-XX:-RegisterFinalizersAtInit`关闭了该参数，那将在对象空间分配好之后将这个对象注册进去。

另外需要提醒的是，当我们通过clone的方式复制一个对象时，如果当前类是一个f类，那么在clone完成时将调用`Finalizer.register`方法进行注册。

### hotspot如何实现f类对象在构造函数执行完毕后调用Finalizer.register

这个实现比较有意思，在这简单提一下，我们知道执行一个构造函数时，会去调用父类的构造函数，主要是为了初始化继承自父类的属性，那么任何一个对象的初始化最终都会调用到`Object`的空构造函数里（任何空的构造函数其实并不空，会含有三条字节码指令，如下代码所示），为了不对所有类的构造函数都埋点调用`Finalizer.register`方法，hotspot的实现是，在初始化`Object`类时将构造函数里的`return`指令替换为`_return_register_finalizer`指令，该指令并不是标准的字节码指令，是hotspot扩展的指令，这样在处理该指令时调用`Finalizer.register`方法，以很小的侵入性代价完美地解决了这个问题。

```
0: aload_0
1: invokespecial #21                 // Method java/lang/Object."&lt;init&gt;":()V
4: return
```

## f类对象的GC回收

### FinalizerThread线程

在`Finalizer`类的`clinit`方法（静态块）里，我们看到它会创建一个`FinalizerThread`守护线程，这个线程的优先级并不是最高的，意味着在CPU很紧张的情况下其被调度的优先级可能会受到影响

```
  private static class FinalizerThread extends Thread {
        private volatile boolean running;
        FinalizerThread(ThreadGroup g) {
            super(g, "Finalizer");
        }
        public void run() {
            if (running)
                return;
            running = true;
            for (;;) {
                try {
                    Finalizer f = (Finalizer)queue.remove();
                    f.runFinalizer();
                } catch (InterruptedException x) {
                    continue;
                }
            }
        }
    }

    static {
        ThreadGroup tg = Thread.currentThread().getThreadGroup();
        for (ThreadGroup tgn = tg;
             tgn != null;
             tg = tgn, tgn = tg.getParent());
        Thread finalizer = new FinalizerThread(tg);
        finalizer.setPriority(Thread.MAX_PRIORITY - 2);
        finalizer.setDaemon(true);
        finalizer.start();
    }
```

这个线程用来从queue里获取`Finalizer`对象，然后执行该对象的`runFinalizer`方法，该方法会将`Finalizer`对象从`Finalizer`对象链里剥离出来，这样意味着下次GC发生时就可以将其关联的f对象回收了，最后将这个`Finalizer`对象关联的f对象传给一个native方法`invokeFinalizeMethod`

```
private void runFinalizer() {
        synchronized (this) {
            if (hasBeenFinalized()) return;
            remove();
        }
        try {
            Object finalizee = this.get();
            if (finalizee != null && !(finalizee instanceof java.lang.Enum)) {
                invokeFinalizeMethod(finalizee);
                /* Clear stack slot containing this variable, to decrease
                   the chances of false retention with a conservative GC */
                finalizee = null;
            }
        } catch (Throwable x) { }
        super.clear();
    }

 static native void invokeFinalizeMethod(Object o) throws Throwable;
```

其实`invokeFinalizeMethod`方法就是调了这个f对象的finalize方法，看到这里大家应该恍然大悟了，整个过程都串起来了。

```
JNIEXPORT void JNICALL
Java_java_lang_ref_Finalizer_invokeFinalizeMethod(JNIEnv *env, jclass clazz,
                                                  jobject ob)
{
    jclass cls;
    jmethodID mid;

    cls = (*env)-&gt;GetObjectClass(env, ob);
    if (cls == NULL) return;
    mid = (*env)-&gt;GetMethodID(env, cls, "finalize", "()V");
    if (mid == NULL) return;
    (*env)-&gt;CallVoidMethod(env, ob, mid);
}
```

### f对象的finalize方法抛出异常会导致FinalizeThread退出吗

不知道大家有没有想过如果f对象的`finalize`方法抛了一个没捕获的异常，这个`FinalizerThread`会不会退出呢，细心的读者看上面的代码其实就可以找到答案，`runFinalizer`方法里对`Throwable`的异常进行了捕获，因此不可能出现`FinalizerThread`因异常未捕获而退出的情况。

### f对象的finalize方法会执行多次吗

如果我们在f对象的`finalize`方法里重新将当前对象赋值，变成可达对象，当这个f对象再次变成不可达时还会执行`finalize`方法吗？答案是否定的，因为在执行完第一次`finalize`方法后，这个f对象已经和之前的`Finalizer`对象剥离了，也就是下次GC的时候不会再发现`Finalizer`对象指向该f对象了，自然也就不会调用这个f对象的`finalize`方法了。

### Finalizer对象何时被放到ReferenceQueue里

除了这里接下来要介绍的环节之外，整个过程大家应该都比较清楚了。

当GC发生时，GC算法会判断f类对象是不是只被`Finalizer`类引用（f类对象被`Finalizer`对象引用，然后放到`Finalizer`对象链里），如果这个类仅仅被`Finalizer`对象引用，说明这个对象在不久的将来会被回收，现在可以执行它的`finalize`方法了，于是会将这个`Finalizer`对象放到`Finalizer`类的`ReferenceQueue`里，但是这个f类对象其实并没有被回收，因为`Finalizer`这个类还对它们保持引用，在GC完成之前，JVM会调用`ReferenceQueue`中lock对象的notify方法（当`ReferenceQueue`为空时，`FinalizerThread`线程会调用`ReferenceQueue`的lock对象的wait方法直到被JVM唤醒），此时就会执行上面FinalizeThread线程里看到的其他逻辑了。

## Finalizer导致的内存泄露

这里举一个简单的例子，我们使用挺广的Socket通信，`SocksSocketImpl`的父类其实就实现了`finalize`方法:

```
/**
 * Cleans up if the user forgets to close it.
 */
protected void finalize() throws IOException {
    close();
}
```

其实这么做的主要目的是万一用户忘记关闭Socket，那么在这个对象被回收时能主动关闭Socket来释放一些系统资源，但是如果用户真的忘记关闭，那这些`socket`对象可能因为`FinalizeThread`迟迟没有执行这些`socket`对象的`finalize`方法，而导致内存泄露，这种问题我们碰到过多次，因此对于这类情况除了大家好好注意貌似没有什么更好的方法了，该做的事真不能省.

## Finalizer的客观评价

上面的过程基本对`Finalizer`的实现细节进行了完整剖析，Java里我们看到有构造函数，但是并没有看到析构函数一说，`Finalizer`其实是实现了析构函数的概念，我们在对象被回收前可以执行一些“收拾性”的逻辑，应该说是一个特殊场景的补充，但是这种概念的实现给f对象生命周期以及GC等带来了一些影响：

- f对象因为`Finalizer`的引用而变成了一个临时的强引用，即使没有其他的强引用，还是无法立即被回收；
- f对象至少经历两次GC才能被回收，因为只有在`FinalizerThread`执行完了f对象的`finalize`方法的情况下才有可能被下次GC回收，而有可能期间已经经历过多次GC了，但是一直还没执行f对象的`finalize`方法；
- CPU资源比较稀缺的情况下`FinalizerThread`线程有可能因为优先级比较低而延迟执行f对象的`finalize`方法；
- 因为f对象的`finalize`方法迟迟没有执行，有可能会导致大部分f对象进入到old分代，此时容易引发old分代的GC，甚至Full GC，GC暂停时间明显变长；
- f对象的`finalize`方法被调用后，这个对象其实还并没有被回收，虽然可能在不久的将来会被回收。

## 参考
1. [JVM 源码分析之 FinalReference 完全解读](https://www.infoq.cn/articles/jvm-source-code-analysis-finalreference)