---
title: java线程系列 JUC锁 05  Condition条件
tags:
  - Condition
categories:
  - java
  - juc
  - lock
abbrlink: d14480c0
date: 2019-03-18 11:56:00
---

## 简单介绍

Condition的作用是对锁进行更精确的控制。Condition中的await()方法相当于Object的wait方法，Condition中的signal()方法相当于Object的notify()方法，Condition中的signalAll()相当于Object的notifyAll()方法。不同的是，Object中的wait()、notify()、notifyAll()方法是和同步锁(synchronized关键字)捆绑使用的；而Condition是需要与斥锁/共享锁捆绑使用的。互斥锁前面已经说过一个ReentrantLock，后还会说道ReentrantReadWriteLock共享锁。
<!-- more -->
### Condition函数示例

```java
// 造成当前线程在接到信号或被中断之前一直处于等待状态。
void await()
// 造成当前线程在接到信号、被中断或到达指定等待时间之前一直处于等待状态。
boolean await(long time, TimeUnit unit)
// 造成当前线程在接到信号、被中断或到达指定等待时间之前一直处于等待状态。
long awaitNanos(long nanosTimeout)
// 造成当前线程在接到信号之前一直处于等待状态。
void awaitUninterruptibly()
// 造成当前线程在接到信号、被中断或到达指定最后期限之前一直处于等待状态。
boolean awaitUntil(Date deadline)
// 唤醒一个等待线程。
void signal()
// 唤醒所有等待线程。
void signalAll()
```

## Condition示例

### 示例1

```java
public class WaitTest1 {

    public static void main(String[] args) {

        ThreadA ta = new ThreadA("ta");

        synchronized(ta) { // 通过synchronized(ta)获取“对象ta的同步锁”
            try {
                System.out.println(Thread.currentThread().getName()+" start ta");
                ta.start();

                System.out.println(Thread.currentThread().getName()+" block");
                ta.wait();    // 等待

                System.out.println(Thread.currentThread().getName()+" continue");
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
    }

    static class ThreadA extends Thread{

        public ThreadA(String name) {
            super(name);
        }

        public void run() {
            synchronized (this) { // 通过synchronized(this)获取“当前对象的同步锁”
                System.out.println(Thread.currentThread().getName()+" wakup others");
                notify();    // 唤醒“当前对象上的等待线程”
            }
        }
    }
}
```

运行结果

```
main start ta
main block
ta  wakup others
main continue
```

### 示例2

```java
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.ReentrantLock;

public class ConditionTest1 {
        
    private static Lock lock = new ReentrantLock();
    private static Condition condition = lock.newCondition();

    public static void main(String[] args) {

        ThreadA ta = new ThreadA("ta");

        lock.lock(); // 获取锁
        try {
            System.out.println(Thread.currentThread().getName()+" start ta");
            ta.start();

            System.out.println(Thread.currentThread().getName()+" block");
            condition.await();    // 等待

            System.out.println(Thread.currentThread().getName()+" continue");
        } catch (InterruptedException e) {
            e.printStackTrace();
        } finally {
            lock.unlock();    // 释放锁
        }
    }

    static class ThreadA extends Thread{

        public ThreadA(String name) {
            super(name);
        }

        public void run() {
            lock.lock();    // 获取锁
            try {
                System.out.println(Thread.currentThread().getName()+" wakup others");
                condition.signal();    // 唤醒“condition所在锁上的其它线程”
            } finally {
                lock.unlock();    // 释放锁
            }
        }
    }
}
```

运行结果

```
main start ta
main block
ta wakup others
main continue
```

通过示例1和示例2，我们知道Condition和Object的方法有一下对应关系：

```
              Object      Condition  
休眠          wait        await
唤醒个线程     notify      signal
唤醒所有线程   notifyAll   signalAll
```

