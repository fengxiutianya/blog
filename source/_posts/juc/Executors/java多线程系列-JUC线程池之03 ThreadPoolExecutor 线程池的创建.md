abbrlink: 12
title: java多线程系列-JUC线程池之03 ThreadPoolExecutor 线程池的创建
tags:
  - JUC
  - 线程池
categories:
  - java
author: zhangke
date: 2018-07-24 13:58:00
---
#  java多线程系列-JUC线程池之03 ThreadPoolExecutor 线程池的创建

### 概要

>1. 线程池的创建
>2. ThreadFactory：线程创建工厂
>3. RejectedExecutionHandler：任务拒绝策略

###  1. 线程池的创建

ThreadPoolExecutor提供了四个创建线程池的构造函数，源码如下

```java
ThreadPoolExecutor(int corePoolSize, int maximumPoolSize, long keepAliveTime, TimeUnit unit, BlockingQueue<Runnable> workQueue)

ThreadPoolExecutor(int corePoolSize, int maximumPoolSize, long keepAliveTime, TimeUnit unit, BlockingQueue<Runnable> workQueue, RejectedExecutionHandler handler)

ThreadPoolExecutor(int corePoolSize, int maximumPoolSize, long keepAliveTime, TimeUnit unit, BlockingQueue<Runnable> workQueue, ThreadFactory threadFactory)

ThreadPoolExecutor(int corePoolSize, int maximumPoolSize, long keepAliveTime, TimeUnit unit, BlockingQueue<Runnable> workQueue, ThreadFactory threadFactory, RejectedExecutionHandler handler)
```
<!-- more -->
虽然其提供了四个构造函数，但是前三个都是在调用最后一个来创建。下面来解释一下上面每个参数的意思

1. corePoolSize:核心线程池的大小
2. maximumPoolSize: 线程池中最大线程池的次数、
3. keepAliveTime :线程最大空闲的时间
4. TimeUnit：用于指定前面keepAliveTime代表的时间单位
5. workQueue：指定存放任务的队列
6. threadFactory：创建线程的工厂，如果不指定的话。默认是Executors.DefaultThreadFactory
7. ejectedExecutionHandler：拒接策略，如果不指定默认是AbortPolicy

下面通过Executors来看看具体的线程池如何创建：

```java
public static ExecutorService newCachedThreadPool() {
    return new ThreadPoolExecutor(0, Integer.MAX_VALUE,
                                  60L, TimeUnit.SECONDS,
                                  new SynchronousQueue<Runnable>());
}

public static ExecutorService newCachedThreadPool(ThreadFactory threadFactory) {
    return new ThreadPoolExecutor(0, Integer.MAX_VALUE,
                                  60L, TimeUnit.SECONDS,
                                  new SynchronousQueue<Runnable>(),
                                  threadFactory);
}
```

上面是创建一个可根据需要创建新线程的线程池，但是以前构造的线程可用时将重用它们。上面是将核心线程设置为0，也就是只要有线程加进来，就会创建一个新线程。每个空闲线程都只会保留60秒，超过这个时间就会回收。另外一个比较特殊是，它使用的队列SynchronousQueue，这是一个不会缓存任务的队列，来一个任务，只有在有线程将此任务取出之后，才会有另外的任务加进来。也确保了只要有任务来，就会去创建一个新的线程或使用空闲的线程。

```java
public static ExecutorService newFixedThreadPool(int nThreads) {
        return new ThreadPoolExecutor(nThreads, nThreads,
                                      0L, TimeUnit.MILLISECONDS,
                                      new LinkedBlockingQueue<Runnable>());
    }
public static ExecutorService newFixedThreadPool(int nThreads, ThreadFactory threadFactory) {
        return new ThreadPoolExecutor(nThreads, nThreads,
                                      0L, TimeUnit.MILLISECONDS,
                                      new LinkedBlockingQueue<Runnable>(),
                                      threadFactory);
```

创建一个核心线程和最大线程相同的线程池，也就是新任务了，如果进不了队列，就会被抛出，不过它使用的是LinkedBlockingQueue队列，并且没有设置队列的长度，就是可以缓存 Integer.MAX_VALUE个任务。

