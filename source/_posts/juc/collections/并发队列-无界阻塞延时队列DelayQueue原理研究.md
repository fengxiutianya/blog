---
tags:
  - 并发队列
categories:
  - java
  - juc
  - 队列
title: 并发队列-无界阻塞延时队列DelayQueue原理研究
abbrlink: b9225de
date: 2019-03-06 19:05:00
---
# 并发队列-无界阻塞延时队列DelayQueue原理研究

## 概述

DelayQueue队列中每个元素都有个过期时间，并且队列是个优先级队列，当从队列获取元素时候，只有过期元素才会出队列。

1. 使用案例
2. 简介
3. 源码分析
<!-- more -->

## 1. 使用案例

因为DelayQueue要求每一个入队的元素都要实现`Delayed`接口，也就是实现一个获取当前对象的延迟时间的方法。另外他的内部是通过使用PriorityQueue存放数据,因此你最好在内部实现一个比较延迟时间的比较器，这样可以按照延迟时间的大小来进行队列的建立，这样也会使得延迟时间最短的放在队列的最前面。不会因为队头延迟时间没到而阻塞了后面延迟时间到的元素出队。后面介绍源码的时候你会更清楚这里说的，先看下面一个简单demo

```java
package JUC.collect;

import java.util.concurrent.DelayQueue;
import java.util.concurrent.Delayed;
import java.util.concurrent.TimeUnit;

/**************************************
 *      Author : zhangke
 *      Date   : 2019-03-06 20:37
 *      email  : 398757724@qq.com
 *      Desc   : 
 ***************************************/
public class DelayQueueTest {

    public static void main(String[] args) {
        DelayQueue<DelayedElement> delayQueue = new DelayQueue<DelayedElement>();

        //生产者
        producer(delayQueue);

        //消费者
        consumer(delayQueue);

        while (true) {
            try {
                TimeUnit.HOURS.sleep(1);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
    }


    /**
     * 每100毫秒创建一个对象，放入延迟队列，延迟时间1毫秒
     *
     * @param delayQueue
     */
    private static void producer(final DelayQueue<DelayedElement> delayQueue) {
        new Thread(new Runnable() {
            @Override
            public void run() {
                while (true) {
                    try {
                        TimeUnit.MILLISECONDS.sleep(100);
                    } catch (InterruptedException e) {
                        e.printStackTrace();
                    }

                    DelayedElement element = new DelayedElement(1000, "test");
                    delayQueue.offer(element);
                }
            }
        }).start();

        /**
         * 每秒打印延迟队列中的对象个数
         */
        new Thread(new Runnable() {
            @Override
            public void run() {
                while (true) {
                    try {
                        TimeUnit.MILLISECONDS.sleep(1000);
                    } catch (InterruptedException e) {
                        e.printStackTrace();
                    }
                    System.out.println("delayQueue size:" + delayQueue.size());
                }
            }
        }).start();
    }


    /**
     * 消费者，从延迟队列中获得数据,进行处理
     *
     * @param delayQueue
     */
    private static void consumer(final DelayQueue<DelayedElement> delayQueue) {
        new Thread(new Runnable() {
            @Override
            public void run() {
                while (true) {
                    DelayedElement element = null;
                    try {
                        element = delayQueue.take();
                    } catch (InterruptedException e) {
                        e.printStackTrace();
                    }
                    System.out.println(System.currentTimeMillis() + "---" + element);
                }
            }
        }).start();
    }
}

class DelayedElement implements Delayed {

    private final long delay; //延迟时间

    private final long expire;  //到期时间

    private final String msg;   //数据

    private final long now; //创建时间


    public DelayedElement(long delay, String msg) {
        this.delay = delay;
        this.msg = msg;
        expire = System.currentTimeMillis() + delay;    //到期时间 = 当前时间+延迟时间
        now = System.currentTimeMillis();
    }


    /**
     * 需要实现的接口，获得延迟时间   用过期时间-当前时间
     *
     * @param unit
     * @return
     */
    @Override
    public long getDelay(TimeUnit unit) {
        return unit.convert(this.expire - System.currentTimeMillis(), TimeUnit.MILLISECONDS);
    }


    /**
     * 用于延迟队列内部比较排序
     * 当前时间的延迟时间 - 比较对象的延迟时间
     *
     * @param o
     * @return
     */
    @Override
    public int compareTo(Delayed o) {
        return (int) (this.getDelay(TimeUnit.MILLISECONDS) - o.getDelay(TimeUnit.MILLISECONDS));
    }


    @Override
    public String toString() {
        final StringBuilder sb = new StringBuilder("DelayedElement{");
        sb.append("delay=").append(delay);
        sb.append(", expire=").append(expire);
        sb.append(", msg='").append(msg).append('\'');
        sb.append(", now=").append(now);
        sb.append('}');
        return sb.toString();
    }
}


```

这个大体上就是实现了一个`Delayed`接口的类。然后模拟了生产者消费者模型来回进行入队出队操作。具体的源码解释的比较详细。

## 2. 简介

类图如下

![upload successful](/images/pasted-167.png)

使用场景主要有以下俩个：

- TimerQueue的内部实现
- ScheduledThreadPoolExecutor中DelayedWorkQueue是对其的优化使用

## 3. 源码分析

首先介绍后面会用到的属性