Condition除了支持上面的功能之外，它更强大的地方在于：能够更加精细的控制多线程的休眠与唤醒。对于同一个锁，我们可以创建多个Condition，在不同的情况下使用不同的Condition。
例如，假如多线程读/写同一个缓冲区：当向缓冲区中写入数据之后，唤醒"读线程"；当从缓冲区读出数据之后，唤醒"写线程"；并且当缓冲区满的时候，"写线程"需要等待；当缓冲区为空时，"读线程"需要等待。        

 如果采用Object类中的wait(), notify(), notifyAll()实现该缓冲区，当向缓冲区写入数据之后需要唤醒"读线程"时，不可能通过notify()或notifyAll()明确的指定唤醒"读线程"，而只能通过notifyAll唤醒所有线程(但是notifyAll无法区分唤醒的线程是读线程，还是写线程)。  但是，通过Condition，就能明确的指定唤醒读线程。
看看下面的示例3，可能对这个概念有更深刻的理解。

### 示例3

```java
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.ReentrantLock;

class BoundedBuffer {
    final Lock lock = new ReentrantLock();
    final Condition notFull  = lock.newCondition(); 
    final Condition notEmpty = lock.newCondition(); 

    final Object[] items = new Object[5];
    int putptr, takeptr, count;

    public void put(Object x) throws InterruptedException {
        lock.lock();    //获取锁
        try {
            // 如果“缓冲已满”，则等待；直到“缓冲”不是满的，才将x添加到缓冲中。
            while (count == items.length)
                notFull.await();
            // 将x添加到缓冲中
            items[putptr] = x; 
            // 将“put统计数putptr+1”；如果“缓冲已满”，则设putptr为0。
            if (++putptr == items.length) putptr = 0;
            // 将“缓冲”数量+1
            ++count;
            // 唤醒take线程，因为take线程通过notEmpty.await()等待
            notEmpty.signal();

            // 打印写入的数据
            System.out.println(Thread.currentThread().getName() + " put  "+ (Integer)x);
        } finally {
            lock.unlock();    // 释放锁
        }
    }

    public Object take() throws InterruptedException {
        lock.lock();    //获取锁
        try {
            // 如果“缓冲为空”，则等待；直到“缓冲”不为空，才将x从缓冲中取出。
            while (count == 0) 
                notEmpty.await();
            // 将x从缓冲中取出
            Object x = items[takeptr]; 
            // 将“take统计数takeptr+1”；如果“缓冲为空”，则设takeptr为0。
            if (++takeptr == items.length) takeptr = 0;
            // 将“缓冲”数量-1
            --count;
            // 唤醒put线程，因为put线程通过notFull.await()等待
            notFull.signal();

            // 打印取出的数据
            System.out.println(Thread.currentThread().getName() + " take "+ (Integer)x);
            return x;
        } finally {
            lock.unlock();    // 释放锁
        }
    } 
}

public class ConditionTest2 {
    private static BoundedBuffer bb = new BoundedBuffer();

    public static void main(String[] args) {
        // 启动10个“写线程”，向BoundedBuffer中不断的写数据(写入0-9)；
        // 启动10个“读线程”，从BoundedBuffer中不断的读数据。
        for (int i=0; i<10; i++) {
            new PutThread("p"+i, i).start();
            new TakeThread("t"+i).start();
        }
    }

    static class PutThread extends Thread {
        private int num;
        public PutThread(String name, int num) {
            super(name);
            this.num = num;
        }
        public void run() {
            try {
                Thread.sleep(1);    // 线程休眠1ms
                bb.put(num);        // 向BoundedBuffer中写入数据
            } catch (InterruptedException e) {
            }
        }
    }

    static class TakeThread extends Thread {
        public TakeThread(String name) {
            super(name);
        }
        public void run() {
            try {
                Thread.sleep(10);                    // 线程休眠1ms
                Integer num = (Integer)bb.take();    // 从BoundedBuffer中取出数据
            } catch (InterruptedException e) {
            }
        }
    }
}
```

运行结果

```
p1 put  1
p4 put  4
p5 put  5
p0 put  0
p2 put  2
t0 take 1
p3 put  3
t1 take 4
p6 put  6
t2 take 5
p7 put  7
t3 take 0
p8 put  8
t4 take 2
p9 put  9
t5 take 3
t6 take 6
t7 take 7
t8 take 8
t9 take 9
```

**结果说明**：

