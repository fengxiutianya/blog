---
title: java线程系列 JUC同步器 10 Semaphore
tags:
  - 同步器
categories:
  - java
  - juc
  - tools
abbrlink: '2313243'
date: 2019-03-20 14:51:38
---
从字面意思理解就是信号量，本质上来说是用于线程之间访问共享资源，是一种同步原语，只是访问的资源可能有多个，其实现是通过AQS框架。在我们开发中，经常会碰见使用信号量的场景，比如出于系统性能的考虑需要限流，这时需要控制同时访问共享资源的最大线程数量，或者共享资源是稀缺资源，我们需要有一种办法能够协调各个线程，以保证合理的使用公共资源。
可以看下图来理解
![upload successful](/images/pasted-309.png)
有四个线程来共同竞争资源，现在信号量是5，则表明共享资源的数量是5。如果每个线程申请一个资源，则可以同时满足5个线程申请资源，每个线程在使用完之后，需要释放资源。如果在线程在申请资源的时候，没有足够的资源来满足，则会阻塞线程。
<!-- more  -->
## 示例

```java
package JUC.tools;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Semaphore;

/**************************************
 *      Author : zhangke
 *      Date   : 2018/4/20 20:00
 *      Desc   : Semaphore 学习
 ***************************************/
public class SemaphoreTest1 {

    public static void main(String[] args) {
        Semaphore sem = new Semaphore(10);
        ExecutorService threadPool = Executors.newFixedThreadPool(3);

        //在线程池中执行任务
        threadPool.execute(new MyThread(sem, 5));
        threadPool.execute(new MyThread(sem, 4));
        threadPool.execute(new MyThread(sem, 7));

        //关闭池
        threadPool.shutdown();
    }


    static class MyThread extends Thread {
        private Semaphore sem;   //信号量
        private int count;   //申请信号量的大小


        public MyThread(Semaphore sem, int count) {
            this.sem = sem;
            this.count = count;
        }


        @Override
        public void run() {

            try {
                //从信号量中获取count个许可
                sem.acquire(count);
                Thread.sleep(2000);
                System.out.println(Thread.currentThread().getName() 
                                   + " acquire count=" + count);
            } catch (InterruptedException e) {
                e.printStackTrace();
            } finally {
                // 释放给定数目的许可，将其返回到信号量。
                sem.release(count);
                System.out.println(Thread.currentThread().getName() 
                                   + " release " + count + "");
            }
        }
    }
}

```

上面演示了基本的信号量使用机制，当有线程尝试使用共享资源时，我们要求线程先获得许可（调用**Semaphore** 的**acquire**方法），这样线程就拥有了权限，否则就需要等待。当使用完资源后，线程需要调用**Semaphore** 的**release**方法释放许可。

运行结果如下

```
pool-1-thread-2 acquire count=4
pool-1-thread-1 acquire count=5
pool-1-thread-1 release 5
pool-1-thread-2 release 4
pool-1-thread-3 acquire count=7
pool-1-thread-3 release 7
```

从结果可以看出，这有点类似于共享锁，锁的获取可以不用等待锁的释放。但必须满足下面的条件**许可数 ≤ 0代表共享资源不可用。许可数 ＞ 0，代表共享资源可用，且多个线程可以同时访问共享资源。**

## 源码分析

类图如下：

![upload successful](/images/pasted-308.png)

1.  Semaphore也包含sync对象，sync是Sync类型；而且，Sync是一个继承于AQS的抽象类。
2. Sync包括两个子类："公平信号量"FairSync 和 "非公平信号量"NonfairSync。sync是"FairSync的实例"，或者"NonfairSync的实例"；默认情况下，sync是NonfairSync(即，默认是非公平信号量)。

### 构造函数

```java
public Semaphore(int permits) {
    sync = new NonfairSync(permits);
}

public Semaphore(int permits, boolean fair) {
    sync = fair ? new FairSync(permits) : new NonfairSync(permits);
}
```

从中，我们可以信号量分为公平信号量(FairSync)和非公平信号量(NonfairSync)。Semaphore(int permits)函数会默认创建非公平信号量。permits表示许可数，可以理解为资源可以被共享的数量。

### 公平信号量的获取

获取信号量的源码如下：

