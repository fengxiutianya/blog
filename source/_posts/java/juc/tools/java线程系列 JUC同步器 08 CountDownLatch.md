---
title: java线程系列 JUC同步器 08 CountDownLatch
tags:
  - 同步器
categories:
  - java
  - juc
  - sync同步器
abbrlink: b071530c
date: 2019-03-19 10:34:00
---

正如每个Java文档所描述的那样，[CountDownLatch](http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/CountDownLatch.html)是一个同步工具类，它允许一个或多个线程一直等待，直到其他线程的操作执行完后再执行。在Java并发中，countdownlatch的概念是一个常见的面试题，所以一定要确保你很好的理解了它。

## CountDownLatch是什么

CountDownLatch是在java1.5被引入的，跟它一起被引入的并发工具类还有CyclicBarrier和Semaphore，它们都存在于java.util.concurrent包下，后面会讲解另外俩个。CountDownLatch这个类能够使一个线程等待其他线程完成各自的工作后再执行。例如，应用程序的主线程希望在负责启动框架服务的线程已经启动所有的框架服务之后再执行。

CountDownLatch是通过一个计数器来实现的，计数器的初始值为线程的数量。每当一个线程完成了自己的任务后，计数器的值就会减1。当计数器值到达0时，它表示所有的线程已经完成了任务，然后在闭锁上等待的线程就可以恢复执行任务。

![upload successful](/images/pasted-302.png)

如上图：TA主线程会一直等待，等待T1、T2和T3将计数器减为0，才继续执行。

<!-- more -->

## 例子

在这个例子中，我模拟了一个应用程序启动类，它开始时启动了n个线程类，这些线程将检查外部系统并通知闭锁，并且启动类一直在闭锁上等待着。一旦验证和检查了所有外部服务，那么启动类恢复执行。

**BaseHealthChecker.java：**这个类是一个Runnable，负责所有特定的外部服务健康的检测。它删除了重复的代码和闭锁的中心控制代码。

```java
package JUC.tools.CountDownLathDemo;

import java.util.concurrent.CountDownLatch;

/**************************************
 *      Author : zhangke
 *      Date   : 2019-03-19 20:02
 *      email  : 398757724@qq.com
 *      Desc   : 这个类是一个Runnable，负责所有特定的外部服务健康的检测。
 *               它删除了重复的代码和闭锁的中心控制代码。
 ***************************************/
public abstract class BaseHealthChecker implements Runnable {

    private CountDownLatch _latch;

    private String _serviceName;

    private boolean _serviceUp;


    public BaseHealthChecker(String serviceName, CountDownLatch latch) {
        super();
        this._latch = latch;
        this._serviceName = serviceName;
        this._serviceUp = false;
    }


    @Override
    public void run() {
        try {
            verifyService();
            _serviceUp = true;
        } catch (Throwable t) {
            t.printStackTrace(System.err);
            _serviceUp = false;
        } finally {
            if (_latch != null) {
                _latch.countDown();
            }
        }
    }


    public String getServiceName() {
        return _serviceName;
    }


    public boolean isServiceUp() {
        return _serviceUp;
    }


    //This methos needs to be implemented by all specific service checker
    public abstract void verifyService();
}

```

**NetworkHealthChecker.java：**这个类继承了BaseHealthChecker，实现了verifyService()方法。**DatabaseHealthChecker.java**和**CacheHealthChecker.java**除了服务名和休眠时间外，与NetworkHealthChecker.java是一样的。

```java
package JUC.tools.CountDownLathDemo;

import java.util.concurrent.CountDownLatch;

/**************************************
 *      Author : zhangke
 *      Date   : 2019-03-19 20:06
 *      email  : 398757724@qq.com
 *      Desc   : 
 ***************************************/
public class CacheHealthChecker extends BaseHealthChecker {

    public CacheHealthChecker(CountDownLatch latch) {
        super("CacheHealthChecker", latch);
    }


    @Override
    public void verifyService() {
        System.out.println("Checking " + this.getServiceName());
        try {
            Thread.sleep(7000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        System.out.println(this.getServiceName() + " is UP");
    }
}

```

**ApplicationStartupUtil.java：**这个类是一个主启动类，它负责初始化闭锁，然后等待，直到所有服务都被检测完。