1. BoundedBuffer 是容量为5的缓冲，缓冲中存储的是Object对象，支持多线程的读/写缓冲。多个线程操作“一个BoundedBuffer对象”时，它们通过互斥锁lock对缓冲区items进行互斥访问；而且同一个BoundedBuffer对象下的全部线程共用“notFull”和“notEmpty”这两个Condition。
   notFull用于控制写缓冲，notEmpty用于控制读缓冲。当缓冲已满的时候，调用put的线程会执行notFull.await()进行等待；当缓冲区不是满的状态时，就将对象添加到缓冲区并将缓冲区的容量count+1，最后，调用notEmpty.signal()缓冲notEmpty上的等待线程(调用notEmpty.await的线程)。 简言之，notFull控制“缓冲区的写入”，当往缓冲区写入数据之后会唤醒notEmpty上的等待线程。
   同理，notEmpty控制“缓冲区的读取”，当读取了缓冲区数据之后会唤醒notFull上的等待线程。

2. 在ConditionTest2的main函数中，启动10个“写线程”，向BoundedBuffer中不断的写数据(写入0-9)；同时，也启动10个“读线程”，从BoundedBuffer中不断的读数据。

3. 简单分析一下运行结果。

   ```
   	 1, p1线程向缓冲中写入1。    此时，缓冲区数据:   | 1 |   |   |   |   |
        2, p4线程向缓冲中写入4。    此时，缓冲区数据:   | 1 | 4 |   |   |   |
        3, p5线程向缓冲中写入5。    此时，缓冲区数据:   | 1 | 4 | 5 |   |   |
        4, p0线程向缓冲中写入0。    此时，缓冲区数据:   | 1 | 4 | 5 | 0 |   |
        5, p2线程向缓冲中写入2。    此时，缓冲区数据:   | 1 | 4 | 5 | 0 | 2 |
        此时，缓冲区容量为5；缓冲区已满！如果此时，还有“写线程”想往缓冲中写入数据，
        会调用put中的notFull.await()等待，直接缓冲区非满状态，才能继续运行。
        6, t0线程从缓冲中取出数据1。此时，缓冲区数据:    |   | 4 | 5 | 0 | 2 |
        7, p3线程向缓冲中写入3。    此时，缓冲区数据:   | 3 | 4 | 5 | 0 | 2 |
        8, t1线程从缓冲中取出数据4。此时，缓冲区数据:    | 3 |   | 5 | 0 | 2 |
        9, p6线程向缓冲中写入6。    此时，缓冲区数据:   | 3 | 6 | 5 | 0 | 2 |
        ...
   ```

## 源码分析

上面已经演示了如何使用Condition条件队列，下面来具体分析java是如何实现的。这里是结合ReentranLock来分析。

Condition是一个接口，实现类其实是在AQS中——`ConditionObject`，ReentranLock的newConditon方法其实是创建了一个`AbstractQueuedSynchronizer.ConditionObject`对象：

```java
// ReentrantLock
public Condition newCondition() {
    return sync.newCondition();
}
// Sync中的代码
final ConditionObject newCondition() {
    return new ConditionObject();
}
```

从上面可以看出实际上是创建了一个ConditionObject对象，下面首先看看这个对象的属性，然后分析wait和singal函数。

```java
 public class ConditionObject implements Condition, java.io.Serializable {
        private static final long serialVersionUID = 1173984872572414699L;
        
        // 条件队列的第一个节点
        private transient Node firstWaiter;
     
        // 条件队列的最后一个节点
        private transient Node lastWaiter;
        /** Mode meaning to reinterrupt on exit from wait */
       // 表示线程被中断
        private static final int REINTERRUPT =  1;
     
        // 抛出异常而使得线程被中断
        private static final int THROW_IE    = -1;
		public ConditionObject() { }
 
}
```

这里提前说明一点，其实Condition内部维护了等待队列的头结点和尾节点，该队列的作用是存放等待signal信号的线程，该线程被封装为Node节点后存放于此。

这里又出现了一个条件队列，可能我们就有点晕了，了解AbstractQueuedSynchronizer同步器的都知道，这个类中还维护着一个队列，AQS自己维护的队列是当前等待资源(这里的资源就是锁)的队列，AQS会在资源被释放后，依次唤醒队列中从前到后的所有节点，使他们对应的线程恢复执行。直到队列为空。