```java
// 全局同步锁
private final transient ReentrantLock lock = new ReentrantLock();
// 用于存放入队的元素
private final PriorityQueue<E> q = new PriorityQueue<E>();
// 出队有效的条件锁
private final Condition available = lock.newCondition();
```

构造函数

```java
 public DelayQueue() {}

public DelayQueue(Collection<? extends E> c) {
	this.addAll(c);
}
```

### 入队操作

因为`DelayQueue`是无界队列，所以入队的时候是不会阻塞住，他们所有的入队操作都是调用的下面这个方法。

```java
    public boolean offer(E e) {
        final ReentrantLock lock = this.lock;
        // 加锁
        lock.lock();
        try {
            // 插入优先级队列
            q.offer(e);
            // 获取队头元素，看是否有元素延迟时间已过，如果有，则
            // 唤醒等待出队的线程
            if (q.peek() == e) {
                leader = null;
                available.signal();
            }
            return true;
        } finally {
            lock.unlock();
        }
    }

```

这里入队还是比较简单的，主要是借助`PriorityQueue`来进行存储，将等待时间长的放在队尾，短的放在队头。

### 出队操作

#### take 操作

获取并移除队列首元素，如果队列没有过期元素则等待。

```java
public E take() throws InterruptedException {
        final ReentrantLock lock = this.lock;
        lock.lockInterruptibly();
        try {
            // 死循环，具体的退出条件在下面
            for (;;) {
                //获取但不移除队首元素
                E first = q.peek();
                // 如果没有元素，则直接进入等待队列
                if (first == null)
                    available.await();
                else {
                    // 获取队头，看时间是否已经过期，如果过期则出队
                    long delay = first.getDelay(TimeUnit.NANOSECONDS);
                    if (delay <= 0)//(3)
                        return q.poll();
                    // 判断当前内部的thread变量是否为空
                    // 不为为则使当前线程直接进入等待队列
                    else if (leader != null)//(4)
                        available.await();
                    else {
                        // 这是一个优化，使第一个进入等待队列的线程等待时间最短
                        Thread thisThread = Thread.currentThread();
                        leader = thisThread;//(5)
                        try {
                            available.awaitNanos(delay);
                        } finally {
                            if (leader == thisThread)
                                leader = null;
                        }
                    }
                }
            }
        } finally {
            if (leader == null && q.peek() != null)//(6)
                available.signal();
            lock.unlock();
        }
    }
```

第一次调用take时候由于队列空，所以把当前线程放入available的条件队列等待，当执行offer并且添加的元素就是队首元素时候就会通知最先等待的线程激活，循环重新获取队首元素，这时候first假如不空，则调用getdelay方法看该元素海剩下多少时间就过期了，如果delay<=0则说明已经过期，则直接出队返回。否者看leader是否为null，不为null则说明是其他线程也在执行take则把该线程放入条件队列，否者是当前线程执行的take方法，则调用await直到剩余过期时间到（这期间该线程会释放锁，所以其他线程可以offer添加元素，也可以take阻塞自己），剩余过期时间到后，该线程会重新竞争得到锁，重新进入循环。说明当前take返回了元素，如果当前队列还有元素则调用singal激活条件队列里面可能有的等待线程。leader那么为null，那么是第一次调用take获取过期元素的线程，第一次调用的线程调用设置等待时间的await方法等待数据过期，后面调用take的线程则调用await直到signal。

### poll操作

获取并移除队头过期元素，否者返回null。这个方法其实和上面的take操作大体上差不多，只是这个操作有一个等待过期的时间，如果超过这个时间还没有获取到元素，则之间返回null。

```java
 public E poll(long timeout, TimeUnit unit) throws InterruptedException {
        long nanos = unit.toNanos(timeout);
        final ReentrantLock lock = this.lock;
        lock.lockInterruptibly();
        try {
            for (;;) {
                E first = q.peek();
                if (first == null) {
                    if (nanos <= 0)
                        return null;
                    else
                        nanos = available.awaitNanos(nanos);
                } else {
                    long delay = first.getDelay(NANOSECONDS);
                    if (delay <= 0)
                        return q.poll();
                    if (nanos <= 0)
                        return null;
                    first = null; // don't retain ref while waiting
                    if (nanos < delay || leader != null)
                        nanos = available.awaitNanos(nanos);
                    else {
                        Thread thisThread = Thread.currentThread();
                        leader = thisThread;
                        try {
                            long timeLeft = available.awaitNanos(delay);
                            nanos -= delay - timeLeft;
                        } finally {
                            if (leader == thisThread)
                                leader = null;
                        }
                    }
                }
            }
        } finally {
            if (leader == null && q.peek() != null)
                available.signal();
            lock.unlock();
        }
    }
```

## 参考

1. [Java延时队列DelayQueue的使用](https://my.oschina.net/lujianing/blog/705894)
2. [并发队列-无界阻塞延迟队列DelayQueue原理探究](http://ifeve.com/%E5%B9%B6%E5%8F%91%E9%98%9F%E5%88%97-%E6%97%A0%E7%95%8C%E9%98%BB%E5%A1%9E%E5%BB%B6%E8%BF%9F%E9%98%9F%E5%88%97delayqueue%E5%8E%9F%E7%90%86%E6%8E%A2%E7%A9%B6/)