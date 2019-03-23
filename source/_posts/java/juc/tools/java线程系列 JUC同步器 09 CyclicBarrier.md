---
title: java线程系列 JUC同步器09 CyclicBarrier
tags:
  - 同步器
categories:
  - java
  - juc
  - sync同步器
abbrlink: c05d7ca
date: 2019-03-19 11:32:00
---
字面意思回环栅栏，通过它可以实现让一组线程等待至某个状态之后再全部同时执行。叫做回环是因为当所有等待线程都被释放以后，CyclicBarrier可以被重用。我们暂且把这个状态就叫做barrier，当调用await()方法之后，线程就处于barrier了。


可以看下面这个图来理解下:
一共4个线程A、B、C、D，它们到达栅栏的顺序可能各不相同。当A、B、C到达栅栏后，由于没有满足总数4的要求，所以会一直等待，当线程D到达后，栅栏才会放行。

![upload successful](/images/pasted-306.png)
<!-- more -->

## 使用案例

假若有若干个线程都要进行写数据操作，并且只有所有线程都完成写数据操作之后，这些线程才能继续做后面的事情，此时就可以利用CyclicBarrier了：

源码如下：

```java
public class Test {
    public static void main(String[] args) {
        int N = 4;
        CyclicBarrier barrier  = new CyclicBarrier(N);
        for(int i=0;i<N;i++)
            new Writer(barrier).start();
    }
    static class Writer extends Thread{
        private CyclicBarrier cyclicBarrier;
        public Writer(CyclicBarrier cyclicBarrier) {
            this.cyclicBarrier = cyclicBarrier;
        }

        @Override
        public void run() {
            System.out.println("线程"+Thread.currentThread().getName()+"正在写入数据...");
            try {
                Thread.sleep(5000);      //以睡眠来模拟写入数据操作
                System.out.println("线程"+Thread.currentThread().getName()
                                   +"写入数据完毕，等待其他线程写入完毕");
                cyclicBarrier.await();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }catch(BrokenBarrierException e){
                e.printStackTrace();
            }
            System.out.println("所有线程写入完毕，继续处理其他任务...");
        }
    }
}
```

执行结果：

```java
线程Thread-0正在写入数据...
线程Thread-3正在写入数据...
线程Thread-2正在写入数据...
线程Thread-1正在写入数据...
线程Thread-2写入数据完毕，等待其他线程写入完毕
线程Thread-0写入数据完毕，等待其他线程写入完毕
线程Thread-3写入数据完毕，等待其他线程写入完毕
线程Thread-1写入数据完毕，等待其他线程写入完毕
所有线程写入完毕，继续处理其他任务...
所有线程写入完毕，继续处理其他任务...
所有线程写入完毕，继续处理其他任务...
所有线程写入完毕，继续处理其他任务...
```

从上面输出结果可以看出，每个写入线程执行完写数据操作之后，就在等待其他线程写入操作完毕。当所有线程线程写入操作完毕之后，所有线程就继续进行后续的操作了。

如果说想在所有线程写入操作完之后，进行额外的其他操作可以为CyclicBarrier提供Runnable参数：

```java
public class Test {
    public static void main(String[] args) {
        int N = 4;
        CyclicBarrier barrier  = new CyclicBarrier(N,new Runnable() {
            @Override
            public void run() {
                System.out.println("当前线程"+Thread.currentThread().getName());   
            }
        });
         
        for(int i=0;i<N;i++)
            new Writer(barrier).start();
    }
    static class Writer extends Thread{
        private CyclicBarrier cyclicBarrier;
        public Writer(CyclicBarrier cyclicBarrier) {
            this.cyclicBarrier = cyclicBarrier;
        }
 
        @Override
        public void run() {
            System.out.println("线程"+Thread.currentThread().getName()+"正在写入数据...");
            try {
                Thread.sleep(5000);      //以睡眠来模拟写入数据操作
                System.out.println("线程"+Thread.currentThread().getName()
                                   +"写入数据完毕，等待其他线程写入完毕");
                cyclicBarrier.await();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }catch(BrokenBarrierException e){
                e.printStackTrace();
            }
            System.out.println("所有线程写入完毕，继续处理其他任务...");
        }
    }
}
```