而Condition自己也维护了一个队列，该队列的作用是维护一个等待signal信号的队列，两个队列的作用是不同，事实上，每个线程也仅仅会同时存在以上两个队列中的一个，流程是这样的：

1. 首先，线程1调用lock.lock()时，由于此时锁并没有被其它线程占用，因此线程1直接获得锁并不会进入AQS同步队列中进行等待。

2. 在线程1执行期间，线程2调用lock.lock()时由于锁已经被线程1占用，因此，线程2进入AQS同步队列中进行等待。

3. 在线程1中执行condition.await()方法后，线程1释放锁并进入条件队列Condition中等待signal信号的到来。

4. 线程2，因为线程1释放锁的关系，会唤醒AQS队列中的头结点，所以线程2会获取到锁。

5. 线程2调用signal方法，这个时候Condition的等待队列中只有线程1一个节点，于是它被取出来，并被加入到AQS的等待队列中。注意，这个时候，线程1 并没有被唤醒。只是加入到了AQS等待队列中去了

6. 待线程2执行完成之后并调用lock.unlock()释放锁之后，会唤醒此时在AQS队列中的头结点.所以线程1开始争夺锁(由于此时只有线程1在AQS队列中，因此没人与其争夺),如果获得锁继续执行。直到线程1释放锁整个过程执行完毕。

可以看到，整个协作过程是靠结点在AQS的等待队列和Condition的等待队列中来回移动实现的，Condition作为一个条件类，很好的自己维护了一个等待信号的队列，并在适时的时候将结点加入到AQS的等待队列中来实现的唤醒操作。

这里先定义：AQS中的队列叫等待队列，Condition中的队列叫条件等待队列。

### await()

代用此方法，会使的当前线程进入条件队列进行阻塞，源码如下:

```java
public final void await() throws InterruptedException {
    // 线程终端抛出异常
    if (Thread.interrupted())
        throw new InterruptedException();
    // 添加线程到条件等待队列
    Node node = addConditionWaiter();
    // 释放锁，也就是将锁的状态设为0
    int savedState = fullyRelease(node);
    int interruptMode = 0;
    // 检测此节点是否在等待队列上，如果不在，说明此队列没有资格竞争锁
    // 线程继续挂起休眠，直到检测到此线程已经在同步队列上
    // 说明有线程发出了signal信号
    while (!isOnSyncQueue(node)) {
        LockSupport.park(this);
        // 检测当前线程是否被中断过，如果中断，则退出
        if ((interruptMode = checkInterruptWhileWaiting(node)) != 0)
            break;
    }
    //被唤醒后，重新开始正式竞争锁，同样，如果竞争不到还是会将自己沉睡，等待唤醒重新开始竞争。
    if (acquireQueued(node, savedState) && interruptMode != THROW_IE)
        interruptMode = REINTERRUPT;
    // 清理条件队列中不是在等待条件的节点
    if (node.nextWaiter != null) // clean up if cancelled
        unlinkCancelledWaiters();
    // 报告异常
    if (interruptMode != 0)
        reportInterruptAfterWait(interruptMode);
}
```

上面的注释已经描述的比较清楚，现在来其中具体的函数。这里对流程进行总结

1. 判断线程是否被中断，如果中断，则抛出中断异常。
2. 插入节点到等待条件队列中，等待条件队列是通过nextWaiter来进行连接。
3. 释放当前线程获取的所有锁，然后返回锁的状态值。
4. 循环判断当前条件节点是否在等待队列上，如果是，则可以重新获取锁，在循环中会判断当前线程是否被中断过，如果中断则退出循环。
5. 获取锁，没有中断返回false，继续下一步，如果线程是有中断产生，则判断中断的类型，设置线程的中断标志。
6. 如果当前节点还有后继等待条件节点，删除所有非条件等待节点。
7. 如果线程是被中断或者因为异常而被中断，则报告异常。

#### addConditionWaiter

添加当前线程到条件等待队列中，源码如下

