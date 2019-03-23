---
tags:
  - lock
categories:
  - java
  - juc
  - lock
title: java线程系列 JUC锁 03 ReentrantLock公平锁
abbrlink: cb19bcd7
date: 2019-03-18 00:27:00
---
## **基本概念**

本章，我们会讲解线程获取和释放公平锁的原理；在讲解之前，需要了解几个基本概念。后面的内容，都是基于这些概念的；这些概念可能比较枯燥，但从这些概念中，能窥见java锁的一些架构，这对我们了解锁是有帮助的。

1. **AQS** -- 指AbstractQueuedSynchronizer类。

   AQS是JUC中所有锁内部具体实现依赖的的抽象类，锁的许多公共方法都是在这个类中实现。AQS是独占锁(例如，ReentrantLock)和共享锁(例如，Semaphore)的公共父类。

   AQS需要下面三个基本组件的相互协作：

   - 同步状态的原子性管理；
   - 线程的阻塞与解除阻塞；
   - 队列的管理；

   创建一个框架分别实现这三个组件是有可能的。但是，这会让整个框架既难用又没效率。例如：存储在队列节点的信息必须与解除阻塞所需要的信息一致，而暴露出的方法的签名必须依赖于同步状态的特性。

   同步器框架的核心决策是为这三个组件选择一个具体实现，同时在使用方式上又有大量选项可用。这里有意地限制了其适用范围，但是提供了足够的效率，使得实际上没有理由在合适的情况下不用这个框架而去重新建造一个。
   <!-- more -->

2. **AQS**锁的类别 -- 分为“**独占锁**”和“**共享锁**”两种。

   * **独占锁** -- 锁在一个时间点只能被一个线程锁占有。根据锁的获取机制，它又划分为“**公平锁**”和“**非公平锁**”。公平锁，是按照通过CLH等待线程按照先来先得的规则，公平的获取锁；而非公平锁，则当线程要获取锁时，它会无视CLH等待队列而直接获取锁。独占锁的典型实例子是ReentrantLock，此外，ReentrantReadWriteLock.WriteLock也是独占锁。
   *  **共享锁** -- 能被多个线程同时拥有，能被共享的锁。JUC包中的ReentrantReadWriteLock.ReadLock，CyclicBarrier、CountDownLatch和Semaphore都是共享锁。

