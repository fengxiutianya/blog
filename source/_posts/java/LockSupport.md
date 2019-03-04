title: LockSupport
tags:
  - JUC
categories:
  - java
author: zhangke
abbrlink: 34693
date: 2018-12-13 15:21:00
---
---
# LockSupport

### 概述

1. 用法简介
2. 源码分析
3. 底层实现原理

### 1. 用法简介

LockSupport是用来创建锁和其他同步类的基本**线程阻塞**原语。LockSupport 提供park()和unpark()方法实现阻塞线程和解除线程阻塞，LockSupport和每个使用它的线程都与一个许可(permit)关联。permit相当于1，0的开关，默认是0，调用一次unpark就加1变成1，调用一次park会消费permit, 也就是将1变成0，同时park立即返回。再次调用park会变成block（因为permit为0了，会阻塞在这里，直到permit变为1）, 这时调用unpark会把permit置为1。每个线程都有一个相关的permit, permit最多只有一个，重复调用unpark也不会积累。

park()和unpark()不会有 “Thread.suspend和Thread.resume所可能引发的死锁” 问题，由于许可的存在，调用 park 的线程和另一个试图将其 unpark 的线程之间的竞争将保持活性。

如果调用线程被中断，则park方法会返回。同时park也拥有可以设置超时时间的版本。
<!-- more -->
需要特别注意的一点：**park 方法还可以在其他任何时间“毫无理由”地返回，因此通常必须在重新检查返回条件的循环里调用此方法**。从这个意义上说，park 是“忙碌等待”的一种优化，它不会浪费这么多的时间进行自旋，但是必须将它与 unpark 配对使用才更高效。

官方推介的使用方式如下

```java
while(!canprocess()){
    ....
    LockSupport.park(this);
}
```



三种形式的 park 还各自支持一个 blocker 对象参数。此对象在线程受阻塞时被记录，以允许监视工具和诊断工具确定线程受阻塞的原因。（这样的工具可以使用方法 getBlocker(java.lang.Thread) 访问 blocker。）建议最好使用这些形式，而不是不带此参数的原始形式。在锁实现中提供的作为 blocker 的普通参数是 this。
看下线程dump的结果来理解blocker的作用。