```java
private Node addConditionWaiter() {
    // 尾节点
    Node t = lastWaiter;
    
    // CONDITION，值为-2，表示当前节点在等待condition，也就是在condition队列中；
    // 如果此节点的状态不是CONDITION,则需要将此节点在条件队列中移除
    if (t != null && t.waitStatus != Node.CONDITION) {
        // 删除所有非等待条件节点
        unlinkCancelledWaiters();
        t = lastWaiter;
    }
    // 创建当前线程的等待节点
    Node node = new Node(Thread.currentThread(), Node.CONDITION);
    
    // 将节点插入到条件队列中
    if (t == null)
        firstWaiter = node;
    else
        t.nextWaiter = node;
    // 设置尾节点为node
    lastWaiter = node;
    return node;
}
// 删除所有非等待条件节点
private void unlinkCancelledWaiters() {
    Node t = firstWaiter;
    Node trail = null;
    // 循环知道遍历完所有节点
    while (t != null) {
        Node next = t.nextWaiter;
        if (t.waitStatus != Node.CONDITION) {
            t.nextWaiter = null;
            if (trail == null)
                firstWaiter = next;
            else
                trail.nextWaiter = next;
            if (next == null)
                lastWaiter = trail;
        }
        else
            trail = t;
        t = next;
    }
}
```

上面主要过程就是创建当前节点对应的条件节点然后插入，如果尾节点不是等待条件节点，则会调用unlinkCancelledWaiters，删除所有的非条件节点。

另外此处为什么没有使用CAS来替换这些节点的原因是，只有获取到锁的节点才能有资格来操作条件队列，也就是每个时刻只有一个线程操作条件队列，因此不会出现线程安全问题。

#### fullyRelease

释放当前线程获取到的锁，代码如下

```java
/**
 *函数功能：释放锁，
 *如果失败，则抛异常并将此节点的类型设置为：CANCELLED，为之后从条件队列中移除此节点。
*/
final int fullyRelease(Node node) {
    boolean failed = true;
    try {
        
        // 获取锁的状态
        int savedState = getState();
        // 释放锁
        if (release(savedState)) {
            failed = false;
            return savedState;
        } else {
            // 失败则抛出异常
            throw new IllegalMonitorStateException();
        }
    } finally {
        // 如果释放失败，设置当前节点的状态是取消状态
        if (failed)
            node.waitStatus = Node.CANCELLED;
    }
}
public final boolean release(int arg) {
    // 调用tryRelease释放锁，如果释放成功，返回true
    if (tryRelease(arg)) {
        Node h = head;
        // 唤醒后继阻塞的线程。
        if (h != null && h.waitStatus != 0)
            unparkSuccessor(h);
        return true;
    }
    return false;
}
```

上面主要是释放线程获取的锁，也就是讲锁的状态设置为可以获取状态，释放成功则唤醒后继阻塞的线程。失败则抛出异常，并将当前线程对应的节点设置为取消状态。

#### isOnSyncQueue

这个函数用于判断当前节点是否可以重新获取锁，条件队列中的节点必须放在同步队列上才能重新获取锁。源码如下：

```java
final boolean isOnSyncQueue(Node node) {
    // 如果节点状态为CONDITION，或者此节点没有前继节点，则表明还在条件队列上。
    // 因为条件队列节点是通过nextWaiter来进行连接
    if (node.waitStatus == Node.CONDITION || node.prev == null)
        return false;
    // 如果next属性不为空，则表明已经在等待获取锁的队列上，而不是在条件队列上
    if (node.next != null) // If has successor, it must be on queue
        return true;
    // node.prev可以是非空的，而且还没有进入等待队列中，
    // 因为将其放在等待队列中的CAS可能会失败。
    // 所以我们必须从尾部遍历以确保它真的是在等待队列上。
    // 这个方法总是队列的尾部附近调用，除非CAS失败的次数过多（这是不太可能的），
    // 所以我们几乎不会遍历太多次数。
    return findNodeFromTail(node);
}

// 在等待队列上发现线程对应的节点，则返回true
private boolean findNodeFromTail(Node node) {
    Node t = tail;
    for (;;) {
        if (t == node)
            return true;
        if (t == null)
            return false;
        t = t.prev;
    }
}
```