3. **CLH队列** -- Craig, Landin, and Hagersten lock queue

   CLH是自旋锁实现方式的一种，如果你对这个还不是特别了解，可以看这篇文章[自旋锁](http://fengxiutianya.top/posts/6d00129c/)

   CLH队列是AQS中等待获取锁的线程队列。在多线程中，为了保护竞争资源不被多个线程同时操作而引起错误，我们常常需要通过锁来保护这些资源。在独占锁中，竞争资源在一个时间点只能被一个线程锁访问；而其它线程则需要等待。CLH就是管理这些“等待锁”的线程的队列。
    CLH是一个非阻塞的FIFO列。也就是说往里面插入或移除一个节点的时候，在并发条件下不会阻塞，而是通过自旋锁和CAS保证节点插入和移除的原子性。

4. **CAS函数** -- Compare And Swap 
   CAS函数，是比较并交换函数，它是原子操作函数；通过CAS操作的数据都是以**原子方式**进行的。例如，compareAndSetHead(), compareAndSetTail(), compareAndSetNext()等函数。它们共同的特点是，这些函数所执行的动作是以原子的方式进行的。

## **ReentrantLock数据结构**

ReentrantLock的UML类图

![upload successful](/images/pasted-299.png)

从图中可以看出：

* ReentrantLock实现了Lock接口。
* ReentrantLock与Sync是组合关系。ReentrantLock中，包含了Sync对象；而且，Sync是AQS的子类；更重要的是，Sync有两个子类FairSync(公平锁)和NonFairSync(非公平锁)。ReentrantLock是一个独占锁，至于它到底是公平锁还是非公平锁，就取决于Sync对象是"FairSync的实例"还是"NonFairSync的实例"。

## ReentrantLock源码分析

在分析源码之前，首先介绍后面要用到的一些属性。

```java
// AQS 中的代码 
static final class Node {
  
     	// 标记节点为共享节点类型
        static final Node SHARED = new Node();
        // 标记节点为独占节点类型
        static final Node EXCLUSIVE = null;

     	// 下面四个显示当前节点的状态
        // 表示当前节点已取消等待
        static final int CANCELLED =  1;
        // 表示当前节点释放时，需要唤醒后继节点
        static final int SIGNAL    = -1;
        // 表示当前节点是一个等待条件的节点
        static final int CONDITION = -2;
        // 这个是对共享节点的头结点在释放时，应该传播到其他共享的节点
        static final int PROPAGATE = -3;
		 
     	// 当前节点的状态，如果是大于0，则表示取消，小于表示等待，等于0什么都不代表
        volatile int waitStatus;

      	// 前继节点
        volatile Node prev;

   		// 后继及诶单
        volatile Node next;

        // 节点入队时的线程，入队时初始化，出队时为null
        volatile Thread thread;
		// nextWaiter是“区别当前CLH队列是 ‘独占锁’队列 还是 ‘共享锁’队列 的标记”
    	// 若nextWaiter=SHARED，则CLH队列是“独占锁”队列；
    	// 若nextWaiter=EXCLUSIVE，(即nextWaiter=null)，则CLH队列是“共享锁”队列。
        Node nextWaiter;

        。。。。省略了一些方法 
    }
   
	// 等待队列的头结点，头结点如果存在，则其状态不能是取消状态
    private transient volatile Node head;

	// 等待队列尾节点
    private transient volatile Node tail;

    // 同步队列的状态，如果是0表示未有线程获取锁，大于0已有线程获取锁
    private volatile int state;
```

通过上面ReentrantLock的UML类图可以看出，ReentrantLock类中锁的主要实现是有内部类Sync以及其俩个子类FairSync和NonfairSync来实现的。其中Sync是AQS的子类，实现了其中大部分抽象方法，但是由于公平锁和非公平锁的获取方式不同，因此Sync中lock方法没有实现，这就是FairSync和NonfairSync不同的地点。

这里先分析公平锁的获取与释放，并对ReentrantLock中的方法做简单介绍

### 公平锁的获取

公平锁的获取是通过lock来获取，源码如下

```java
public void lock() {
	sync.lock();
}
 final void lock() {
    acquire(1);
}
```

上面代码可以看出当前线程实际上是通过acquire(1)获取锁的。这里说明一下“**1**”的含义，它是设置锁的状态的参数。对于“独占锁”而言，锁处于可获取状态时，它的状态值是0；锁被线程初次获取到，它的状态值就变成1。由于ReentrantLock(公平锁/非公平锁)是可重入锁，所以独占锁可以被同一个线程多此获取，每获取1次就将锁的状态+1。也就是说，初次获取锁时，通过acquire(1)将锁的状态值设为1；再次获取锁时，将锁的状态值设为2；依次类推，这就是为什么获取锁时，传入的参数是1的原因。

另外**可重入**是指锁可以被单个线程多次获取。

### acquire()

acquire()是在AQS中实现，源码如下

```java
// AQS 中的代码
public final void acquire(int arg) {
    if (!tryAcquire(arg) &&
  	  acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
    selfInterrupt();
}
```

代码看着没多少，但是这时获取锁的关键代码，解释上面的流程

1. 当前线程首先通过tryAcquire尝试获取锁，如果获取成功的话，直接返回，尝试失败，就要进入下一步。
2. 当前线程获取失败，通过addWaiter(Node.EXCLUSIVE)将当前线程插入到CLH队列末尾来等待获取锁。
3. 插入成功后，会使用acquireQueued来获取锁，这里获取锁只会等待当前等待节点的前继节点为head节点才会获取成功。没有获取锁，线程会进入休眠状态。如果当前线程在休眠等待过程中被打断，acquireQueue会返回true，此时当前线程会调用selfInterrupt来给自己产生一个中断。

大体的流程如上面介绍，下面会具体的分析每一步。

### tryAcquire

这里说的是公平锁，源码如下

```java
protected final boolean tryAcquire(int acquires) {
    // 获取当前线程
    final Thread current = Thread.currentThread();
    // 获取独占锁的状态
    int c = getState();
    // c=0意味着锁没有被任何线程锁拥有
    if (c == 0) {
        // 锁没有被任何线程拥有
        // 则判断当前线程是否是队列中的第一个线程
        // 如果是，则获取该锁，设置锁的状态
        if (!hasQueuedPredecessors() &&
            compareAndSetState(0, acquires)) {
            // 设置锁的拥有者为当前线程
            setExclusiveOwnerThread(current);
            return true;
        }
    }
    // 判断锁的拥有者是否是当前线程，如果是，则更新锁的状态值
    else if (current == getExclusiveOwnerThread()) {
        int nextc = c + acquires;
        // 下面这个几乎不会出现，因为一个线程不会获取那么多次锁
        if (nextc < 0)
            throw new Error("Maximum lock count exceeded");
        setState(nextc);
        return true;
    }
    return false;
}
```

总结上面的流程

1. 先判断锁的状态，如果没有被获取，则判断当前线程是否是队列的第一个线程，如果是，则设置锁的状态并更新锁的拥有者为当前线程。
2. 如果锁已经被获取，判断锁的拥有者是否为当前线程，如果是则设置锁的状态值，返回获取锁成功
3. 上面俩个都没有成功，返回获取锁失败。

上面有几个函数，后面也会用到，这里先具体分析，分别是`hasQueuedPredecessors`、`compareAndSetState`

`setExclusiveOwnerThread`,`getExclusiveOwnerThread`和`setState`

#### **hasQueuedPredecessors()**

这个函数用于判断当前线程是否是队列头结点

```java
// AQS 中的代码
public final boolean hasQueuedPredecessors() {

    Node t = tail; // Read fields in reverse initialization order
    Node h = head;
    Node s;
    return h != t &&
        ((s = h.next) == null || s.thread != Thread.currentThread());
}
```

整体还是比较简单这里就不具体解释。

#### **compareAndSetState()和setState(),getState()**

这俩个函数都是用来设置锁的装填值，源码如下

```java
// AQS 中的代码
protected final boolean compareAndSetState(int expect, int update) {
    return unsafe.compareAndSwapInt(this, stateOffset, expect, update);
}

protected final void setState(int newState) {
    state = newState;
}
// 获取锁的状态
protected final int getState() {
    return state;
}
```

上面俩个区别是，一个使用CAS来更新state值，一个是直接更新。产生这个区别是因为，setState是获取锁的线程才能够更新，而在一个线程中更新这个值肯定是线程安全的。另一个是在没有获取到锁的情况下更新，所以需要考虑多线程竞争，因此需要使用CAS来更新。而getState是用来获取锁的状态。此外，state是用voliate来修饰的，也就是保证所有线程都会看到最新的值。

#### setExclusiveOwnerThread 和 getExclusiveOwnerThread

这俩个是定义在AbstractOwnableSynchronizer这个抽象类中的，用于设置和获取获取当前锁的线程。但是我有点不明白为什么是抽象类，。源码如下

```java
private transient Thread exclusiveOwnerThread;

protected final void setExclusiveOwnerThread(Thread thread) {
	exclusiveOwnerThread = thread;
}

protected final Thread getExclusiveOwnerThread() {
	return exclusiveOwnerThread;
}
```

### **addWaiter(Node.EXCLUSIVE)**

addWaiter(Node.EXCLUSIVE)的作用是创建当前线程的Node节点，且Node中记录当前线程对应的锁是独占锁类型，并且将该节点添加到CLH队列的末尾。

```JAVA
// AQS 中的代码
private Node addWaiter(Node mode) {
    // 为当前线程新建一个节点，节点对象的线程为当前线程，节点对应的锁的类型为mode
    Node node = new Node(Thread.currentThread(), mode);
    // 若CLH队列不为空，则将当前及诶单插入到末尾，
    Node pred = tail;
    // 这里首先尝试一次，如果掺入成功，则直接返回节点，不成功使用enq来插入
    if (pred != null) {
        node.prev = pred;
        if (compareAndSetTail(pred, node)) {
            pred.next = node;
            return node;
        }
    }
    enq(node);
    return node;
}
```

compareAndSetTail就是使用CAS方式来更新队列末尾节点，和前面compareAndSetHead差不多，这里就不具体分析。下面看看enq函数

```java
// AQS 中的代码
private Node enq(final Node node) {
    for (;;) {
        Node t = tail;
        if (t == null) { // Must initialize
            if (compareAndSetHead(new Node()))
                tail = head;
        } else {
            node.prev = t;
            if (compareAndSetTail(t, node)) {
                t.next = node;
                return t;
            }
        }
    }
}
```

enq()的作用很简单。如果CLH队列为空，则新建一个CLH表头；然后将node添加到CLH末尾。否则，直接将node添加到CLH末尾。

### **acquireQueued**

acquireQueued()的目的是从队列中获取锁，源码如下

```java
// AQS 中的代码
final boolean acquireQueued(final Node node, int arg) {
    // 获取锁是否失败
    boolean failed = true;
    try {
        //线程的中断状态
        boolean interrupted = false;
        for (;;) {
            // 获取前继节点
            // node是当前线程对应的节点，这里意味着上一个等待
            // 获取锁的节点
            final Node p = node.predecessor();
            // 如果p是头节点，并且获取锁成功
            if (p == head && tryAcquire(arg)) {
                // 设置头结点
                setHead(node);
                p.next = null; // help GC
                failed = false;
                return interrupted;
            }
            // 上一步获取失败，这里会首先设置当前节点到合适的位置
            // 然后阻塞当前节点直到被唤醒，然后返回中断状态。
            if (shouldParkAfterFailedAcquire(p, node) &&
                parkAndCheckInterrupt())
                interrupted = true;
        }
    } finally {
        // 如果获取失败，则取消当前节点
        if (failed)
            cancelAcquire(node);
    }
}
```

上面整体逻辑还是比较清晰，这里不过有几点需要注意。

1. 此函数不响应中断，后面会具体解释。
2. 一个线程要出队只有俩种可能，一是此线程是队列的第一个节点并且获取锁成功，二是出现异常，通过finally里面的代码设置当前节点为取消状态。

下面分别来看里面的函数

#### shouldParkAfterFailedAcquire

```java
// AQS 中的代码
private static boolean shouldParkAfterFailedAcquire(Node pred, Node node) {
    // 获取前一个线程的状态
    int ws = pred.waitStatus;
    // 如果前继节点是SINGAL状态，则意味着当前下次呢很难过需要被
    // unPark唤醒，此时返回true
    if (ws == Node.SIGNAL)
        return true;
    // 如果前继节点是取消状态，则设置当前节点的前继节点为前继节点的前继节点
    // 直到找到一个节点的状态不为取消状态。
    if (ws > 0) {
        do {
            node.prev = pred = pred.prev;
        } while (pred.waitStatus > 0);
        pred.next = node;
    } else {
        // 如果前继节点的状态是0或者PROPAGATE，则设置前继节点状态为SIGNAL
        // 此外调用者，需要一直尝试，确保在获取锁之前没有被暂停
        compareAndSetWaitStatus(pred, ws, Node.SIGNAL);
    }
    return false;
}
```

1. 关于waitStatus请参考下表(中扩号内为waitStatus的值)，更多关于waitStatus的内容，可以参考前面的Node类的介绍。

   ```
   CANCELLED[1]  -- 当前线程已被取消
   SIGNAL[-1]    -- “当前线程的后继线程需要被unpark(唤醒)”。
   				 一般发生情况是：当前线程的后继线程处于阻塞状态，
   				 而当前线程被release或cancel掉，因此需要唤醒当前线程的后继线程。
   CONDITION[-2] -- 当前线程(处在Condition休眠状态)在等待Condition唤醒
   PROPAGATE[-3] -- (共享锁)其它线程获取到“共享锁”
   [0]           -- 当前线程不属于上面的任何一种状态。
   ```

2. shouldParkAfterFailedAcquire()通过以下流程判断当前线程是否需要被阻塞。
   1. 如果前继节点状态为SIGNAL，表明当前节点需要被unpark(唤醒)，此时则返回true。表明当前线程可以被阻塞
   2. 如果前继节点状态为CANCELLED(ws>0)，说明前继节点已经被取消，则通过先前回溯找到一个有效(非CANCELLED状态)的节点，并返回false。此时当前节点不能被阻塞，因为还没有保证此节点能够被前继节点唤醒
   3. 如果前继节点状态为非SIGNAL、非CANCELLED，则设置前继的状态为SIGNAL，并返回false。这时前继节点在释放锁时有责任唤醒后继阻塞的节点。

如果上述的第一步发生，即前继节点是SIGNAL状态，则意味着当前线程需要被阻塞。接下来会调用parkAndCheckInterrupt()阻塞当前线程，直到当前先被唤醒才从parkAndCheckInterrupt()中返回。

#### **parkAndCheckInterrupt**

源码如下：

```java
private final boolean parkAndCheckInterrupt() {
    // 通过LockSupport的park()阻塞“当前线程”。
    LockSupport.park(this);
    // 返回线程的中断状态。
    return Thread.interrupted();
}
```

parkAndCheckInterrupt()的作用是阻塞当前线程，并且返回线程被唤醒之后的中断状态。
它会先通过LockSupport.park()阻塞当前线程，然后通过Thread.interrupted()返回线程的中断状态。

这里介绍一下线程被阻塞之后如何唤醒。一般有2种情况：

1. **unpark()唤醒**：前继节点对应的线程使用完锁之后，通过unpark()方式唤醒当前线程。
2. **中断唤醒**：其它线程通过interrupt()中断当前线程。

**补充**：LockSupport()中的park(),unpark()的作用和Object中的wait(),notify()作用类似，是阻塞/唤醒。
它们的用法不同，park(),unpark()是轻量级的，而wait(),notify()是必须先通过Synchronized获取同步锁。

上面俩个介绍了acquireQueued中的主要函数，下面我们来看看整体逻辑还剩下的部分

```java
// 获取前继节点
// node是当前线程对应的节点，这里意味着上一个等待
// 获取锁的节点
final Node p = node.predecessor();
// 如果p是头节点，并且获取锁成功
if (p == head && tryAcquire(arg)) {
    // 设置头结点
    setHead(node);
    p.next = null; // help GC
    failed = false;
    return interrupted;
}
```

来分析上面的主要流程

1. 通过node.predecessor()获取前继节点。predecessor()就是返回node的前继节点，若对此有疑惑可以查看下面关于Node类的介绍。

2.  p == head && tryAcquire(arg)

   首先，判断前继节点是不是CHL表头。如果是的话，则通过tryAcquire()尝试获取锁。 其实，这样做的目的是为了“让当前线程获取锁”，但是为什么需要先判断`p==head`呢？理解这个对理解公平锁的机制很重要，因为这么做的原因就是为了保证公平性！

   前面，我们在shouldParkAfterFailedAcquire()我们判断当前线程是否需要阻塞；当前线程阻塞的话，会调用parkAndCheckInterrupt()来阻塞线程。当线程被解除阻塞的时候，我们会返回线程的中断状态。而线程被阻唤醒，可能是由于线程被中断，也可能是由于其它线程调用了该线程的unpark()函数。

   再回到`p==head`这里。如果当前线程是因为其它线程调用了unpark()函数而被唤醒，那么唤醒它的线程，应该是它的前继节点所对应的线程(关于这一点，后面在释放锁的过程中会看到)。 
   此时，再来理解`p==head`就很简单了：当前继节点是CLH队列的头节点，并且它释放锁之后；就轮到当前节点获取锁。然后，当前节点通过tryAcquire()获取锁；获取成功的话，通过setHead(node)设置当前节点为头节点，并返回。
   总之，如果前继节点调用unpark()唤醒了当前线程并且前继节点是CLH表头，此时就是满足`p==head`，也就是符合公平性原则的。否则，如果当前线程是因为线程被中断而唤醒，那么显然就不是公平了。这就是为什么说p==head就是保证公平性！

从上面可以看出公平锁保证，获取锁一定按照FIFO的序列来获取锁，而具体保证的获取的公平性是在这一步体现的。

#### cancelAcquire

上面已经说完了所有正常情况下锁的获取，但是如果出现异常，如何处理当前线程对应的节点还没有说，也就是对应上面acquireQueued中的这段代码

```java
finally {
    // 如果获取失败，则取消当前节点锁的获取
    if (failed)
        cancelAcquire(node);
}
```

下面是cancelAcquire的源码

```java
private void cancelAcquire(Node node) {
    // 如果节点为空，则忽略处理
    if (node == null)
        return;

    // 设置界定啊对应的线程为空
    node.thread = null;
   
    // 跳过所有取消的前继节点，找到第一个非取消的前继节点
    Node pred = node.prev;
    while (pred.waitStatus > 0)
        node.prev = pred = pred.prev;

    // 获取pred节点的后继节点
    Node predNext = pred.next;

    // 设置当前节点的状态为取消状态，后面正在插入的节点可以看见，然后跳过当前节点
    node.waitStatus = Node.CANCELLED;

        // 如果节点为tail，则设置tail为pred
    if (node == tail && compareAndSetTail(node, pred)) {
        // 设置pred的后继节点为null
        compareAndSetNext(pred, predNext, null);
    } else {
        int ws;
        //设置前继节点的状态为SIGNAL，表示在释放锁时需要唤醒后继节点
        if (pred != head &&
            ((ws = pred.waitStatus) == Node.SIGNAL ||
             (ws <= 0 && compareAndSetWaitStatus(pred, ws, Node.SIGNAL))) &&
            pred.thread != null) {
            // 设置pred的后继节点为node.next节点
            Node next = node.next;
            if (next != null && next.waitStatus <= 0)
                compareAndSetNext(pred, predNext, next);
        } else {
            // 上面操作失败，说明有竞争，则唤醒当前节点的后继节点
            // 由后继节点来处理找到一个合适的前继节点，因为node节点的状态
            // 为取消状态，所以后继节点被唤醒后，会跳过此节点找到合适的前继节点
            unparkSuccessor(node);
        }
		
        // 消除节点的引用，
        node.next = node; // help GC
    }
}
```

上面主要流程还是比较清晰，主要是用来处理线程的异常退出设置该线程在CLH等待队列中的节点。主要流程如下

1. 节点为空，忽略处理。
2. 找到node的没有被取消的前继节点。
3. 设置当前节点的状态为取消状态。
4. 如果node是tail节点，则直接替换tail为pred节点。然后设置pred的后继节点为空。
5. 如果不是，则设置pred的节点的状态为SIGNAL，如果设置成功，则设置pred节点的后继节点为node.next节点。
6. 如果上面操作失败，则唤醒node的后继节点，后继节点会自己找到一个合适的前继节点。同时会忽略当前节点，因为此节点的状态已经被设置成取消状态。

从这不得不佩服Dou Lea大师，在取消时如果竞争，就唤醒后继节点，让后继节点来帮助取消此节点。

### selfInterrupt()

前面已经将获取锁的所有流程，现在就剩最后一步。如果获取锁的线程被中断过，则需要调用selfInterrupt使当前线程产生一个终端信号。


```java
private static void selfInterrupt() {
    Thread.currentThread().interrupt();
}
```

代码很简单，就是当前线程自己产生一个中断信号，但是为什么要这样做呢？

这必须结合acquireQueued()进行分析。如果在acquireQueued()中，当前线程被中断过，则执行selfInterrupt()；否则不会执行。

在acquireQueued()中，即使是线程在阻塞状态被中断唤醒而获取到cpu执行权利；但是，如果该线程的前面还有其它等待锁的线程，根据公平性原则，该线程依然无法获取到锁。它会再次阻塞！ 该线程再次阻塞，直到该线程被它的前面等待锁的线程锁唤醒；线程才会获取锁，然后真正执行起来！
也就是说，在该线程成功获取锁并真正执行起来之前，它的中断会被忽略并且中断标记会被清除！ 因为在parkAndCheckInterrupt()中，我们线程的中断状态时调用了Thread.interrupted()。该函数不同于Thread的isInterrupted()函数，isInterrupted()仅仅返回中断状态，而interrupted()在返回当前中断状态之后，还会清除中断状态。 正因为之前的中断状态被清除了，所以这里需要调用selfInterrupt()重新产生一个中断！

还记得前面说过acquire函数是不响应中断，原因就是在这里。

### 获取公平锁总结

再回过头看看acquire()函数，它最终的目的是获取锁！

```java
public final void acquire(int arg) {
    if (!tryAcquire(arg) &&
        acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
        selfInterrupt();
}
```

1. 先是通过tryAcquire()尝试获取锁。获取成功的话，直接返回；尝试失败的话，再通过acquireQueued()获取锁。
2. 尝试失败的情况下，会先通过addWaiter()来将当前线程加入到CLH队列末尾；然后调用acquireQueued()，在CLH队列中排序等待获取锁，在此过程中，线程处于休眠状态。直到获取锁了才返回。 如果在休眠等待过程中被中断过，则调用selfInterrupt()来自己产生一个中断。

## 公平锁的释放

是通过unlock函数来释放锁，源码如下：

```java
public void unlock() {
    // 释放锁
	sync.release(1);
}

// AQS 中的代码
// 释放锁
public final boolean release(int arg) {
    // 尝试释放锁，如果释放成功
    if (tryRelease(arg)) {
        // 尝试唤醒后继节点
        Node h = head;
        if (h != null && h.waitStatus != 0)
            unparkSuccessor(h);
        return true;
    }
    return false;
}
```

从上面可以看出，释放的主要流程是在release中，其中参数1表示的含义和获取锁函数acquire(1)是一样的。由于公平锁是可重入的，所以对于通过一个线程可能会获取多次锁，每一次锁的状态值都会加1，相应的释放时都需要减1。下面总结上面的流程

1. 尝试释放锁，如果释放成功，从当前节点的状态值来判断是否需要唤醒后继的节点，如果需要，则调用unparkSuccessor来唤醒。
2. 如果释放失败，则直接返回false。

#### tryRelease()

这个函数的实现是在ReentrantLock中的Synch类中实现，源码如下：

```java
protected final boolean tryRelease(int releases) {
    //c是本次释放之后的状态
    int c = getState() - releases;
    // 如果当前线程不是锁的持有者，抛出异常
    if (Thread.currentThread() != getExclusiveOwnerThread())
        throw new IllegalMonitorStateException();
    // 判断是否释放成功
    boolean free = false;
    // 锁可以彻底释放，则设置锁的持有者为null，即锁是可获取状态
    if (c == 0) {
        free = true;
        setExclusiveOwnerThread(null);
    }
    // 设置当前锁的状态
    setState(c);
    return free;
}
```

tryRelease是尝试释放锁，主要流程如下：

1. 首先判断锁的持有者是否是当前线程，如果不是则抛出异常。
2.  如果当前线程在本次释放锁操作之后，对锁的拥有状态是0(即，当前线程彻底释放该锁)，则设置锁的持有者为null，即锁是可获取状态。同时，更新当前线程的锁的状态为0。

### unparkSuccessor()

如果锁被成功释放之后，需要调用此函数来唤醒后继阻塞的线程。根据CLH队列的FIFO规则，当前线程(即已经获取锁的线程)肯定是head；如果CLH队列非空的话，则唤醒锁的下一个等待线程。

```java
private void unparkSuccessor(Node node) {
   	 // 获取当前线程对应的状态值
    int ws = node.waitStatus;
    // 如果小于0，则设置状态值为0
    if (ws < 0)
        compareAndSetWaitStatus(node, ws, 0);


    // 获取后继节点，
    Node s = node.next;
    // 如果节点为空或者节点的状态值大于0，说明是被取消的节点，
    // 则需要循环判断找到第一个小于0的节点
    if (s == null || s.waitStatus > 0) {
        s = null;
        // 这里是从尾往头来找，直到遍历完所有的节点，找到第一个非取消的节点
        for (Node t = tail; t != null && t != node; t = t.prev)
            if (t.waitStatus <= 0)
                s = t;
    }
    // 如果s不为空，唤醒节点对应的线程。
    if (s != null)
        LockSupport.unpark(s.thread);
}
```

释放锁的过程相对获取锁的过程比较简单。释放锁时，主要进行的操作，是更新当前线程对应的锁的状态。如果当前线程对锁已经彻底释放，则设置锁的持有线程为null，设置当前线程的状态为空，然后唤醒后继线程。