```java
public void acquire() throws InterruptedException {
    sync.acquireSharedInterruptibly(1);
}

public void acquire(int permits) throws InterruptedException {
    if (permits < 0) 
        throw new IllegalArgumentException();
    sync.acquireSharedInterruptibly(permits);
}
```

从上面可以看出，内部是同过Sync对象的acquireSharedInterruptibly方法来获取，源码如下

```java
public final void acquireSharedInterruptibly(int arg)
    throws InterruptedException {
    // 如果线程是中断状态，则抛出异常。
    if (Thread.interrupted())
        throw new InterruptedException();
    // 否则，尝试获取“共享锁”；获取成功则直接返回，
    // 获取失败，则通过doAcquireSharedInterruptibly()获取。
    if (tryAcquireShared(arg) < 0)
        doAcquireSharedInterruptibly(arg);
}
```

tryAcquireShared对应公平锁的源码如下

```java
protected int tryAcquireShared(int acquires) {
    for (;;) {
        // 判断当前线程是不是CLH队列中的第一个线程线程，
        // 若是的话，则返回-1。
        if (hasQueuedPredecessors())
            return -1;
        // 设置可以获得的信号量的许可数
        int available = getState();
        // 设置获得acquires个信号量许可之后，剩余的信号量许可数
        int remaining = available - acquires;
        // 如果剩余的信号量许可数>=0，则设置可以获得的信号量许可数为remaining。
        // 设置成功则返回remaining
        if (remaining < 0 ||
            compareAndSetState(available, remaining))
            return remaining;
    }
}
```

tryAcquireShared()的作用是尝试获取acquires个信号量许可数。对于Semaphore而言，state表示的是当前可获得的信号量许可数。

下面看看AQS中doAcquireSharedInterruptibly的实现

```java
private void doAcquireSharedInterruptibly(long arg)
    throws InterruptedException {
    // 创建当前线程的Node节点，且Node中记录的锁是共享锁类型；
    // 并将该节点添加到CLH队列末尾。
    final Node node = addWaiter(Node.SHARED);
    boolean failed = true;
    try {
        for (;;) {
            // 获取上一个节点。
            // 如果上一节点是CLH队列的表头，则”尝试获取共享锁“。
            final Node p = node.predecessor();
            if (p == head) {
                long r = tryAcquireShared(arg);
                if (r >= 0) {
                    setHeadAndPropagate(node, r);
                    p.next = null; // help GC
                    failed = false;
                    return;
                }
            }
            // 当前线程一直等待，直到获取到共享锁。
            // 如果线程在等待过程中被中断过，则再次中断该线程(还原之前的中断状态)。
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
doAcquireSharedInterruptibly()会使当前线程一直等待，直到当前线程获取到共享锁(或被中断)才返回。主要流程如下：
1.  addWaiter(Node.SHARED)的作用是，创建当前线程的Node节点，且Node中记录的锁的类型是共享锁(Node.SHARED)；并将该节点添加到CLH队列末尾。
2.  node.predecessor()的作用是，获取上一个节点。如果上一节点是CLH队列的表头，则尝试获取共享锁。
3. shouldParkAfterFailedAcquire()的作用和它的名称一样，如果在尝试获取锁失败之后，线程应该等待，则返回true；否则，返回false。当shouldParkAfterFailedAcquire()返回ture时，则调用parkAndCheckInterrupt()，当前线程会进入等待状态，直到获取到共享锁才继续运行。如果检测到时中断导致的返回，则抛出异常。

上面的函数在前面几篇文章中都已经介绍过，这里就不在重复讲，如果不理解可以看这几篇文章[JUC 锁介绍](/categories/java/juc/lock)
### 公平信号量的释放
``` java
public void release() {
    sync.releaseShared(1);
}
public void release(int permits) {
    if (permits < 0) 
    throw new IllegalArgumentException();
    sync.releaseShared(permits);
}
```
信号量的释放是通过releases()释放函数，实际上调用的AQS中的releaseShared()
``` java
public final boolean releaseShared(int arg) {
    if (tryReleaseShared(arg)) {
        doReleaseShared();
        return true;
    }
    return false;
}
```
releaseShared()的目的是让当前线程释放它所持有的共享锁。它首先会通过tryReleaseShared()去尝试释放共享锁。尝试成功，则直接返回；尝试失败，则通过doReleaseShared()去释放共享锁。
Semaphore重写了tryReleaseShared()，它的源码如下：
```java
protected final boolean tryReleaseShared(int releases) {
    for (;;) {
        // 获取“可以获得的信号量的许可数”
        int current = getState();
        // 获取“释放releases个信号量许可之后，剩余的信号量许可数”
        int next = current + releases;
        if (next < current) // overflow
            throw new Error("Maximum permit count exceeded");
        // 设置“可以获得的信号量的许可数”为next。
        if (compareAndSetState(current, next))
            return true;
    }
}
```
如果tryReleaseShared()尝试释放共享锁失败，则会调用doReleaseShared()去释放共享锁。doReleaseShared()的源码如下：
``` java
private void doReleaseShared() {
    for (;;) {
        // 获取CLH队列的头节点
        Node h = head;
        // 如果头节点不为null，并且头节点不等于tail节点。
        if (h != null && h != tail) {
            // 获取头节点对应的线程的状态
            int ws = h.waitStatus;
            // 如果头节点对应的线程是SIGNAL状态，则意味着“头节点的下一个节点所对应的线程”需要被unpark唤醒。
            if (ws == Node.SIGNAL) {
                // 设置“头节点对应的线程状态”为空状态。失败的话，则继续循环。
                if (!compareAndSetWaitStatus(h, Node.SIGNAL, 0))
                    continue;
                // 唤醒“头节点的下一个节点所对应的线程”。
                unparkSuccessor(h);
            }
            // 如果头节点对应的线程是空状态，则设置“节点对应的线程所拥有的共享锁”为其它线程获取锁的空状态。
            else if (ws == 0 &&
                     !compareAndSetWaitStatus(h, 0, Node.PROPAGATE))
                continue;                // loop on failed CAS
        }
        // 如果头节点发生变化，则继续循环。否则，退出循环。
        if (h == head)                   // loop if head changed
            break;
    }
}
```
doReleaseShared()会释放共享锁。它会从前往后的遍历CLH队列，依次唤醒然后执行队列中每个节点对应的线程；最终的目的是让这些线程释放它们所持有的信号量。
## 非公平信号量获取和释放
Semaphore中的非公平信号量是NonFairSync。在Semaphore中，非公平信号量许可的释放(release)与公平信号量许可的释放(release)是一样的。
不同的是它们获取信号量许可的机制不同，下面是非公平信号量获取信号量许可的代码。

非公平信号量的tryAcquireShared()实现如下：
```java