#### checkInterruptWhileWaiting

检测中断信号，并返回中断产生的原因。1表示线程被中断，-1表示抛出异常而使得线程被中断。

```java
private int checkInterruptWhileWaiting(Node node) {
    return Thread.interrupted() ?
        (transferAfterCancelledWait(node) ? THROW_IE : REINTERRUPT) :
    0;
}
final boolean transferAfterCancelledWait(Node node) {
    // 设置当前节点的状态为0，如果设置成功，将节点插入等待队列
    if (compareAndSetWaitStatus(node, Node.CONDITION, 0)) {
        enq(node);
        return true;
    }
	// 如果上面的设置节点状态失败，则可能产生了一个signal()，
    // 那么在signal完成enq（）之前，线程不能继续操作。
    // 不完全转移过程中的取消既罕见又短暂，所以只需旋转。
    while (!isOnSyncQueue(node))
        Thread.yield();
    return false;
}
```

至此，await中重要的函数已经分析完，其他的和获取公平锁一样，这里就不具体讲解。实际上，await就是讲等待队列上的节点单独放到一个条件队列上，如果希望再次获取锁，只有将此节点再次移动到等待队列上，那么当前线程就有机会获取到锁。

### signal()

```java
public final void signal() {
    // 如果当前线程不是锁的拥有者，抛出非法操作异常
    if (!isHeldExclusively())
        throw new IllegalMonitorStateException();
    Node first = firstWaiter;
    // 如果条件队列中有等待获取锁的线程，唤醒后继线程
    if (first != null)
        doSignal(first);
}
```

此方法干了两件事：取出Condition条件队列中的头结点，然后调用doSignal开始唤醒。

```java
private void doSignal(Node first) {
    do {
        // 修改头结点，完成旧头结点的移除工作
        if ( (firstWaiter = first.nextWaiter) == null)
            lastWaiter = null;
        first.nextWaiter = null;
        // 如果转移失败，则说明头结点在条件队列中被取消，
        // 则继续操作下一个节点
    } while (!transferForSignal(first) &&
             (first = firstWaiter) != null);
}
final boolean transferForSignal(Node node) {

    // 设置node节点的状态值为0，如果失败，说明已经被取消
    if (!compareAndSetWaitStatus(node, Node.CONDITION, 0))
        return false;
    
    // 节点条件队列中的节点转移到等待队列中
    Node p = enq(node);
    int ws = p.waitStatus;

    // 如果节点为取消状态或尝试设置waitstatus失败，
    // 唤醒并重新设置等待节点（在这种情况下，waitstatus可能是短暂且无害的错误）
    if (ws > 0 || !compareAndSetWaitStatus(p, ws, Node.SIGNAL))
        LockSupport.unpark(node.thread);
    return true;
}
```

可以看到，正常情况 ws > 0 || !compareAndSetWaitStatus(p, ws, Node.SIGNAL) 这个判断是不会为true的，所以，不会在这个时候唤醒该线程。但是如果此时被唤醒，但是因为前面还会判断当前节点是否可以获取锁来保证获取锁的正确性，因此在总体上不会出现安全问题。

## 总结

本章以ReentrantLock的公平锁为例，分析了AbstractQueuedSynchronizer的Condition功能。
通过分析，可以看到，当线程在指定Condition对象上等待的时候，其实就是将线程包装成结点，加入了条件队列，然后阻塞。当线程被通知唤醒时，则是将条件队列中的结点转换成等待队列中的结点，之后的处理就和独占功能完全一样。

除此之外，Condition还支持限时等待、非中断等待等功能，分析思路是一样的，可以自己去阅读AQS的源码，通过使用示例，加入调试断点一步步看内部的调用流程，主干理顺了之后，再看其它分支，其实是异曲同工的。

### 参考

1.  [Java多线程进阶（八）—— J.U.C之locks框架：AQS的Conditon等待(3)](https://segmentfault.com/a/1190000015807209)
2. [Java多线程系列目录(共43篇)](https://www.cnblogs.com/skywang12345/p/java_threads_category.html)