![线程dump结果对比](https://segmentfault.com/img/bVJuIP?w=783&h=375)

从线程dump结果可以看出：
有blocker的可以传递给开发人员更多的现场信息，可以查看到当前线程的阻塞对象，方便定位问题。所以java6新增加带blocker入参的系列park方法，替代原有的park方法。

#### demo1

看一个Java docs中的示例用法：一个先进先出非重入锁类的框架

```java
class FIFOMutex {
    private final AtomicBoolean locked = new AtomicBoolean(false);
    private final Queue<Thread> waiters
      = new ConcurrentLinkedQueue<Thread>();
 
    public void lock() {
      boolean wasInterrupted = false;
      Thread current = Thread.currentThread();
      waiters.add(current);
 
      // Block while not first in queue or cannot acquire lock
      while (waiters.peek() != current ||
             !locked.compareAndSet(false, true)) {
        LockSupport.park(this);
        if (Thread.interrupted()) // ignore interrupts while waiting
          wasInterrupted = true;
      }

      waiters.remove();
      if (wasInterrupted)          // reassert interrupt status on exit
        current.interrupt();
    }
 
    public void unlock() {
      locked.set(false);
      LockSupport.unpark(waiters.peek());
    }
  }}
  
  //具体使用
  public class LockSupportDemo {
    public static void main(String[] args) throws InterruptedException {
        final FIFOMutex lock = new FIFOMutex();

        for (int i = 0; i < 10; i++) {
            new Thread(generateTask(lock, String.valueOf(i), list)).start();
        }
        countDownLatch.await();
        System.out.println(list);
    }


    static CountDownLatch countDownLatch = new CountDownLatch(10);

    static List<String> list = new ArrayList<>();


    private static Runnable generateTask(final FIFOMutex lock, 
    				final String taskId, final List<String> list) {
        return () -> {
            lock.lock();
            try {
                Thread.sleep(300);
                list.add(taskId);

            } catch (Exception e) {

            }
            String s = list.toString();
            System.out.println(String.format("Thread %s Completed %s", taskId, s));
            lock.unLock();
            countDownLatch.countDown();
        };
    }
}
```

运行结果

```
Thread 0 Completed [0]
Thread 1 Completed [0, 1]
Thread 2 Completed [0, 1, 2]
Thread 3 Completed [0, 1, 2, 3]
Thread 4 Completed [0, 1, 2, 3, 4]
Thread 5 Completed [0, 1, 2, 3, 4, 5]
Thread 6 Completed [0, 1, 2, 3, 4, 5, 6]
Thread 7 Completed [0, 1, 2, 3, 4, 5, 6, 7]
Thread 8 Completed [0, 1, 2, 3, 4, 5, 6, 7, 8]
Thread 9 Completed [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
```

从结果可以看出，运行结果可以看出，确实是先进先出类型的锁，同时也验证了没有俩个线程同时获取修改list的时机，因为如果同时修改List回抛出异常，这里没有。从侧面验证了锁的正确性

#### demo2 

验证一下，在park之前多次调用unpark，是否会累加

```
public class LockSupportStudy2 {

    public static void main(String[] args) {
        //在park之前不管有多少个unpark，都只能释放一个park
        LockSupport.unpark(Thread.currentThread());
        LockSupport.unpark(Thread.currentThread());
        System.out.println("暂停线程");
        LockSupport.park();
        System.out.println("线程继续");
        LockSupport.park();
        System.out.println("线程继续");
    }
}
```

运行结果

```
暂停线程
线程继续
。。。。。
```

从实验结果可以看出，不管在park之前调用了多少次的unpark，只会唤醒一次相应的线程阻塞。

另外这个实验可以看出park和unpark的先后顺序是不重要的，因此park()和unpark()不会有 “Thread.suspend和Thread.resume所可能引发的死锁” 问题，由于许可的存在，调用 park 的线程和另一个试图将其 unpark 的线程之间的竞争将保持活性。

### 2. 源码分析

1. LockSupport中主要的两个成员变量：

```

    private static final sun.misc.Unsafe UNSAFE;
    private static final long parkBlockerOffset;
```

unsafe:全名sun.misc.Unsafe可以直接操控内存，被JDK广泛用于自己的包中，如java.nio和java.util.concurrent。但是不建议在生产环境中使用这个类。因为这个API十分不安全、不轻便、而且不稳定。
LockSupport的方法底层都是调用Unsafe的方法实现。

再来看parkBlockerOffset:
parkBlocker就是第一部分说到的用于记录线程被谁阻塞的，用于线程监控和分析工具来定位原因的，可以通过LockSupport的getBlocker获取到阻塞的对象。

```
 static {
        try {
            UNSAFE = sun.misc.Unsafe.getUnsafe();
            Class<?> tk = Thread.class;
            parkBlockerOffset = UNSAFE.objectFieldOffset
                (tk.getDeclaredField("parkBlocker"));
        } catch (Exception ex) { throw new Error(ex); }
 }
```

从这个静态语句块可以看的出来，先是通过反射机制获取Thread类的parkBlocker字段对象。然后通过sun.misc.Unsafe对象的objectFieldOffset方法获取到parkBlocker在内存里的偏移量，parkBlockerOffset的值就是这么来的.

JVM的实现可以自由选择如何实现Java对象的“布局”，也就是在内存里Java对象的各个部分放在哪里，包括对象的实例字段和一些元数据之类。 sun.misc.Unsafe里关于对象字段访问的方法把对象布局抽象出来，它提供了objectFieldOffset()方法用于获取某个字段相对 Java对象的“起始地址”的偏移量，也提供了getInt、getLong、getObject之类的方法可以使用前面获取的偏移量来访问某个Java 对象的某个字段。

为什么要用偏移量来获取对象？干吗不要直接写个get，set方法。多简单？
仔细想想就能明白，这个parkBlocker就是在线程处于阻塞的情况下才会被赋值。线程都已经阻塞了，如果不通过这种内存的方法，而是直接调用线程内的方法，线程是不会回应调用的。

2.LockSupport的方法：

```
public static  Object getBlocker(Thread t)
public static  void park()
public static  void park(Object blocker)
public static  void parkNanos(long nanos)
public static  void parkNanos(Object blocker, long nanos)
public static  void parkUntil(long deadline)
public static  void parkUntil(Object blocker, long deadline)
```



可以看到，LockSupport中主要是park和unpark方法以及设置和读取parkBlocker方法。

```
 private static void setBlocker(Thread t, Object arg) {
        // Even though volatile, hotspot doesn't need a write barrier here.
        UNSAFE.putObject(t, parkBlockerOffset, arg);
  }
```

对给定线程t的parkBlocker赋值。

```
    public static Object getBlocker(Thread t) {
        if (t == null)
            throw new NullPointerException();
        return UNSAFE.getObjectVolatile(t, parkBlockerOffset);
    }
  
```

从线程t中获取它的parkBlocker对象，即返回的是阻塞线程t的Blocker对象。

接下来主查两类方法，一类是阻塞park方法，一类是解除阻塞unpark方法

**阻塞线程**

- park()

```
public static void park() {
        UNSAFE.park(false, 0L);
}
```

调用native方法阻塞当前线程。

- parkNanos(long nanos)

```
public static void parkNanos(long nanos) {
        if (nanos > 0)
            UNSAFE.park(false, nanos);
}
```

阻塞当前线程，最长不超过nanos纳秒，返回条件在park()的基础上增加了超时返回。

- parkUntil(long deadline)

```
public static void parkUntil(long deadline) {
  UNSAFE.park(true, deadline);
}
```

阻塞当前线程，知道deadline时间（deadline - 毫秒数）。

JDK1.6引入这三个方法对应的拥有Blocker版本。

- park(Object blocker)

```
public static void park(Object blocker) {
  Thread t = Thread.currentThread();
  setBlocker(t, blocker);
  UNSAFE.park(false, 0L);
  setBlocker(t, null);
}
```

1) 记录当前线程等待的对象（阻塞对象）；
2) 阻塞当前线程；
3) 当前线程等待对象置为null。

