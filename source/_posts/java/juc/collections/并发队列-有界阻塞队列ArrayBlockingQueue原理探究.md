---
title: 并发队列-有界阻塞队列ArrayBlockingQueue原理探究
tags:
  - juc
  - 并发队列
categories:
  - java
  - juc
  - collections
abbrlink: 5fda9009
date: 2019-03-06 19:05:00
---
# 并发队列-有界阻塞队列ArrayBlockingQueue原理探究

## 概述

`java.util.concurrent.ArrayBlockingQueue` 是一个线程安全的、基于数组、有界的、阻塞的、FIFO 队列。试图向已满队列中放入元素会导致操作受阻塞；试图从空队列中提取元素将导致类似阻塞。

此类基于 `java.util.concurrent.locks.ReentrantLock` 来实现线程安全，所以提供了 `ReentrantLock` 所能支持的公平性选择

1. ArrayBlockingQueue简介
2. 源码分析
<!-- more -->

## ArrayBlockingQueue简介

ArrayBlockingQueue是数组实现的线程安全的有界的阻塞队列。线程安全是指，ArrayBlockingQueue内部通过“互斥锁”保护竞争资源，实现了多线程对竞争资源的互斥访问。而有界，则是指ArrayBlockingQueue对应的数组是有界限的。 阻塞队列，是指多线程访问竞争资源时，当竞争资源已被某线程获取时，其它要获取该资源的线程需要阻塞等待；而且，ArrayBlockingQueue是按 FIFO（先进先出）原则对元素进行排序，元素都是从尾部插入到队列，从头部开始返回。

类图如下

![upload successful](/images/pasted-164.png)

## 源码分析

首先看一下后面要用的属性，队列的操作主要有读、写，所以用了两个 `int` 类型的属性作为下一个读写位置的的指针。存放元素的数组是 `final` 修饰的，所以数组的大小是固定的。对于并发控制，是所有的访问都必须加锁，并用两个条件对象用于协调读写操作。

```java
// 队列存放元素的容器
final Object[] items;

// 下一次读取或移除的位置
int takeIndex;

// 存放下一个放入元素的位置
int putIndex;

// 队列里有效元素的数量
int count;

// 所有访问的保护锁
final ReentrantLock lock;

// 等待获取的条件
private final Condition notEmpty;

// 等待放入的条件
private final Condition notFull;
```

接下来我们看一下构造函数：

提供了三个构造函数，最终都会调用下面这个构造函数

```java
public ArrayBlockingQueue(int capacity, boolean fair) {
    if (capacity <= 0)
        throw new IllegalArgumentException();
        
    // 初始化上面介绍的属性
   this.items = new Object[capacity];
   lock = new ReentrantLock(fair);
   notEmpty = lock.newCondition();
   notFull =  lock.newCondition();
}
```

### 入队

入队有以下方法可用，分别是：

```java
public boolean add(E e)
public void put(E e)
public boolean offer(E e)
public boolean offer(E e, long timeout, TimeUnit unit)
```

不过上面四个方法的大体思路都是一样的，就是对同步变量加锁，然后添加数据到队尾，然后释放锁。这里拿`public boolean offer(E e, long timeout, TimeUnit unit)`来举例，这个操作多了一个条件，当等待指定的时间还没有添加成功，则直接返回添加失败。源码如下：

```java
public boolean offer(E e, long timeout, TimeUnit unit)
        throws InterruptedException {
		// 检查e为非空，如果为空，则抛出异常
        checkNotNull(e);
    	// 转换成纳秒
        long nanos = unit.toNanos(timeout);
        final ReentrantLock lock = this.lock;
    	// 加锁
        lock.lockInterruptibly();
        try {
            // 当队列已满，则等待nanos时间，
            // 也就是进入notFull条件等待队列
            // 当被唤醒，检测是否队列还是处于满的状态
            // 如果队列未满，则直接结束循环，将元素入队
            // 否则，判断等待时间是否还剩余， 如果还剩余，
            // 则接着进入等待队列，
            // 如果没有时间剩余，则之间返回添加失败
            while (count == items.length) {
                if (nanos <= 0)
                    return false;
                nanos = notFull.awaitNanos(nanos);
            }
            // 入队
            enqueue(e);
            return true;
        } finally {
            // 释放锁
            lock.unlock();
        }
    }
```