protected int tryAcquireShared(int acquires) {
    return nonfairTryAcquireShared(acquires);
}
```
nonfairTryAcquireShared()的实现如下：
```java
final int nonfairTryAcquireShared(int acquires) {
    for (;;) {
        // 设置“可以获得的信号量的许可数”
        int available = getState();
        // 设置“获得acquires个信号量许可之后，剩余的信号量许可数”
        int remaining = available - acquires;
        // 如果“剩余的信号量许可数>=0”，则设置“可以获得的信号量许可数”为remaining。
        if (remaining < 0 ||
            compareAndSetState(available, remaining))
            return remaining;
    }
}
```
非公平信号量的tryAcquireShared()调用AQS中的nonfairTryAcquireShared()。而在nonfairTryAcquireShared()的for循环中，它都会直接判断当前剩余的信号量许可数是否足够；足够的话，则直接设置可以获得的信号量许可数，进而再获取信号量。
而公平信号量的tryAcquireShared()中，在获取信号量之前会通过if (hasQueuedPredecessors())来判断当前线程是不是在CLH队列的头部，是的话，则返回-1。 
## 总结
Semaphore其实就是实现了AQS共享功能的同步器，对于Semaphore来说，资源就是许可证的数量：
* 剩余许可证数（State值） - 尝试获取的许可数（acquire方法入参） ≥ 0：资源可用
* 剩余许可证数（State值） - 尝试获取的许可数（acquire方法入参） < 0：资源不可用
这里共享的含义是多个线程可以同时获取资源，当计算出的剩余资源不足时，线程就会阻塞。
注意：Semaphore不是锁，只能限制同时访问资源的线程数，至于对数据一致性的控制，Semaphore是不关心的。当前，如果是只有一个许可的Semaphore，可以当作锁使用。