```java
package JUC.tools.CountDownLathDemo;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

/**************************************
 *      Author : zhangke
 *      Date   : 2019-03-19 20:07
 *      email  : 398757724@qq.com
 *      Desc   : 应用启动类
 ***************************************/
public class ApplicationStartupUtil {

    public static void main(String[] args) {
        boolean result = false;
        try {
            result = ApplicationStartupUtil.checkExternalServices();
        } catch (Exception e) {
            e.printStackTrace();
        }
        System.out.println("External services validation completed !! Result was :: " + result);
    }


    private static List<BaseHealthChecker> _services;

    private static CountDownLatch _latch;


    private ApplicationStartupUtil() {
    }


    private final static ApplicationStartupUtil INSTANCE = new ApplicationStartupUtil();


    public static ApplicationStartupUtil getInstance() {
        return INSTANCE;
    }


    public static boolean checkExternalServices() throws Exception {

        _latch = new CountDownLatch(3);

        _services = new ArrayList<BaseHealthChecker>();
        _services.add(new NetworkHealthChecker(_latch));
        _services.add(new CacheHealthChecker(_latch));
        _services.add(new DatabaseHealthChecker(_latch));

        Executor executor = Executors.newFixedThreadPool(_services.size());

        for (final BaseHealthChecker v : _services) {
            executor.execute(v);
        }

        _latch.await();
        for (final BaseHealthChecker v : _services) {
            if (!v.isServiceUp()) {
                return false;
            }
        }
        return true;
    }
}

```

运行结果

```
Checking networkService
Checking CacheHealthChecker
Checking DatabaseHealth
networkService is UP
CacheHealthChecker is UP
DatabaseHealth is UP
External services validation completed !! Result was :: true
```



## 源码解析

CountDownLath的类图如下

![upload successful](/images/pasted-304.png)

CountDownLatch是通过共享锁实现的。下面，我们分析CountDownLatch中3个核心函数: CountDownLatch(int count), await(), countDown()。

首先看一下构造函数

```java
public CountDownLatch(int count) {
    if (count < 0) 
        throw new IllegalArgumentException("count < 0");
    this.sync = new Sync(count);
}
```

里面很简单，创建一个Sync对象，下面看看Sync类，这个类继承了AQS，源码如下

```java
private static final class Sync extends AbstractQueuedSynchronizer {
    private static final long serialVersionUID = 4982264981922014374L;

    
    Sync(int count) {
        // 设置状态值
        setState(count);
    }

    int getCount() {
        return getState();
    }

    // 获取共享锁
    protected int tryAcquireShared(int acquires) {
        return (getState() == 0) ? 1 : -1;
    }

    protected boolean tryReleaseShared(int releases) {
        // Decrement count; signal when transition to zero
        
        for (;;) {
            int c = getState();
            //如果已经为0，值之间返回说明已经释放完，不需要在释放
            if (c == 0)
                return false;
            // 状态值减1
            int nextc = c-1;
            //设置状态值，如果减小状态值之后，数字为0，则表示释放成功
            if (compareAndSetState(c, nextc))
                return nextc == 0;
        }
    }
}
```

### await

这个函数想当我我们前面的lock函数，只是这里换了个名称而已，源码如下

```java
public void await() throws InterruptedException {
    sync.acquireSharedInterruptibly(1);
}
public final void acquireSharedInterruptibly(int arg)
    throws InterruptedException {
    if (Thread.interrupted())
        throw new InterruptedException();
    // 尝试获取锁，如果成功直接返回
    if (tryAcquireShared(arg) < 0)
        // 获取锁失败，调用下面获取锁
        doAcquireSharedInterruptibly(arg);
}

```

从上面可以看出，这里await功能是通过获取共享锁来实现的。在我们构造CountDownLath对象的时候，闯进来一个state值，因此默认情况下，这里是获取到不到锁，从而使得线程进入阻塞状态。tryAcquireShared函数比较简单，这里就不仔细说这个函数，可以看上米娜Sync对象中的定义。下面看看doAcquireSharedInterruptibly这个函数，源码如下

```java
private void doAcquireSharedInterruptibly(int arg)
    throws InterruptedException {
    // 插入获取共享锁的节点
    final Node node = addWaiter(Node.SHARED);
    boolean failed = true;
    try {
        for (;;) {
            // 获取前继节点
            final Node p = node.predecessor();
            // 如果是头结点，尝试获取共享锁
            if (p == head) {
                // 大于0表示获取成功
                int r = tryAcquireShared(arg);
                // 获取成功唤醒后继节点，并返回
                if (r >= 0) {
                    // 设置头结点然后唤醒后继节点
                    setHeadAndPropagate(node, r);
                    p.next = null; // help GC
                    failed = false;
                    return;
                }
            }
            // 判断是否需要阻塞，并将节点插入到合适的位置，然后阻塞
            // 阻塞如果是被中断唤醒的，则抛出异常
            if (shouldParkAfterFailedAcquire(p, node) &&
                parkAndCheckInterrupt())
                throw new InterruptedException();
        }
    } finally {
        if (failed)
            cancelAcquire(node);
    }
}
```