运行结果：

```
线程Thread-0正在写入数据...
线程Thread-1正在写入数据...
线程Thread-2正在写入数据...
线程Thread-3正在写入数据...
线程Thread-0写入数据完毕，等待其他线程写入完毕
线程Thread-1写入数据完毕，等待其他线程写入完毕
线程Thread-2写入数据完毕，等待其他线程写入完毕
线程Thread-3写入数据完毕，等待其他线程写入完毕
当前线程Thread-3
所有线程写入完毕，继续处理其他任务...
所有线程写入完毕，继续处理其他任务...
所有线程写入完毕，继续处理其他任务...
所有线程写入完毕，继续处理其他任务...
```

另外，只要正在Barrier上等待的任一线程抛出了异常，那么Barrier就会认为肯定是凑不齐所有线程了，就会将栅栏置为损坏（Broken）状态，并传播**BrokenBarrierException**给其它所有正在等待（await）的线程。我们来对上面的例子做个改造，模拟下异常情况：

```java
package JUC.tools;

import java.util.concurrent.BrokenBarrierException;
import java.util.concurrent.CyclicBarrier;

/**************************************
 *      Author : zhangke
 *      Date   : 2019-03-19 23:10
 *      email  : 398757724@qq.com
 *      Desc   : 
 ***************************************/
public class CyclicBarrierTest2 {
    public static void main(String[] args) throws InterruptedException {
        int N = 4;
        CyclicBarrier barrier = new CyclicBarrier(N);

        for (int i = 0; i < N; i++) {
            Writer writer = new Writer(barrier);
            writer.start();
            if (i == 2) {
                writer.interrupt();
            }
        }
        Thread.sleep(2000);
        System.out.println("Barrier是否损坏：" + barrier.isBroken());
    }


    static class Writer extends Thread {
        private CyclicBarrier cyclicBarrier;


        public Writer(CyclicBarrier cyclicBarrier) {
            this.cyclicBarrier = cyclicBarrier;
        }


        @Override
        public void run() {
            System.out.println("线程" + Thread.currentThread().getName()
                               + "正在写入数据...");
            try {
                System.out.println("线程" + Thread.currentThread().getName()
                        + "写入数据完毕，等待其他线程写入完毕");
                cyclicBarrier.await();
            } catch (InterruptedException e) {
                System.out.println("线程" + Thread.currentThread().getName()
                        + ": 被中断");
            } catch (BrokenBarrierException e) {
                System.out.println("线程" + Thread.currentThread().getName()
                        + ":抛出BrokenBarrierException");
            }
        }
    }
}

```

运行结果：

```
线程Thread-1正在写入数据...
线程Thread-2正在写入数据...
线程Thread-1写入数据完毕，等待其他线程写入完毕
线程Thread-0正在写入数据...
线程Thread-0写入数据完毕，等待其他线程写入完毕
线程Thread-2写入数据完毕，等待其他线程写入完毕
线程Thread-3正在写入数据...
线程Thread-3写入数据完毕，等待其他线程写入完毕
线程Thread-3:抛出BrokenBarrierException
线程Thread-2: 被中断
线程Thread-0:抛出BrokenBarrierException
线程Thread-1:抛出BrokenBarrierException
Barrier是否损坏：true
```

这段代码，模拟了中断线程3的情况，从输出可以看到，线程0、1、2首先到达Brrier等待。
然后线程3到达，由于之前设置了中断标志位，所以线程3抛出中断异常，导致Barrier损坏，此时所有已经在栅栏等待的线程（0、1、2）都会抛出**BrokenBarrierException**异常。
此时，即使再有其它线程到达栅栏（线程3），都会抛出**BrokenBarrierException**异常。

> **注意：**使用`CyclicBarrier`时，对异常的处理一定要小心，比如线程在到达栅栏前就抛出异常，此时如果没有重试机制，其它已经到达栅栏的线程会一直等待（因为没有还没有满足总数），最终导致程序无法继续向下执行。

## 源码分析

![upload successful](/images/pasted-305.png)

CyclicBarrier是通过ReentrantLock(独占锁)和Condition来实现的。下面，我们分析CyclicBarrier中俩个个核心函数: 构造函数和await()作出分析。

