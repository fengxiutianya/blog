---
title: java线程系列 JUC锁 07 ReentrantReadWriteLock
tags:
  - ReentrantReadWriteLock
categories:
  - java
  - juc
  - lock
abbrlink: 18178dca
date: 2019-03-19 03:46:00
---

## ReentrantReadWriteLock 简介

在前面我们已经分析过JUC中的独占锁：ReentrantLock。本篇文章将对JUC的读写锁ReentrantReadWriteLock进行介绍。

类如如下：

![upload successful](/images/pasted-300.png)

从上图可以看出ReentrantReadWriteLock实现了ReadWriteLock接口，而这个接口从名字就可以看出是读写锁。它维护了一对相关连的锁：读锁和写锁。作用如下

* 读锁：用于只读操作，不会修改共享数据。是共享锁，能够同时被多个线程锁获取。
* 写锁：用于写入操作，是独占锁，只能被一个线程锁获取。

而这个接口提供了俩个抽象函数，获取读锁的readLock()函数和获取写锁的writeLock()函数。

ReentrantReadWriteLock中包含：Sync对象，读锁ReadLock和写锁WriteLock。

读锁ReadLock和写锁WriteLock都实现了Lock接口。读锁ReadLock和写锁WriteLock中也都分别包含了相同的Sync对象，里面所有的功能实现也都是靠这个对象。它们的Sync对象和ReentrantReadWriteLock的Sync对象是一样，就是通过sync，读锁和写锁实现了对同一个对象的访问。

和ReentrantLock一样，Sync也是一个继承于AQS的抽象类。Sync也包括公平锁FairSync和非公平锁NonfairSync。在创建读写锁时可以选择其中俩个其中一个，默认是NonfairSync。

### 公平读写锁源码分析

这里我们先对公平锁方式实现的读写锁进行源码分析，首先把后面要用到的属性在这里写出来，方便后买源码的理解：

```java
// 内部使用的读锁
private final ReentrantReadWriteLock.ReadLock readerLock;
// 内部使用的写锁
private final ReentrantReadWriteLock.WriteLock writerLock;
// 读锁和写锁共同使用的锁类型，可以是公平锁和非公平锁
final Sync sync;

```

这里先看看构造函数和如何获取读锁和写锁

```java
public ReentrantReadWriteLock(boolean fair) {
    sync = fair ? new FairSync() : new NonfairSync();
    readerLock = new ReadLock(this);
    writerLock = new WriteLock(this);
}

public ReentrantReadWriteLock.WriteLock writeLock() { return writerLock; }
public ReentrantReadWriteLock.ReadLock  readLock()  { return readerLock; }
```

从上面可以看出，在创建ReentrantReadWriteLock对象时就会根据是否选择公平锁来创建一个sync锁对象。然后分别创建响应的读锁和写锁。后面获取和使用的读写锁都是在构造函数中创建出来的。

下面开始首先对读锁的获取和释放进行分析。

### 读锁的获取（公平锁篇）

读锁也就是共享锁，获取锁的源码如下：

```java
// ReadLock 类中
public void lock() {
    // 获取共享锁
    sync.acquireShared(1);
}

//AQS 类中
public final void acquireShared(int arg) {
    if (tryAcquireShared(arg) < 0)
        doAcquireShared(arg);
}
```

从上面可以看出，这里调用的是AQS类中的acquireShared来获取锁。参数和ReentrantLock一样，表示获取锁的数量，1表示当前获取一把共享锁。锁的状态也会加1.

acquireShared()首先会通过tryAcquireShared()来尝试获取锁。尝试成功的话，直接返回。尝试失败的话，则通过doAcquireShared()来获取锁。doAcquireShared()会获取到锁才返回。

#### tryAcquireShared

尝试获取共享锁，此函数定义在Sync类中，源码如下