- parkNanos(Object blocker, long nanos)

```
public static void parkNanos(Object blocker, long nanos) {
  if (nanos > 0) {
      Thread t = Thread.currentThread();
      setBlocker(t, blocker);
      UNSAFE.park(false, nanos);
      setBlocker(t, null);
  }
}
```

阻塞当前线程，最长等待时间不超过nanos毫秒，同样，在阻塞当前线程的时候做了记录当前线程等待的对象操作。

- parkUntil(Object blocker, long deadline)

```
public static void parkUntil(Object blocker, long deadline) {
  Thread t = Thread.currentThread();
  setBlocker(t, blocker);
  UNSAFE.park(true, deadline);
  setBlocker(t, null);
}
```

阻塞当前线程直到deadline时间，相同的，也做了阻塞前记录当前线程等待对象的操作。

**唤醒线程**

- unpark(Thread thread)

```
public static void unpark(Thread thread) {
  if (thread != null)
      UNSAFE.unpark(thread);
}
```

唤醒处于阻塞状态的线程Thread。

### 3. 底层实现原理

从LockSupport源码可以看出，park和unpark的实现都是调用Unsafe.park和Unsafe.unpark，因此只要找到这俩个的底层实现原理，就可以明白park和unpark的底层实现。

#### HotSpot 里 park/unpark 的实现

每个 java 线程都有一个 Parker 实例，Parker 类是这样定义的：

```
class Parker : public os::PlatformParker {
private:
  volatile int _counter ;
  ...
public:
  void park(bool isAbsolute, jlong time);
  void unpark();
  ...
}
class PlatformParker : public CHeapObj<mtInternal> {
  protected:
    pthread_mutex_t _mutex [1] ;
    pthread_cond_t  _cond  [1] ;
    ...
}
```

可以看到 Parker 类实际上用 Posix 的 mutex，condition 来实现的。

在 Parker 类里的_counter 字段，就是用来记录所谓的 “许可” 的。

当调用 park 时，先尝试直接能否直接拿到 “许可”，即_counter>0 时，如果成功，则把_counter 设置为 0, 并返回：