上面整个流程还是比较清晰，下面我们来看一下入队操作，其实也比较简单，就是循环的往数组里面添加元素

```java
    private void enqueue(E x) {
		
        final Object[] items = this.items;
        // 添加元素
        items[putIndex] = x;
        // 处理下标，如果是最后一个，则将下标设为0
        if (++putIndex == items.length)
            putIndex = 0;
        // 元素数量加1
        count++;
        // 发出队类不为空的信号，释放哪些等待获取的线程
        notEmpty.signal();
    }
```

代码逻辑很简单，但是这里需要思考一个问题为啥调用lockInterruptibly方法而不是Lock方法。我的理解是因为调用了条件变量的await()方法，而await()方法会在中断标志设置后抛出InterruptedException异常后退出，所以还不如在加锁时候先看中断标志是不是被设置了，如果设置了直接抛出InterruptedException异常，就不用再去获取锁了。然后看了其他并发类里面凡是调用了await的方法获取锁时候都是使用的lockInterruptibly方法而不是Lock也验证了这个想法。

### 出队

出队主要有以下方法可用：

```java
public E poll()
public E poll(long timeout, TimeUnit unit)
public E take() throws InterruptedException
public E peek()
```

上面四个方法中主要是peek出队不会删除元素，其他的都是移除队头元素并将数据返回。

大体的思路是，获取元素之前对共享变量加锁，然后出队，接着释放锁，这里拿`public E poll(long timeout, TimeUnit unit)`来举例说明

```java
public E poll(long timeout, TimeUnit unit) throws InterruptedException {
    long nanos = unit.toNanos(timeout);
    final ReentrantLock lock = this.lock;
    // 加锁，当线程被中断，则抛出异常
    lock.lockInterruptibly();
    
    try {
        // 循环判断当前队列是否为空，
        // 如果不为空，则结束中断
        // 否则进入条件等待队列，
        // 如果在等待已给的时间内还没有
        // 元素添加，则返回null
        // 否则结束循环，进入下一步操作
        while (count == 0) {
            if (nanos <= 0)
                return null;
            nanos = notEmpty.awaitNanos(nanos);
        }
        // 获取出队元素
        return dequeue();
    } finally {
        lock.unlock();
    }
}
// 出队操作
private E dequeue() {
    final Object[] items = this.items;
    @SuppressWarnings("unchecked")
    E x = (E) items[takeIndex];
    items[takeIndex] = null;
    if (++takeIndex == items.length)
        takeIndex = 0;
    count--;
    if (itrs != null)
        itrs.elementDequeued();
   	//发送信号激活notFull条件队列里面的线程
    notFull.signal();
    return x;
}
```

### size操作

获取队列元素个数，非常精确因为计算size时候加了独占锁，其他线程不能入队或者出队或者删除元素

```java
public int size() {
    final ReentrantLock lock = this.lock;
    lock.lock();
    try {
        return count;
    } finally {
        lock.unlock();
    }
}
```

## 总结

ArrayBlockingQueue通过使用全局独占锁实现同时只能有一个线程进行入队或者出队操作，这个锁的粒度比较大，有点类似在方法上添加synchronized的意味。其中offer,poll操作通过简单的加锁进行入队出队操作，而put,take则使用了条件变量实现如果队列满则等待，如果队列空则等待，然后分别在出队和入队操作中发送信号激活等待线程实现同步。另外相比LinkedBlockingQueue，ArrayBlockingQueue的size操作的结果是精确的，因为计算前加了全局锁。

## 参考

1. [并发队列-有界阻塞队列ArrayBlockingQueue原理探究](http://ifeve.com/%E5%B9%B6%E5%8F%91%E9%98%9F%E5%88%97-%E6%9C%89%E7%95%8C%E9%98%BB%E5%A1%9E%E9%98%9F%E5%88%97arrayblockingqueue%E5%8E%9F%E7%90%86%E6%8E%A2%E7%A9%B6/)