```java
protected final int tryAcquireShared(int unused) {

    Thread current = Thread.currentThread();
    // 获取锁的状态
    int c = getState();
    // 如果锁被独占锁获取并且获取独占锁的线程不是当前线程，
    // 直接返回-1 达标获取锁失败
    if (exclusiveCount(c) != 0 &&
        getExclusiveOwnerThread() != current)
        return -1;
    // 获取读锁的共享计数
    int r = sharedCount(c);
    // 判断不需要阻塞，并且已经获取读锁的数量小于MAX_COUNT
    // 则通过CAS函数更新读锁的状态，将读锁的共享计数加1
    if (!readerShouldBlock() &&
        r < MAX_COUNT &&
        compareAndSetState(c, c + SHARED_UNIT)) {
        // 第一次获取读锁
        if (r == 0) {
            firstReader = current;
            firstReaderHoldCount = 1;
          
        } else if (firstReader == current) {
              // 如果当前获取锁的线程是第一个获取读锁的线程
            firstReaderHoldCount++;
        } else {
            // HoldCounter是用来统计该线程获取“读取锁”的次数。
            HoldCounter rh = cachedHoldCounter;
            if (rh == null || rh.tid != getThreadId(current))
                cachedHoldCounter = rh = readHolds.get();
            else if (rh.count == 0)
                readHolds.set(rh);
             // 将该线程获取“读取锁”的次数+1。
            rh.count++;
        }
        return 1;
    }
    // 如果获取读锁失败，则通过下面函数来进行获取读锁
    return fullTryAcquireShared(current);
}
```

上面流程比较清晰，但是有很多地点你可能看不明白，先跳过，看完后面所有的分析，你就会明白。先总结上面的流程。

1. 判断当前锁是否是独占锁，如果是并且独占锁的线程和当前获取锁的线程不相同，则直接返回-1，获取读锁失败。
2. 如果当前线程不应该被阻塞，并且已获取读锁的数量小于最大值，则尝试使用CAS更改读锁的状态值。如果操作成功，进行下一步，操作失败进入最后一步。
3. 这一步主要设置每一个线程获取读锁的数量，主要分为三类来讨论：
   1. 如果是第一个线程来获取读锁，则设置firstReader为当前线程和当前线程拥有的读锁数量为1.
   2. 如果不是，则判断当前线程和firstReader线程是否一样，如果一样，则当前线程获取读锁的数量加1
   3. 以上都不是，则通过HoldCounter来对当前线程获取读锁的数量加1，而HoldCounter是一个ThreadLocal对象。保证每个线程都有一个不一样的HoldCounter变量。下面会详细解释
4. 如果上面没有成功获取到读锁，但也没有返回。则通过fullTryAcquireShared来获取锁

下面对上面每一步使用到的函数进行详细的解释。

#### 计算读锁和写锁已被获取的数量

```java
static final int SHARED_SHIFT   = 16;
static final int SHARED_UNIT    = (1 << SHARED_SHIFT);
static final int MAX_COUNT      = (1 << SHARED_SHIFT) - 1;
static final int EXCLUSIVE_MASK = (1 << SHARED_SHIFT) - 1;

// 返回共享锁的数量
static int sharedCount(int c)    { return c >>> SHARED_SHIFT; }
// 返回独占说的数量
static int exclusiveCount(int c) { return c & EXCLUSIVE_MASK; }
```

从上面可以看出，读锁使用state的高16位来表示数量，而写锁则使用低16位来表示数量。然后通过后面的俩个函数来分别计算对应的数量。

#### readerShouldBlock

判断当前获取读锁的线程是否应该阻塞，源码在FairSync中，源码如下

```java
final boolean readerShouldBlock() {
    return hasQueuedPredecessors();
}
```

代码比较简单，就是判断当前线程是否是队列中的第一个节点，如果是，则不需要阻塞，不是则需要阻塞。具体的和前面ReentrantLock中的一样，这里具体分析。

#### HoldCounter