```
void Parker::park(bool isAbsolute, jlong time) {
  // Ideally we'd do something useful while spinning, such
  // as calling unpackTime().
  // Optional fast-path check:
  // Return immediately if a permit is available.
  // We depend on Atomic::xchg() having full barrier semantics
  // since we are doing a lock-free update to _counter.
  if (Atomic::xchg(0, &_counter) > 0) return;
```

如果不成功，则构造一个 ThreadBlockInVM，然后检查_counter 是不是 > 0，如果是，则把_counter 设置为 0，unlock mutex 并返回：

```
  ThreadBlockInVM tbivm(jt);
  if (_counter > 0)  { // no wait needed
    _counter = 0;
    status = pthread_mutex_unlock(_mutex);
```

否则，再判断等待的时间，然后再调用 pthread_cond_wait 函数等待，如果等待返回，则把_counter 设置为 0，unlock mutex 并返回

```
  if (time == 0) {
    status = pthread_cond_wait (_cond, _mutex) ;
  }
  _counter = 0 ;
  status = pthread_mutex_unlock(_mutex) ;
  assert_status(status == 0, status, "invariant") ;
  OrderAccess::fence();
```

当 unpark 时，则简单多了，直接设置_counter 为 1，再 unlock mutext 返回。如果_counter 之前的值是 0，则还要调用 pthread_cond_signal 唤醒在 park 中等待的线程

```
void Parker::unpark() {
  int s, status ;
  status = pthread_mutex_lock(_mutex);
  assert (status == 0, "invariant") ;
  s = _counter;
  _counter = 1;
  if (s < 1) {
     if (WorkAroundNPTLTimedWaitHang) {
        status = pthread_cond_signal (_cond) ;
        assert (status == 0, "invariant") ;
        status = pthread_mutex_unlock(_mutex);
        assert (status == 0, "invariant") ;
     } else {
        status = pthread_mutex_unlock(_mutex);
        assert (status == 0, "invariant") ;
        status = pthread_cond_signal (_cond) ;
        assert (status == 0, "invariant") 
     }
  } else {
    pthread_mutex_unlock(_mutex);
    assert (status == 0, "invariant") ;
  }
}
```

简而言之，是用 mutex 和 condition 保护了一个_counter 的变量，当 park 时，这个变量置为了 0，当 unpark 时，这个变量置为 1。

值得注意的是在 park 函数里，调用 pthread_cond_wait 时，并没有用 while 来判断，所以 posix condition 里的 "Spurious wakeup" 一样会传递到上层 Java 的代码里，这也是官方为什么推介使用while方式的原因。

关于 "Spurious wakeup"，参考这篇文章：[Why does pthread_cond_wait have spurious wakeups?](https://stackoverflow.com/questions/8594591/why-does-pthread-cond-wait-have-spurious-wakeups)

不过在看这篇文章之前，最好看看《Unix环境高级编程》这本书第11章节

```
  if (time == 0) {
    status = pthread_cond_wait (_cond, _mutex) ;
  }
```

这也就是为什么 Java dos 里提到，当下面三种情况下 park 函数会返回：

- Some other thread invokes unpark with the current thread as the target; or
- Some other thread interrupts the current thread; or
- **The call spuriously (that is, for no reason) returns.**

相关的实现代码在：

http://hg.openjdk.java.net/jdk7/jdk7/hotspot/file/81d815b05abb/src/share/vm/runtime/park.hpp
http://hg.openjdk.java.net/jdk7/jdk7/hotspot/file/81d815b05abb/src/share/vm/runtime/park.cpp
http://hg.openjdk.java.net/jdk7/jdk7/hotspot/file/81d815b05abb/src/os/linux/vm/os_linux.hpp
http://hg.openjdk.java.net/jdk7/jdk7/hotspot/file/81d815b05abb/src/os/linux/vm/os_linux.cp

### 参考

1. [浅谈Java并发编程系列（八）—— LockSupport原理剖析](https://segmentfault.com/a/1190000008420938)
2. [并行编程之条件变量（posix condition variables）](https://blog.csdn.net/hengyunabc/article/details/27969613)
3. [Java的LockSupport.park()实现分析](https://blog.csdn.net/hengyunabc/article/details/28126139)