---
title: java线程系列 JUC锁 04 ReentrantLock 非公平锁
tags:
  - lock
categories:
  - java
  - juc
  - lock
abbrlink: b95fbd38
date: 2019-03-18 08:27:00
---

上一篇文章已经分析了公平锁的获取与释放，本篇文章在前文的基础上分析非公平锁的获取与释放。如果你看懂跑了前面公平锁的获取与释放主要流程，那么看懂本篇文章将会比较轻松。

<!--more-->

## 获取非公平锁

非公平锁和公平锁在获取锁的方法上，流程是一样的；它们的区别主要表现在“尝试获取锁的机制不同。简单点说，公平锁在每次尝试获取锁时，都是采用公平策略(根据等待队列依次排序等待)；而非公平锁在每次尝试获取锁时，都是采用的非公平策略(无视等待队列，直接尝试获取锁，如果锁是空闲的，即可获取状态，则获取锁)。
在前面的“[Java多线程系列--“JUC锁”03之 公平锁(一)](http://www.cnblogs.com/skywang12345/p/3496147.html)”中，已经详细介绍了获取公平锁的流程和机制；下面，通过代码分析以下获取非公平锁的流程。

### lock

lock()在ReentrantLock.java的NonfairSync类中实现，它的源码如下：

```java
final void lock() {
    if (compareAndSetState(0, 1))
        setExclusiveOwnerThread(Thread.currentThread());
    else
        acquire(1);
}
```

lock()会先通过compareAndSet(0, 1)来判断锁是不是空闲状态。是的话，当前线程直接获取锁；否则的话，调用acquire(1)获取锁,主要流程如下

1. 通过compareAndSetState()函数设置当前锁的状态。若锁的状态值为0，则设置锁的状态值为1。也就是获取锁成功。然后通过setExclusiveOwnerThread(Thread.currentThread())设置当前线程为锁的持有者。这样就获取锁成功。
2. 如果上面失败，则通过acquire(1)来获取锁

**公平锁和非公平锁关于lock()的对比**

* **公平锁**   -- 公平锁的lock()函数，会直接调用acquire(1)。
* **非公平锁** -- 非公平锁会先判断当前锁的状态是不是空闲，是的话，就不排队，而是直接获取锁。

### **acquire()**

acquire()在AQS中实现的，它的源码如下：

```java
public final void acquire(int arg) {
    if (!tryAcquire(arg) &&
        acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
        selfInterrupt();
}
```

1. 当前线程首先通过tryAcquire尝试获取锁，如果获取成功的话，直接返回，尝试失败，就要进入下一步。
2. 当前线程获取失败，通过addWaiter(Node.EXCLUSIVE)将当前线程插入到CLH队列末尾来等待获取锁。
3. 插入成功后，会使用acquireQueued来获取锁，这里获取锁只会等待当前等待节点的前继节点为head节点才会获取成功。没有获取锁，线程会进入休眠状态。如果当前线程在休眠等待过程中被打断，acquireQueue会返回true，此时当前线程会调用selfInterrupt来给自己产生一个中断。

**公平锁和非公平锁关于acquire()的对比**

公平锁和非公平锁，只有tryAcquire()函数的实现不同；即它们尝试获取锁的机制不同。这就是我们所说的它们获取锁策略的不同所在之处.在“[Java多线程系列--“JUC锁”03之 公平锁(一)](http://www.cnblogs.com/skywang12345/p/3496147.html)”中，已经详细介绍了acquire()涉及到的各个函数。这里仅对它们有差异的函数tryAcquire()进行说明。

### tryAcquire

非公平锁的tryAcquire()在ReentrantLock的NonfairSync类中实现，源码如下：

```java
protected final boolean tryAcquire(int acquires) {
    return nonfairTryAcquire(acquires);
}
```

nonfairTryAcquire()在ReentrantLock的Sync类中实现，源码如下：

```java
final boolean nonfairTryAcquire(int acquires) {
    // 获取“当前线程”
    final Thread current = Thread.currentThread();
    // 获取“锁”的状态
    int c = getState();
    // c=0意味着“锁没有被任何线程锁拥有”
    if (c == 0) {
        // 若“锁没有被任何线程锁拥有”，则通过CAS函数设置“锁”的状态为acquires。
        // 同时，设置“当前线程”为锁的持有者。
        if (compareAndSetState(0, acquires)) {
            setExclusiveOwnerThread(current);
            return true;
        }
    }
    else if (current == getExclusiveOwnerThread()) {
        // 如果“锁”的持有者已经是“当前线程”，
        // 则将更新锁的状态。
        int nextc = c + acquires;
        if (nextc < 0) // overflow
            throw new Error("Maximum lock count exceeded");
        setState(nextc);
        return true;
    }
    return false;
}
```

根据代码,tryAcquire()的作用就是尝试去获取锁。

1. 如果锁没有被任何线程拥有，则通过CAS函数设置锁的状态为已被获取状态，同时，设置当前线程为锁的持有者，然后返回true。
2. 如果锁的持有者已经是当前线程，则将更新锁的状态即可。
3. 如果不是上面的两种情况，则认为尝试获取锁失败。

**公平锁和非公平锁关于tryAcquire()的对比**

1. 公平锁在尝试获取锁时，即使锁没有被任何线程锁持有，它也会判断自己是不是CLH等待队列的表头；是的话，才获取锁。
2. 而非公平锁在尝试获取锁时，如果锁没有被任何线程持有，则不管它在CLH队列的何处，它都直接获取锁。

至于非公平锁的释放和公平锁是一样的，这里就不具体说明，下面主要分析ReentrantLock还剩下和获取锁有关的几个函数。

## lockInterruptibly、tryLock分析

### lockInterruptibly

这个函数和lock区别是，他响应中断，也就是当等待获取锁的线程在等待获取锁的时候收到中断信号，此方法会抛出中断异常。具体看西面源码

```java
public void lockInterruptibly() throws InterruptedException {
    sync.acquireInterruptibly(1);
}
// AQS
public final void acquireInterruptibly(int arg)
    throws InterruptedException {
     // 如果线程的中断标志为true，则抛出异常
    if (Thread.interrupted())
        throw new InterruptedException();
     // 尝试获取锁
    if (!tryAcquire(arg)) 
        // 获取锁
        doAcquireInterruptibly(arg);
}
```

从上面可以看出，主要的逻辑是在AQS中的acquireInterruptibly，至于参数1和前面的公平锁的参数一样，这里就不解释。下面看看上面的具体逻辑。

1. 判断线程是否被中断，如果被中断，抛出中断异常
2. 尝试获取锁，如果ReentrantLock使用的是公平锁，则使用的是公平锁的获取流程，否则是非公平锁的获取流程。获取成功，直接返回，失败则进入下一步。
3. 使用doAcquireInterruptibly获取锁。

#### doAcquireInterruptibly

获取锁的源码如下：

```java
private void doAcquireInterruptibly(int arg)
    throws InterruptedException {
    // 将当前线程加入等待队列
    final Node node = addWaiter(Node.EXCLUSIVE);
    boolean failed = true;
    try {
        for (;;) {
            // 获取前继节点
            final Node p = node.predecessor();
            // 如果是head并且是成功获取锁
            if (p == head && tryAcquire(arg)) {
                setHead(node);
                p.next = null; // help GC
                failed = false;
                return;
            }
            // 阻塞当前线程
            if (shouldParkAfterFailedAcquire(p, node) &&
                parkAndCheckInterrupt())
                // 如果中断抛出异常
                throw new InterruptedException();
        }
    } finally {
        if (failed)
            cancelAcquire(node);
    }
}
```

上面代码和**acquireQueued**方法的对比，唯一的区别就是：当调用线程获取锁失败，进入阻塞后，如果线程被中断，**acquireQueued**只是用一个标识记录线程被中断过，而**doAcquireInterruptibly**则是直接抛出异常。其他的是一样。具体可以看前面。

### tryLock

这个方法是尝试获取锁，成功则返回true，失败返回false。有俩个版本，一个是带有时间的等待，一个不带。下面看看俩者的区别。

首先来看看不带超时时间的tryLock，源码如下

#### tryLock

```java
public boolean tryLock() {
    return sync.nonfairTryAcquire(1);
}
```

从上面可以看出，不管当锁的类型是公平和非公平，都是使用nonfairTryAcquire来获取锁，在前面我们分析非公平锁的获取时已经分析了这部分的内容。这里就不具体讲解。

#### tryLock(long timeout, TimeUnit unit)

这个是带有等待时间的获取锁的版本，如果第一次尝试获取锁失败，则等待指定的时间，在此尝试获取锁，如果成功则返回true，失败返回false。

```java
public boolean tryLock(long timeout, TimeUnit unit)
    throws InterruptedException {
    return sync.tryAcquireNanos(1, unit.toNanos(timeout));
}

public final boolean tryAcquireNanos(int arg, long nanosTimeout)
    throws InterruptedException {
    if (Thread.interrupted())
        throw new InterruptedException();
    return tryAcquire(arg) ||
        doAcquireNanos(arg, nanosTimeout);
}
```

下面看看上面的具体流程

1. 判断当前线程是否被中断，如果中断抛出中断异常
2. 先通过tryAcquire尝试获取锁，如果成功，返回true，失败返回false。
3. 如果前面获取失败，通过doAcquireNanos来获取锁。

下面具体看看上面doAcquireNanos的流程，源码如下

```java
private boolean doAcquireNanos(int arg, long nanosTimeout)
    throws InterruptedException {
    // 等待时间为0，返回false
    if (nanosTimeout <= 0L)
        return false;
    // 获取等待的截止时间
    final long deadline = System.nanoTime() + nanosTimeout;
    // 将此节点放入等待队列
    final Node node = addWaiter(Node.EXCLUSIVE);
    boolean failed = true;
    try {
        for (;;) {
            // 获取前继节点
            final Node p = node.predecessor();
            // 当前节点获取锁成功，则返回
            if (p == head && tryAcquire(arg)) {
                setHead(node);
                p.next = null; // help GC
                failed = false;
                return true;
            }
            // 重新计算等待的时间
            nanosTimeout = deadline - System.nanoTime();
            // 如果小于0，则结束等待
            if (nanosTimeout <= 0L)
                return false;
            // 进入阻塞
            // spinForTimeoutThreshold=1000L
            if (shouldParkAfterFailedAcquire(p, node) &&
                nanosTimeout > spinForTimeoutThreshold)
                LockSupport.parkNanos(this, nanosTimeout);
            
            //线程被中断过，则抛出中断异常
            if (Thread.interrupted())
                throw new InterruptedException();
        }
    } finally {
        if (failed)
            cancelAcquire(node);
    }
}
```

上面流程还是比较清晰，下面总结上面的流程。

1. 判断等待的时间如果小于等于0，则直接返回false

2. 计算等待的截止时间，并将当前节点插入到等待队列中。

3. 进入循环

   1. 判断当前节点是否能成功获取锁，如果成功获取则返回true

   2. 计算等待的时间，如果小于0，返回失败

   3. shouldParkAfterFailedAcquire判断当前节点是否阻塞，如果返回false，进入新一轮的循环。

      如果是，则判断还需等待的时间是否小于spinForTimeoutThreshold，如果小于则不等待，进入自旋。这是一个优化，因为线程的切换需要时间，如果阻塞的时间非常短，则可以进入自旋，从而提升整体的性能。如果大于，则进入有限时间的阻塞。

   4. 判断线程是否中断过，如果是，则抛出中断异常

4. 进入finally，如果failed=true，则取消当前节点。



### 参考

1.  [Java多线程进阶（一）—— J.U.C并发包概述](https://segmentfault.com/a/1190000015558984)](https://segmentfault.com/a/1190000015804888)
2. [Java多线程系列目录(共43篇)](https://www.cnblogs.com/skywang12345/p/java_threads_category.html)
3.  [JAVA并发编程J.U.C学习总结](https://www.cnblogs.com/chenpi/p/5614290.html)