计算每个线程获取读锁的数量，这里HoldCounter是ThreaLocal类型的变量，如果不了解这个对象，可以看这篇文章[深入分析ThreadLocal](http://fengxiutianya.top/posts/400f00a6/)，在分析这个之前，首先看一些定义在Sync类中的属性：

```java
// 计数器对象，用于记录每个线程保持读锁的数量
// 这个对象被记录在ThreadLocal中，缓存在cachedHoldCounter
static final class HoldCounter {
    int count = 0;
    final long tid = getThreadId(Thread.currentThread());
}

// 自定的ThreadLocal对象，设置初始化方法
static final class ThreadLocalHoldCounter
   			 extends ThreadLocal<HoldCounter> {
    
    public HoldCounter initialValue() {
        return new HoldCounter();
    }
}
// 记录当前线程获取读锁的数量，在构造器中初始化，当保持的读锁数量为空的时候删除
private transient ThreadLocalHoldCounter readHolds;

// 用于记录上一个线程成功获取读锁的数量
private transient HoldCounter cachedHoldCounter;
// 下面来个一个是记录第一个获取读锁的线程和获取读锁的数量
private transient Thread firstReader = null;
private transient int firstReaderHoldCount;
```

下面可以解释tryAcquireShared中的如下代码段

```java
// 第一次获取读锁
if (r == 0) {
    firstReader = current;
    firstReaderHoldCount = 1;

} else if (firstReader == current) {
    // 如果当前获取锁的线程是第一个获取读锁的线程
    firstReaderHoldCount++;
} else {
    // HoldCounter是用来统计该线程获取“读取锁”的次数。
    HoldCounter rh = cachedHoldCounter;
    if (rh == null || rh.tid != getThreadId(current))
        cachedHoldCounter = rh = readHolds.get();
    else if (rh.count == 0)
        readHolds.set(rh);
    // 将该线程获取“读取锁”的次数+1。
    rh.count++;
}
```

1. 首先判断是否是第一个线程获取读锁，如果是，则设置firstReader和firstReaderHoldCount值吗，可以加快后续此线程的获取读锁和记录读锁的数量。
2. 判断线程是否是firstReader，如果是直接使用firstReaderHoldCount进行累加，可以加快获取的速度。
3. 前面俩个都不是，则获取cachedHoldCounter，判断这个变量中保存的线程id是否和当前线程对应的id相同，如果是，则判断当前读锁的数量是否为0，如果为0，则调用` readHolds.set(rh)`初始化这个对象然后在原有的读锁数量上加1。
4. 不是则通过readHold获取当前线程对应的HoldCounter，并缓存在cachedHoldCounter中，加速下一次的操作，接着读锁数量加1。

#### fullTryAcquireShared

这个是tryAcquireShared的最后一步，也就是前面没有获取到共享锁，才会走到这一步，源码如下

```java
final int fullTryAcquireShared(Thread current) {
    // 下面这部分代码和tryAcquireShared有一部分是重复的。
    // 但是tryAcquireShared只是先尝试获取，但是如果出现竞争则获取
    // 不到共享锁，即前面那部分加快锁的获取。下面这部分通过
    // 循环尝试，保证如果可以获取读锁，则一定获取到
    HoldCounter rh = null;
    for (;;) {
        // 获取锁的状态
        int c = getState();
        // 如果是独占锁，并且获取锁的线程不是current线程；则返回-1。
        if (exclusiveCount(c) != 0) {
            if (getExclusiveOwnerThread() != current)
                return -1;
            
         // 如果需要阻塞等待。
        // 当需要阻塞等待的线程是第1个获取锁的线程的话，则继续往下执行。
        // 当需要阻塞等待的线程获取锁的次数为0时，则返回-1。
        } else if (readerShouldBlock()) {
           // 确保不是有一次获取读锁
            if (firstReader == current) {
                //忽略
            } else {
                // 获取当前线程获取读锁的数量，如果为0，则调用
                // ThreadLocal.remove删除这个ThreadLocal
                if (rh == null) {
                    rh = cachedHoldCounter;
                    if (rh == null || rh.tid != getThreadId(current)) {
                        rh = readHolds.get();
                        if (rh.count == 0)
                            readHolds.remove();
                    }
                }
                // 如果当前线程获取读锁的计数=0,则返回-1。
                // 表示还没有获取过读锁，不在这里进行获取，
                // 则需要阻塞获取读锁的进程
                if (rh.count == 0)
                    return -1;
            }
        }
        // 则获取读取锁的共享统计数；
        // 如果共享统计数超过MAX_COUNT，则抛出异常。
        if (sharedCount(c) == MAX_COUNT)
            throw new Error("Maximum lock count exceeded");
        // 将线程的读取锁次数加1
        // 这一步和上面一样，就不具体解释
        // 放在这里主要是因为CAS失败，如果失败，进入下一次循环
        if (compareAndSetState(c, c + SHARED_UNIT)) {       
            if (sharedCount(c) == 0) {
                firstReader = current;
                firstReaderHoldCount = 1;
            } else if (firstReader == current) {
                firstReaderHoldCount++;
            } else {
                if (rh == null)
                    rh = cachedHoldCounter;
                if (rh == null || rh.tid != getThreadId(current))
                    rh = readHolds.get();
                else if (rh.count == 0)
                    readHolds.set(rh);
                rh.count++;
                cachedHoldCounter = rh; // cache for release
            }
            return 1;
        }
    }
}

```

fullTryAcquireShared()会根据是否需要阻塞等待，读取锁的共享计数是否超过限制进行处理。如果不需要阻塞等待，并且锁的共享计数没有超过限制，则通过CAS尝试获取锁，并返回1。

至此tryAcquireShared已经解析完成，这里做一个总结：tryAcquireShared将代码分成俩个大部分，首先通过尝试获取锁，如果获取成功直接返回。这是为了加快获取锁。如果没有获取成功，说明CAS失败，则进入fullTryAcquireShared函数进行获取，这里会循环知道CAS交换成功。当然我只是说了一个精简的过程。具体的可以看上面。其他异常情况我也没有总结。

#### **doAcquireShared**

源码如下：

```java
private void doAcquireShared(int arg) {
    // 创建当前线程对应的节点，并将该线程添加到CLH队列中。
    final Node node = addWaiter(Node.SHARED);
    boolean failed = true;
    try {
        boolean interrupted = false;
        for (;;) {
            // 获取前继节点
            final Node p = node.predecessor();
            // 如果当前节点是头结点，尝试获取锁
            if (p == head) {
                int r = tryAcquireShared(arg);
                // 获取成功设置节点为可传播状态，
                // 然后释放后继获取读锁的节点
                if (r >= 0) {
                    setHeadAndPropagate(node, r);
                    p.next = null; // help GC
                    if (interrupted)
                        selfInterrupt();
                    failed = false;
                    return;
                }
            }
            // 如果当前线程不是CLH队列的表头，
            // 则通过shouldParkAfterFailedAcquire()判断是否需要等待，
            // 需要的话，则通过parkAndCheckInterrupt()进行阻塞等待。
            // 若阻塞等待过程中，线程被中断过，则设置interrupted为true。
            if (shouldParkAfterFailedAcquire(p, node) &&
                parkAndCheckInterrupt())
                interrupted = true;
        }
    } finally {
        // 上面出现异常，则取消当前节点
        if (failed)
            cancelAcquire(node);
    }
}
```

doAcquireShared()的作用是获取共享锁，流程如下

1. 创建线程对应的CLH队列的节点，然后将该节点添加到CLH队列中。CLH队列是管理获取锁的等待线程的队列。
2. 获取前继节点，判断当前节点是否是表头，如果当前线程是CLH队列的表头，则尝试获取共享锁；如果获取成功，则释放后继等待获取获取共享锁的线程。然后判断是否中断过，如果产生过中断，则调动中断函数产生一次中断。
3. 上一步没有成功获取锁，需要通过shouldParkAfterFailedAcquire()判断是否阻塞等待，需要阻塞，则通过parkAndCheckInterrupt()进行阻塞等待。

doAcquireShared()会通过for循环，不断的进行上面的操作；目的就是获取共享锁。需要注意的是：doAcquireShared()在每一次尝试获取锁时，是通过tryAcquireShared()来执行的！

其实和前面获取独占锁的流程差不多，只不过这里会有一个释放后继获取共享锁的节点。这一步放到下面讲解共享锁的释放中来说。

### 读锁的释放(公平锁)

释放锁是调用下面的函数，源码如下：

```java
public void unlock() {
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

上面的过程比较简单，先通过tryReleaseShared释放共享锁，尝试失败则直接返回；如果释放成功，则通过doReleaseShared()去释放共享锁并唤醒后继节点。

#### tryReleaseShared

tryReleaseShared()定义在ReentrantReadWriteLock中，源码如下：

```java
protected final boolean tryReleaseShared(int unused) {
    
    // 获取当前线程，即释放共享锁的线程。
    Thread current = Thread.currentThread();
    
    // 如果想要释放锁的线程(current)是第1个获取锁(firstReader)的线程，
    // 并且第1个获取锁的线程获取锁的次数=1，则设置firstReader为null；
    // 否则，将第1个获取锁的线程的获取次数-1。
    if (firstReader == current) {
        if (firstReaderHoldCount == 1)
            firstReader = null;
        else
            firstReaderHoldCount--;
    // 获取rh对象，并更新当前线程获取锁的信息。
    } else {
        HoldCounter rh = cachedHoldCounter;
        if (rh == null || rh.tid != current.getId())
            rh = readHolds.get();
        int count = rh.count;
        if (count <= 1) {
            readHolds.remove();
            if (count <= 0)
                throw unmatchedUnlockException();
        }
        --rh.count;
    }
    for (;;) {
        // 获取锁的状态
        int c = getState();
        // 将锁的获取次数-1。
        int nextc = c - SHARED_UNIT;
        // 通过CAS更新锁的状态。通过判断锁的状态是否为0来判断锁是否可以释放。
        if (compareAndSetState(c, nextc))
            return nextc == 0;
    }
}
```

上面的注释比较清晰，这里就不具体讲流程，下面来看**doReleaseShared**

#### **doReleaseShared**

```java
private void doReleaseShared() {
    for (;;) {
        // 获取CLH队列的头节点
        Node h = head;
       
        // 如果头节点不为null，并且头节点不等于tail节点。
        if (h != null && h != tail) {
            // 获取头节点对应的线程的状态
            int ws = h.waitStatus;
            
            // 如果头节点对应的线程是SIGNAL状态，
            // 则意味着头节点的下一个节点所对应的线程需要被unpark唤醒。
            if (ws == Node.SIGNAL) {
                // 设置头节点对应的线程状态为空状态。失败的话，则继续循环。
                if (!compareAndSetWaitStatus(h, Node.SIGNAL, 0))
                    continue;
                // 唤醒头节点的下一个节点所对应的线程。
                unparkSuccessor(h);
            }
            // 如果头节点对应的线程的状态值是0，
            // 则设置头结点的状态为PROPAGATE状态，等待有线程来获取锁才会结束循环。
            else if (ws == 0 &&
                     !compareAndSetWaitStatus(h, 0, Node.PROPAGATE))
                continue;                // loop on failed CAS
        }
        // 如果头节点没有改变，则继续循环。否则，退出循环。
        if (h == head)                   // loop if head changed
            break;
    }
}
```

doReleaseShared()会释放共享锁：流程如下：

1. 判断队列是否为空，如果为空则继续循环。
2. 如果不为空，则判断头结点是否为SIGNAL状态吗，如果是，则设置状态为0，然后唤醒后继获取锁的节点可以是独占或者共享锁。如果唤醒成功，头结点会改变，这一在最后一步就会推出这个循环
3. 如果头结点状态为0，则设置状态为PROPAGATE，然后继续循环。
4. 如果头结点发生改变，则继续循环。

主要流程如上，但是为什么要一直循环这是我不明白的地点。

### **公平共享锁和非公平共享锁**

和互斥锁ReentrantLock一样，ReadLock也分为公平锁和非公平锁。

公平锁和非公平锁的区别，体现在判断是否需要阻塞的函数readerShouldBlock()的不同。
公平锁的readerShouldBlock()的源码如下：

```java
final boolean readerShouldBlock() {
    return hasQueuedPredecessors();
}
```

在公平共享锁中，如果在当前线程的前面有其他线程在等待获取共享锁，则返回true；否则，返回false。
非公平锁的readerShouldBlock()的源码如下：

```java
final boolean readerShouldBlock() {
    return apparentlyFirstQueuedIsExclusive();
}
final boolean apparentlyFirstQueuedIsExclusive() {
    Node h, s;
    return (h = head) != null &&
        (s = h.next)  != null &&
        !s.isShared()         &&
        s.thread != null;
}
```

在非公平共享锁中，它会无视当前线程的前面是否有其他线程在等待获取共享锁。只要该非公平共享锁对应的线程不为null，则返回true。也就是当前锁的类型是共享锁，并且还没有释放。

### 写锁

写锁的获取和ReentrantLock中独占锁的获取是一样的，这里就不在单独说明。

### 使用示例

```java
package JUC.locks;

import lombok.Data;
import lombok.Getter;
import lombok.Setter;

import java.util.concurrent.locks.ReadWriteLock;
import java.util.concurrent.locks.ReentrantReadWriteLock;

/**************************************
 *      Author : zhangke
 *      Date   : 2018/4/18 22:13
 *      Desc   : 读写锁
 ***************************************/
public class ReadWriteLockTest {

    public static void main(String[] args) {
        // 创建账户
        MyCount myCount = new MyCount("4238920615242830", 10000);

        // 创建用户，并指定账户
        User user = new User("Tommy", myCount);

        // 分别启动3个“读取账户金钱”的线程 和 3个“设置账户金钱”的线程
        for (int i = 0; i < 3; i++) {
            user.getCash();
            user.setCash((i + 1) * 1000);
        }
    }


    static class User {
        private String name;            //用户名

        private MyCount myCount;        //所要操作的账户

        private ReadWriteLock myLock;   //执行操作所需的锁对象


        public User(String name, MyCount myCount) {
            this.name = name;
            this.myCount = myCount;
            this.myLock = new ReentrantReadWriteLock();

        }


        public void getCash() {
            new Thread(() -> {
                try {
                    myLock.readLock().lock();
                    System.out.println(Thread.currentThread().getName() + " getCash start");
                    myCount.getCash();
                    Thread.sleep(1);
                    System.out.println(Thread.currentThread().getName() + " getCash end");
                } catch (InterruptedException e) {

                } finally {
                    myLock.readLock().unlock();
                }
            }).start();
        }


        public void setCash(final int cash) {
            new Thread(() -> {
                try {
                    Thread.sleep(100);
                    myLock.writeLock().lock();
                    System.out.println(Thread.currentThread().getName() 
                                       + " setCash start");
                    myCount.setCash(cash);
                    System.out.println(Thread.currentThread().getName() 
                                       + " setCash end");
                } catch (InterruptedException e) {

                } finally {
                    myLock.writeLock().unlock();
                }
            }).start();
        }
    }

    static class MyCount {

        @Getter
        @Setter
        private String id; //账户id

        private int cash; //现金


        public MyCount(String id, int cash) {
            this.id = id;
            this.cash = cash;
        }


        public int getCash() {
            System.out.println(Thread.currentThread().getName() + " getCash" +
                               " cash= " + cash);
            return cash;
        }


        public void setCash(int cash) {
            System.out.println(Thread.currentThread().getName() + " setCash" +
                               " cash= " + cash);
            this.cash = cash;
        }
    }
}

```

运行结果：

```
Thread-0 getCash start
Thread-0 getCash cash= 10000
Thread-0 getCash end
Thread-2 getCash start
Thread-2 getCash cash= 10000
Thread-4 getCash start
Thread-4 getCash cash= 10000
Thread-2 getCash end
Thread-4 getCash end
Thread-5 setCash start
Thread-5 setCash cash= 3000
Thread-5 setCash end
Thread-3 setCash start
Thread-3 setCash cash= 2000
Thread-3 setCash end
Thread-1 setCash start
Thread-1 setCash cash= 1000
Thread-1 setCash end
```

从上面可以观察到读锁是可以共享，也就是读锁的打印的语句不一定是start-end连着的。但是写锁一定是。

## 参考

1. [Java多线程系列--“JUC锁”08之 共享锁和ReentrantReadWriteLock](https://www.cnblogs.com/skywang12345/p/3505809.html)