```java
public static ExecutorService newSingleThreadExecutor() {
        return new FinalizableDelegatedExecutorService
            (new ThreadPoolExecutor(1, 1,
                                    0L, TimeUnit.MILLISECONDS,
                                    new LinkedBlockingQueue<Runnable>()));
}
 public static ExecutorService newSingleThreadExecutor(ThreadFactory threadFactory) {
        return new FinalizableDelegatedExecutorService
            (new ThreadPoolExecutor(1, 1,
                                    0L, TimeUnit.MILLISECONDS,
                                    new LinkedBlockingQueue<Runnable>(),
                                    threadFactory));
}

```

这个是创建只有一个核心线程的线程池，只有前一个任务执行完成，后一个任务才能被执行。

### 2. ThreadFactory:线程创建工厂

>在JUC中定义了线程创建工厂接口，也就是ThreadFactory接口，源码如下
>
>```java
>public interface ThreadFactory {
>	Thread newThread(Runnable r);
>}
>```
>
>接口定义很简单，传递一个实现了Runnable接口的类，然后返回一个Thread对象，这和我们平常使用的new Thread其实没设么区别，只是在这里换成了工厂模式。
>
>ThreadPoolExecutor默认使用的是Executors.DefaultThreadFactory这个类，源码如下
>
>```java
>static class DefaultThreadFactory implements ThreadFactory {
>   private static final AtomicInteger poolNumber = new AtomicInteger(1);
>   private final ThreadGroup group;
>   private final AtomicInteger threadNumber = new AtomicInteger(1);
>   private final String namePrefix;
>
>   DefaultThreadFactory() {
>       SecurityManager s = System.getSecurityManager();
>       //获取当前cpu运行线程的ThreadGroup，这样便于管理线程池中线程
>       group = (s != null) ? s.getThreadGroup() :
>                             Thread.currentThread().getThreadGroup();
>       //所有后面创建的线程，都都以这个下面这个字符串为前缀
>       namePrefix = "pool-" +
>                     poolNumber.getAndIncrement() +
>                    "-thread-";
>   }
>
>   public Thread newThread(Runnable r) {
>   	   //创建线程，指定ThreadGroup和线程名字，忽略栈的大小，也就是使用默认栈的深度
>       Thread t = new Thread(group, r,
>                             namePrefix + threadNumber.getAndIncrement(),
>                             0);
>       //设置线程的优先级和线程不是daemon线程
>       if (t.isDaemon())
>           t.setDaemon(false);
>       // 设置线程优先级为NORM_PRIORITY
>       if (t.getPriority() != Thread.NORM_PRIORITY)
>           t.setPriority(Thread.NORM_PRIORITY);
>       return t;
>   }
>}
>```
>
>分析：
>
>是在Executors内部实现的一个内部静态类，这个类的定义很简单，就是创建一个ThreadGroup，将后面使用newThread创建的线程放到这个group中，然后设置所有的线程都不是daemon线程，并且设置线程优先级为NORM_PRIORITY。
>

### 3. RejectedExecutionHandler：任务拒绝策略

>线程池的拒绝策略，是指当任务添加到线程池中被拒绝，而采取的处理措施。当任务添加到线程池中之所以被拒绝，可能是由于：第一，线程池异常关闭。第二，任务数量超过线程池的最大限制。
>
>线程池共包括4种拒绝策略，它们分别是：**AbortPolicy**, **CallerRunsPolicy**, **DiscardOldestPolicy**和**DiscardPolicy**。
>
>1. **AbortPolicy** ：当任务添加到线程池中被拒绝时，它将抛出 RejectedExecutionException 异常。
>2. **CallerRunsPolicy** ：当任务添加到线程池中被拒绝时，会在调用execute方法的Thread线程中处理被拒绝的任务，也就是当前运行在cpu上的线程中执行，会阻塞当前正在运行的线程。
>3. **DiscardOldestPolicy** ： 当任务添加到线程池中被拒绝时，线程池会放弃等待队列中最旧的未处理任务，然后将被拒绝的任务添加到等待队列中。
>4. **DiscardPolicy**   ：当任务添加到线程池中被拒绝时，线程池将丢弃被拒绝的任务。