首先看看下面要用的重要属性：

```java
 private static class Generation {
        boolean broken = false;
 }

// 保证线程阻塞的锁
private final ReentrantLock lock = new ReentrantLock();

// 用于设置等待的条件队列
private final Condition trip = lock.newCondition();

// 栅栏开启需要到达的线程数
private final int parties;

// 当线程都到达后运行的命令
private final Runnable barrierCommand;

// 当前轮次运行的状态
private Generation generation = new Generation();

// 剩余未到达的线程数
private int count;
```

### 构造函数

CyclicBarrier的构造函数共2个：CyclicBarrier 和 CyclicBarrier(int parties, Runnable barrierAction)，第1个构造函数是调用第2个构造函数来实现，下面第2个构造函数的源码：

```java
public CyclicBarrier(int parties, Runnable barrierAction) {
    if (parties <= 0) 
        throw new IllegalArgumentException();
    // parties表示必须同时到达barrier的线程个数。
    this.parties = parties;
    // count表示处在等待状态的线程个数。
    this.count = parties;
    // barrierCommand表示parties个线程到达barrier时，会执行的动作。
    this.barrierCommand = barrierAction;
}
```

### await()

await这个函数等待所有的barrier都到达屏障之后，会释放所有等待的阻塞线程。另外还有一个等待函数await(long timeout, TimeUnit unit)，这个函数会在等待一定时间之后，如果线程还是阻塞，则抛出超时错误，而前面那个等待函数会一直等，没有超时这个概念。俩者的实现是差不多，实现源码如下

```java
public int await() throws InterruptedException, BrokenBarrierException {
    try {
        return dowait(false, 0L);
    } catch (TimeoutException toe) {
        throw new Error(toe); // cannot happen;
    }
}
public int await(long timeout, TimeUnit unit)
    throws InterruptedException,BrokenBarrierException,
					TimeoutException {
    return dowait(true, unit.toNanos(timeout));
}
```

从上面可以看出，俩者的实现都是通过dowait来实现的，下面来一起看看这个函数：

```java
private int dowait(boolean timed, long nanos)
    throws InterruptedException, BrokenBarrierException,
           TimeoutException {
               
    final ReentrantLock lock = this.lock;
    // 获取独占锁(lock)
    lock.lock();
    try {
        // 保存当前的generation
        final Generation g = generation;

        // 若当前generation已损坏，则抛出异常。
        if (g.broken)
            throw new BrokenBarrierException();

        // 如果当前线程被中断，则通过breakBarrier()终止CyclicBarrier，
        // 唤醒CyclicBarrier中所有等待线程。
        if (Thread.interrupted()) {
            breakBarrier();
            throw new InterruptedException();
        }

       // 将count计数器-1
       int index = --count;
       // 如果index=0，则意味着有parties个线程到达barrier。
       if (index == 0) {  // tripped
           boolean ranAction = false;
           try {
               // 如果barrierCommand不为null，则执行该动作。
               final Runnable command = barrierCommand;
               if (command != null)
                   command.run();
               ranAction = true;
               // 唤醒所有等待线程，并更新generation。
               nextGeneration();
               return 0;
           } finally {
               if (!ranAction)
                   breakBarrier();
           }
       }

        // 当前线程一直阻塞，直到有parties个线程到达barrier”或当前线程被中断或超时这3者之一发生，
        // 当前线程才继续执行。
        for (;;) {
            try {
                // 如果不是超时等待，则调用awati()进行等待；
                // 否则，调用awaitNanos()进行等待。
                if (!timed)
                    trip.await();
                else if (nanos > 0L)
                    nanos = trip.awaitNanos(nanos);
            } catch (InterruptedException ie) {
                // 如果等待过程中，线程被中断，则执行下面的函数。
                if (g == generation && !g.broken) {
                    breakBarrier();
                    throw ie;
                } else {
                    Thread.currentThread().interrupt();
                }
            }

            // 如果当前generation已经损坏，则抛出异常。
            if (g.broken)
                throw new BrokenBarrierException();

            // 如果generation已经换代，则返回index。
            if (g != generation)
                return index;

            // 如果是超时等待，并且时间已到，
            // 则通过breakBarrier()终止CyclicBarrier，唤醒CyclicBarrier中所有等待线程。
            if (timed && nanos <= 0L) {
                breakBarrier();
                throw new TimeoutException();
            }
        }
    } finally {
        // 释放独占锁(lock)
        lock.unlock();
    }
}
```