上面流程还是比较简单，具体细节可以看上面的注释，主要的细节在前面的文章中已经解释过，下面重点解释一下setHeadAndPropagate这个函数。

源码如下：

```java
private void setHeadAndPropagate(Node node, int propagate) {
    // 记录头结点
    Node h = head; // Record old head for check below
    // 色红孩子当前节点为头结点
    setHead(node);

    // 有需要唤醒的后继节点，唤醒后继节点
    if (propagate > 0 || h == null || h.waitStatus < 0 ||
        (h = head) == null || h.waitStatus < 0) {
        Node s = node.next;
        // 如果是共享锁，则唤醒
        if (s == null || s.isShared())
            doReleaseShared();
    }
}
```

主要流程就是判断当前队列中是否有后续需要唤醒获取共享锁的节点，如果有则调用doReleaseShared唤醒。

```java
private void doReleaseShared() {
	
    for (;;) {
        Node h = head;
        // 等待队列不为空
        if (h != null && h != tail) {
            int ws = h.waitStatus;
            // 头结点的状态SIGNAL，则需要唤醒后继节点
            if (ws == Node.SIGNAL) {
                // 这只状态值，成功则执行后面唤醒后继节点的函数，否则继续循环知道成功
                if (!compareAndSetWaitStatus(h, Node.SIGNAL, 0))
                    continue;            // loop to recheck cases
                // 释放后继节点，则会改变头结点，也就是会退出这个逊汗
                unparkSuccessor(h);
            }
            //设置头结点为PROPAGATE状态，一直进行循环，知道头结点改变
            // 这样可以防止后继节点一直等待而不被唤醒
            
            else if (ws == 0 &&
                     !compareAndSetWaitStatus(h, 0, Node.PROPAGATE))
                continue;                // loop on failed CAS
        }
        // 头结点改变，退出循环
        if (h == head)                   // loop if head changed
            break;
    }
}

```

上面注释已经解释了整体的逻辑，这里重点解释`ws == 0 &&
!compareAndSetWaitStatus(h, 0, Node.PROPAGATE)`这个条件，通常情况下，如果头结点释放，那么会唤醒后继节点，但是出现这里的情况是因为队列里面只有当前节点，没有需要唤醒的节点，但是如果我们在改变当前节点状态过程中如果有后继节点计入阻塞队列，因为我们已经释放了此节点，会造成后继节点没有唤醒而造成阻塞。因此这里循环判断，直到有新的节点入队。而新节点入队，就会改变当前节点状态，从而使得循环结束。不过出现这种情况很少，因为共享锁获取的时候，入队的节点都会通过shouldParkAfterFailedAcquire将前继节点值设置成为SIGNAL。所以一般情况先，在循环的第一步就会结束。

### **countDown()**

```java
public void countDown() {
    sync.releaseShared(1);
}

public final boolean releaseShared(int arg) {
    if (tryReleaseShared(arg)) {
        doReleaseShared();
        return true;
    }
    return false;
}
```

该函数实际上调用releaseShared(1)释放共享锁，releaseShared()在AQS中实现。releaseShared()的目的是让当前线程释放它所持有的共享锁。它首先会通过tryReleaseShared()去尝试释放共享锁。尝试成功，则直接返回；尝试失败，则通过doReleaseShared()去释放共享锁，上面已经解释过这个函数。先买看看CountDownLath中实现的tryReleaseShared。源码如下：

```java
protected boolean tryReleaseShared(int releases) {
    // Decrement count; signal when transition to zero
    for (;;) {
        // 获取“锁计数器”的状态
        int c = getState();
        if (c == 0)
            return false;
        // “锁计数器”-1
        int nextc = c-1;
        // 通过CAS函数进行赋值。
        if (compareAndSetState(c, nextc))
            return nextc == 0;
    }
}
```

tryReleaseShared()的作用是释放共享锁，将锁计数器的值减1。

## 总结

CountDownLatch是通过共享锁实现的。在创建CountDownLatch中时，会传递一个int类型参数count，该参数是锁计数器的初始状态，表示该“享锁最多能被count给线程同时获取。当某线程调用该CountDownLatch对象的await()方法时，该线程会等待共享锁可用时，才能获取“共享锁进而继续运行。而共享锁可用的条件，就是锁计数器的值为0！而锁计数器的初始值为count，每当一个线程调用该CountDownLatch对象的countDown()方法时，才将锁计数器减1；通过这种方式，必须有count个线程调用countDown()之后，锁计数器才为0，而前面提到的等待线程才能继续运行！

## 参考

1. [Java多线程系列--“JUC锁”09之 CountDownLatch原理和示例](https://www.cnblogs.com/skywang12345/p/3533887.html)
2. [什么时候使用CountDownLatch](http://www.importnew.com/15731.html)