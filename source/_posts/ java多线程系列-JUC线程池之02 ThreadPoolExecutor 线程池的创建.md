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

>ThreadPoolExecutor提供了四个创建线程池的构造函数，源码如下
>
>```
>//构造函数
>ThreadPoolExecutor(int corePoolSize, int maximumPoolSize, long keepAliveTime, TimeUnit unit, BlockingQueue<Runnable> workQueue)
>
>ThreadPoolExecutor(int corePoolSize, int maximumPoolSize, long keepAliveTime, TimeUnit unit, BlockingQueue<Runnable> workQueue, RejectedExecutionHandler handler)
>
>ThreadPoolExecutor(int corePoolSize, int maximumPoolSize, long keepAliveTime, TimeUnit unit, BlockingQueue<Runnable> workQueue, ThreadFactory threadFactory)
>
>ThreadPoolExecutor(int corePoolSize, int maximumPoolSize, long keepAliveTime, TimeUnit unit, BlockingQueue<Runnable> workQueue, ThreadFactory threadFactory, RejectedExecutionHandler handler)
>
>```
>
>虽然其提供了四个构造函数，但是前三个都是在调用最后一个来创建。
>
>threadFactory：如果不指定的话。默认是Executors.DefaultThreadFactory
>
>RejectedExecutionHandler：如果不指定默认是AbortPolicy
>
>下面是一个小的demo，创建线程池
>
>```
>ArrayBlockingQueue<Runnable> queue = new ArrayBlockingQueue(4);
>
>//使用默认的threadFatory，和ArrayBlockingQueue，DiscardOldestPolicy来创建线程池
>ThreadPoolExecutor executor = new ThreadPoolExecutor(2, 4,
>       60, TimeUnit.SECONDS, queue, new ThreadPoolExecutor.DiscardOldestPolicy());
>```
>
>

### 2. ThreadFactory:线程创建工厂

>在JUC中定义了线程创建工厂接口，也就是ThreadFactory接口，源码如下
>
>```
>public interface ThreadFactory {
>    Thread newThread(Runnable r);
>}
>```
>
>接口定义很简单，传递一个实现了Runnable接口的类，然后返回一个Thread对象，这和我们平常使用的new Thread其实没设么区别，只是在这里换成了工厂模式。
>
>ThreadPoolExecutor默认使用的是Executors.DefaultThreadFactory这个类，源码如下
>
>```
>    static class DefaultThreadFactory implements ThreadFactory {
>        private static final AtomicInteger poolNumber = new AtomicInteger(1);
>        private final ThreadGroup group;
>        private final AtomicInteger threadNumber = new AtomicInteger(1);
>        private final String namePrefix;
>
>        DefaultThreadFactory() {
>            SecurityManager s = System.getSecurityManager();
>            //
>            group = (s != null) ? s.getThreadGroup() :
>                                  Thread.currentThread().getThreadGroup();
>            //所有后面创建的线程，都都以这个下面这个字符串为前缀
>            namePrefix = "pool-" +
>                          poolNumber.getAndIncrement() +
>                         "-thread-";
>        }
>
>        public Thread newThread(Runnable r) {
>        	//创建线程
>            Thread t = new Thread(group, r,
>                                  namePrefix + threadNumber.getAndIncrement(),
>                                  0);
>            //设置线程的优先级和线程不是daemon线程
>            if (t.isDaemon())
>                t.setDaemon(false);
>            if (t.getPriority() != Thread.NORM_PRIORITY)
>                t.setPriority(Thread.NORM_PRIORITY);
>            return t;
>        }
>    }
>```
>
>分析：
>
>是在Executors内部实现的一个内部静态类，这个类的定义很简单，就是创建一个ThreadGroup，将后面使用newThread创建的线程放到这个group中，然后设置所有的线程都不是daemon线程，并且设置线程优先级为
>
>NORM_PRIORITY。

### 3. RejectedExecutionHandler：任务拒绝策略

>线程池堵塞队列容量满之后，将会直接新建线程，数量等于 `maximumPoolSize` 后，将会执行任务拒绝策略不在接受任务，有以下四种拒绝策略：
>
>1. ThreadPoolExecutor.AbortPolicy:丢弃任务并抛出RejectedExecutionException异常。
>2. ThreadPoolExecutor.DiscardPolicy：也是丢弃任务，但是不抛出异常。
>3. ThreadPoolExecutor.DiscardOldestPolicy：丢弃队列最前面的任务，然后重新尝试执行任务（重复此过程）
>4. ThreadPoolExecutor.CallerRunsPolicy：由调用线程处理该任务,也就是放在当前线程上运行，知道执行完成。