这里总结一下上面的流程：

1. 首先获取独占锁，这里是为了保证线程安全，因为会有多个线程可能同时来竞争。
2. 判断当前Generation是否已经损坏，如果true，则调用breakBarrier释放所有的线程。
3. 判断当前count是否等于0，如果是，唤醒所有等待线程，并更新generation。
4. 如果以上都不是，则进入循环，来执行下面的步骤
   1. 根据是否是有限时间阻塞，调用不同的阻塞函数。如果在等待过程中被中断，则会调用breakBarrier唤醒所有的线程，并抛出异常。注意这里使用的是条件等待队列，使用这个原因是所有线程可以被一次全部唤醒。
   2. 判断当前generation是否发生改变，如果是，则抛出损坏异常。
   3. 如果超时等待，则唤醒所有的线程，并抛出超时异常
   4. 循环上面的三步，直到退出循环。

从上面可以看出，直到执行n次await函数之后，才会使得所以阻塞的异常被唤醒。先前所有的线程都会被阻塞。下面分别解释上面的每一步。

1. generation是CyclicBarrier的一个成员遍历，它的定义如下：

   ```java
   private Generation generation = new Generation();
   
   private static class Generation {
       boolean broken = false;
   }
   ```

   在CyclicBarrier中，同一批的线程属于同一代，即同一个Generation；CyclicBarrier中通过generation对象，记录属于哪一代。当有parties个线程到达barrier，generation就会被更新换代。

2. 如果当前线程被中断，即Thread.interrupted()为true；则通过breakBarrier()终止CyclicBarrier。breakBarrier()的源码如下：

   ```java
   private void breakBarrier() {
       generation.broken = true;
       count = parties;
       trip.signalAll();
   }
   ```

   breakBarrier()会设置当前中断标记broken为true，意味着将该Generation中断；同时，设置count=parties，即重新初始化count；最后，通过signalAll()唤醒CyclicBarrier上所有的等待线程。

3. 将count计数器-1，即--count；然后判断是不是有parties个线程到达barrier，即index是不是为0。
   当index=0时，如果barrierCommand不为null，则执行该barrierCommand，barrierCommand就是我们创建CyclicBarrier时，传入的Runnable对象。然后，调用nextGeneration()进行换代工作，nextGeneration()的源码如下：

   ```java
   private void nextGeneration() {
       trip.signalAll();
       count = parties;
       generation = new Generation();
   }
   ```

   首先，它会调用signalAll()唤醒CyclicBarrier上所有的等待线程；接着，重新初始化count；最后，更新generation的值。

4. 在for(;;)循环中:timed是用来表示当前是不是超时等待线程。如果不是，则通过trip.await()进行等待；否则，调用awaitNanos()进行超时等待。

## 总结

CyclicBarrier内部是通过ReentrantLock和Condition来实现，调用await进行阻塞时，如果检测到当前线程还没有都到达，则会阻塞当前线程，这时是通过Condition锁来实现的阻塞。当所有的屏障都到达时，最后一个到达屏障的线程会调用signalAll唤醒所有的线程。因为此时等待队列上没有线程阻塞，所以条件队列上等待的线程会一个接一个获取到锁，然后解除阻塞。

CountDownLatch和CyclicBarrier都能够实现线程之间的等待，只不过它们侧重点不同：

1. CountDownLatch一般用于某个线程A等待若干个其他线程执行完任务之后，它才执行；
2. CyclicBarrier一般用于一组线程互相等待至某个状态，然后这一组线程再同时执行；
3. CountDownLatch是不能够重用的，而CyclicBarrier是可以重用的。

## 参考

1. [Java多线程进阶（十九）—— J.U.C之synchronizer框架：CyclicBarrier](https://segmentfault.com/a/1190000015888316)
2. [Java多线程系列--“JUC锁”10之 CyclicBarrier原理和示例](https://www.cnblogs.com/skywang12345/p/3533995.html)