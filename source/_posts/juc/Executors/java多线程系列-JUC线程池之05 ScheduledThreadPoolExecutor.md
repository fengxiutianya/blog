title: java多线程系列-JUC线程池之05 ScheduledThreadPoolExecutor
tags:
  - juc
  - ''
  - 线程池
categories:
  - java
  - ''
abbrlink: 3f86c9f8
date: 2019-03-08 07:23:00
---
---
# java多线程系列-JUC线程池之05 ScheduledThreadPoolExecutor

## 简介

自JDK1.5开始，JDK提供了ScheduledThreadPoolExecutor类来支持周期性任务的调度。在这之前的实现需要依靠Timer和TimerTask或者其它第三方工具来完成。但Timer有不少的缺陷：

- Timer是单线程模式；
- 如果在执行任务期间某个TimerTask耗时较久，那么就会影响其它任务的调度；
- Timer的任务调度是基于绝对时间的，对系统时间敏感；
- Timer不会捕获执行TimerTask时所抛出的异常，由于Timer是单线程，所以一旦出现异常，则线程就会终止，其他任务也得不到执行。
<!-- more -->
ScheduledThreadPoolExecutor继承ThreadPoolExecutor来重用线程池的功能，它的实现方式如下：

- 将任务封装成ScheduledFutureTask对象，ScheduledFutureTask基于相对时间，不受系统时间的改变所影响；
- ScheduledFutureTask实现了`java.lang.Comparable`接口和`java.util.concurrent.Delayed`接口，所以有两个重要的方法：compareTo和getDelay。compareTo方法用于比较任务之间的优先级关系，如果距离下次执行的时间间隔较短，则优先级高；getDelay方法用于返回距离下次任务执行时间的时间间隔；
- ScheduledThreadPoolExecutor定义了一个DelayedWorkQueue，它是一个有序队列，会通过每个任务按照距离下次执行时间间隔的大小来排序；
- ScheduledFutureTask继承自FutureTask，可以通过返回Future对象来获取执行的结果。

通过如上的介绍，可以对比一下Timer和ScheduledThreadPoolExecutor：

| Timer                                            | ScheduledThreadPoolExecutor            |
| ------------------------------------------------ | -------------------------------------- |
| 单线程                                           | 多线程                                 |
| 单个任务执行时间影响其他任务调度                 | 多线程，不会影响                       |
| 基于绝对时间                                     | 基于相对时间                           |
| 一旦执行任务出现异常不会捕获，其他任务得不到执行 | 多线程，单个任务的执行不会影响其他线程 |

## ScheduledThreadPoolExecutor的实现

 ScheduledThreadPoolExecutor的类结构

![upload successful](/images/pasted-172.png)

ScheduledThreadPoolExecutor继承自ThreadPoolExecutor，实现了ScheduledExecutorService接口，该接口定义了schedule等任务调度的方法。

同时ScheduledThreadPoolExecutor有两个重要的内部类：DelayedWorkQueue和ScheduledFutureTask。可以看到，DelayeddWorkQueue是一个阻塞队列，而ScheduledFutureTask继承自FutureTask，并且实现了Delayed接口。有关FutureTask的介绍请参考另一篇文章：[java多线程系列-JUC线程池之04 Future 和Callable](https://taolove.top/2018/07/24/juc/Executors/java%E5%A4%9A%E7%BA%BF%E7%A8%8B%E7%B3%BB%E5%88%97-JUC%E7%BA%BF%E7%A8%8B%E6%B1%A0%E4%B9%8B04%20Future%20%E5%92%8CCallable/)

我们首先看一下ScheduledThreadPoolExecutor有3中构造方法：

```java
public ScheduledThreadPoolExecutor(int corePoolSize,
                                    ThreadFactory threadFactory) {
    super(corePoolSize, Integer.MAX_VALUE, 0, NANOSECONDS,
          new DelayedWorkQueue(), threadFactory);
}

public ScheduledThreadPoolExecutor(int corePoolSize,
                                   RejectedExecutionHandler handler) {
    super(corePoolSize, Integer.MAX_VALUE, 0, NANOSECONDS,
          new DelayedWorkQueue(), handler);
}

public ScheduledThreadPoolExecutor(int corePoolSize,
                                   ThreadFactory threadFactory,
                                   RejectedExecutionHandler handler) {
    super(corePoolSize, Integer.MAX_VALUE, 0, NANOSECONDS,
          new DelayedWorkQueue(), threadFactory, handler);
}
```

因为ScheduledThreadPoolExecutor继承自ThreadPoolExecutor，所以这里都是调用的ThreadPoolExecutor类的构造方法。有关ThreadPoolExecutor可以参考这俩篇文章[java多线程系列-JUC线程池之02 ThreadPoolExecutor 执行流程分析](https://taolove.top/2018/07/23/juc/Executors/java%E5%A4%9A%E7%BA%BF%E7%A8%8B%E7%B3%BB%E5%88%97-JUC%E7%BA%BF%E7%A8%8B%E6%B1%A0%E4%B9%8B02%20ThreadPoolExecutor%E6%BA%90%E7%A0%81%E5%88%86%E6%9E%90/) 和[java多线程系列-JUC线程池之03 ThreadPoolExecutor 线程池的创建](https://taolove.top/2018/07/24/juc/Executors/java%E5%A4%9A%E7%BA%BF%E7%A8%8B%E7%B3%BB%E5%88%97-JUC%E7%BA%BF%E7%A8%8B%E6%B1%A0%E4%B9%8B03%20ThreadPoolExecutor%20%E7%BA%BF%E7%A8%8B%E6%B1%A0%E7%9A%84%E5%88%9B%E5%BB%BA/)

另外这里使用的是DelayedWorkQueue，使用这个的原因是DelayQueue队列中每个元素都有个过期时间，并且队列是个优先级队列，当从队列获取元素时候，只有过期元素才会出队列。具体可以参考这篇文章[并发队列-无界阻塞延时队列DelayQueue原理研究](https://taolove.top/2019/03/07/juc/collections/%E5%B9%B6%E5%8F%91%E9%98%9F%E5%88%97-%E6%97%A0%E7%95%8C%E9%98%BB%E5%A1%9E%E5%BB%B6%E6%97%B6%E9%98%9F%E5%88%97DelayQueue%E5%8E%9F%E7%90%86%E7%A0%94%E7%A9%B6/)

下面来具体来分析是如何实现定时任务和周期性任务的调度：

### schedule：延迟任务调度的方法

schedule方法来进行延迟任务调度，schedule方法的代码如下：

```java
public ScheduledFuture<?> schedule(Runnable command,
                                   long delay,
                                   TimeUnit unit) {
    if (command == null || unit == null)
        throw new NullPointerException();
    RunnableScheduledFuture<?> t = decorateTask(command,
        new ScheduledFutureTask<Void>(command, null,
                                      triggerTime(delay, unit)));
    delayedExecute(t);
    return t;
}


public <V> ScheduledFuture<V> schedule(Callable<V> callable,
                                       long delay,
                                       TimeUnit unit) {
    if (callable == null || unit == null)
        throw new NullPointerException();
    RunnableScheduledFuture<V> t = decorateTask(callable,
        new ScheduledFutureTask<V>(callable,
                                   triggerTime(delay, unit)));
    delayedExecute(t);
    return t;
}
```

首先，这里的两个重载的schedule方法只是传入的第一个参数不同，可以是Runnable对象或者Callable对象。会把传入的任务封装成一个RunnableScheduledFuture对象，其实也就是ScheduledFutureTask对象，这个下面在具体进行说明，decorateTask默认什么功能都没有做，子类可以重写该方法来进行扩展：

```java
/**
 * 修改或替换用于执行 runnable 的任务。此方法可重写用于管理内部任务的具体类。默认实现只返回给定任务。
 */
protected <V> RunnableScheduledFuture<V> decorateTask(
    Runnable runnable, RunnableScheduledFuture<V> task) {
    return task;
}

/**
 * 修改或替换用于执行 callable 的任务。此方法可重写用于管理内部任务的具体类。默认实现只返回给定任务。
 */
protected <V> RunnableScheduledFuture<V> decorateTask(
    Callable<V> callable, RunnableScheduledFuture<V> task) {
    return task;
}
```

然后，通过调用delayedExecute方法来延时执行任务，最后，返回一个ScheduledFuture对象。源码如下：

### delayedExecute方法

```
private void delayedExecute(RunnableScheduledFuture<?> task) {
    // 如果线程池已经关闭，使用拒绝策略拒绝任务
    if (isShutdown())
        reject(task);
    else {
        // 添加到阻塞队列中
        super.getQueue().add(task);
        // 再一次判断线程池是否关闭，如果关闭则删除任务
        if (isShutdown() &&
            !canRunInCurrentRunState(task.isPeriodic()) &&
            remove(task))
            task.cancel(false);
        else
            // 确保线程池中至少有一个线程启动，即使corePoolSize为0
            // 该方法在ThreadPoolExecutor中实现
            ensurePrestart();
    }
}
```

逻辑比较清晰，主要是按照以下步骤

1. 判断线程池是否关闭，如果关闭则拒绝任务，如果不是进入步骤2
2. 任务首先入队，然后再一次判断当前线程池是否关闭，并判断任务是否可以在执行中终止，如果满足，则删除任务。
3. 确保线程池有至少有一个线程在运行。

对于步骤2，可以通过`setContinueExistingPeriodicTasksAfterShutdownPolicy`方法设置在线程池关闭时，周期任务继续执行，默认为false，也就是线程池关闭时，不再执行周期任务。

ensurePrestart方法在ThreadPoolExecutor中定义：

```java
void ensurePrestart() {
    int wc = workerCountOf(ctl.get());
    if (wc < corePoolSize)
        addWorker(null, true);
    else if (wc == 0)
        addWorker(null, false);
}
```

调用了addWorker方法，可以在[java多线程系列-JUC线程池之02 ThreadPoolExecutor 执行流程分析](https://taolove.top/2018/07/23/juc/Executors/java%E5%A4%9A%E7%BA%BF%E7%A8%8B%E7%B3%BB%E5%88%97-JUC%E7%BA%BF%E7%A8%8B%E6%B1%A0%E4%B9%8B02%20ThreadPoolExecutor%E6%BA%90%E7%A0%81%E5%88%86%E6%9E%90/)中查看addWorker方法的介绍，线程池中的工作线程是通过该方法来启动并执行任务的。

### scheduleAtFixedRate方法

该方法设置了执行周期，下一次执行时间相当于是上一次的执行时间加上period，它是采用固定的频率来执行任务：

```java
public ScheduledFuture<?> scheduleAtFixedRate(Runnable command,
                                              long initialDelay,
                                              long period,
                                              TimeUnit unit) {
    if (command == null || unit == null)
        throw new NullPointerException();
    if (period <= 0)
        throw new IllegalArgumentException();
    ScheduledFutureTask<Void> sft =
        new ScheduledFutureTask<Void>(command,
                                      null,
                                      triggerTime(initialDelay, unit),
                                      unit.toNanos(period));
    RunnableScheduledFuture<Void> t = decorateTask(command, sft);
    sft.outerTask = t;
    delayedExecute(t);
    return t;
}
```

### scheduleWithFixedDelay方法

该方法设置了执行周期，与scheduleAtFixedRate方法不同的是，下一次执行时间是上一次任务执行完的系统时间加上period，因而具体执行时间不是固定的，但周期是固定的，是采用相对固定的延迟来执行任务：

```java
public ScheduledFuture<?> scheduleWithFixedDelay(Runnable command,
                                                 long initialDelay,
                                                 long delay,
                                                 TimeUnit unit) {
    if (command == null || unit == null)
        throw new NullPointerException();
    if (delay <= 0)
        throw new IllegalArgumentException();
    ScheduledFutureTask<Void> sft =
        new ScheduledFutureTask<Void>(command,
                                      null,
                                      triggerTime(initialDelay, unit),
                                      unit.toNanos(-delay));
    RunnableScheduledFuture<Void> t = decorateTask(command, sft);
    sft.outerTask = t;
    delayedExecute(t);
    return t;
}
```

注意这里的`unit.toNanos(-delay));`，这里把周期设置为负数来表示是相对固定的延迟执行。

到这我们已经看完了ScheduledThreadPoolExecutor的所有调度任务执行执行的方法，下面我们来具体看一下他是如何做到任务的定时执行和周期执行，如果你阅读过ThreadPoolExecutor，那么你应该能够猜到具体的方法是在ScheduledFutureTask中，我们首先看一下他的构造函数。

ScheduledFutureTask继承自FutureTask并实现了RunnableScheduledFuture接口，构造方法如下：

```java
ScheduledFutureTask(Runnable r, V result, long ns) {
    super(r, result);
    this.time = ns;
    this.period = 0;
    this.sequenceNumber = sequencer.getAndIncrement();
}
ScheduledFutureTask(Callable<V> callable, long ns) {
    super(callable);
    this.time = ns;
    this.period = 0;
    this.sequenceNumber = sequencer.getAndIncrement();
}


ScheduledFutureTask(Runnable r, V result, long ns, long period) {
    super(r, result);
    this.time = ns;
    this.period = period;
    this.sequenceNumber = sequencer.getAndIncrement();
}



```

这里面有几个重要的属性，下面来解释一下：

-  **time**：下次任务执行时的时间；
-  **period**：执行周期；0代表延迟任务，正数代表fixed-delay任务，负数代表fixed-rate任务
-  **sequenceNumber**：保存任务被添加到ScheduledThreadPoolExecutor中的序号。

回顾一下线程池的执行过程：当线程池中的工作线程启动时，不断地从阻塞队列中取出任务并执行，当然，取出的任务实现了Runnable接口，所以是通过调用任务的run方法来执行任务的。

这里的任务类型是ScheduledFutureTask，所以下面看一下ScheduledFutureTask的run方法：

```
public void run() {
    // 是否是周期性任务
    boolean periodic = isPeriodic();
    // 当前线程池运行状态下如果不可以执行任务，取消该任务
    if (!canRunInCurrentRunState(periodic))
        cancel(false);
    // 如果不是周期性任务，调用FutureTask中的run方法执行
    else if (!periodic)
        ScheduledFutureTask.super.run();
    // 如果是周期性任务，调用FutureTask中的runAndReset方法执行
    // runAndReset方法不会设置执行结果，所以可以重复执行任务
    else if (ScheduledFutureTask.super.runAndReset()) {
        // 计算下次执行该任务的时间
        setNextRunTime();
        // 重复执行任务
        reExecutePeriodic(outerTask);
    }
}
```

分析一下执行过程：

1. 如果当前线程池运行状态不可以执行任务，取消该任务，然后直接返回，否则执行步骤2；
2. 如果不是周期性任务，调用FutureTask中的run方法执行，会设置执行结果，然后直接返回，否则执行步骤3；
3. 如果是周期性任务，调用FutureTask中的runAndReset方法执行，不会设置执行结果，然后直接返回，否则执行步骤4和步骤5；
4. 计算下次执行该任务的具体时间；
5. 重复执行任务。

有关FutureTask的run方法可以看这篇文章[java多线程系列-JUC线程池之04 Future 和Callable](https://taolove.top/2018/07/24/juc/Executors/java%E5%A4%9A%E7%BA%BF%E7%A8%8B%E7%B3%BB%E5%88%97-JUC%E7%BA%BF%E7%A8%8B%E6%B1%A0%E4%B9%8B04%20Future%20%E5%92%8CCallable/)，下面我们来说一下runAndReset方法，其实从名字就可以看出，就是运行之后，重新设置任务为初始状态，源码如下

```java
    protected boolean runAndReset() {
        // 判断任务状态是否为NEW，如果不是直接返回
        if (state != NEW ||
            !UNSAFE.compareAndSwapObject(this, runnerOffset,
                                         null, Thread.currentThread()))
            return false;
        boolean ran = false;
        int s = state;
        try {
            // 执行任务，至此那个成功后返回true
            Callable<V> c = callable;
            if (c != null && s == NEW) {
                try {
                    c.call(); // don't set result
                    ran = true;
                } catch (Throwable ex) {
                    setException(ex);
                }
            }
        } finally {
            // 执行完成后，设置执行任务的线程为null
            runner = null;
            // 在意判断状态，如果被中断或者取消，则进行后续处理
            s = state;
            if (s >= INTERRUPTING)
                handlePossibleCancellationInterrupt(s);
        }
        return ran && s == NEW;
    }
```

上面整体逻辑很清晰，这里就不具体说明。下面我们看看setNextRunTime和reExecutePeriodic方法

### setNextRunTime 用于设置下一次任务执行的时间

```
private void setNextRunTime() {
    long p = period;
    // 固定频率，上次执行时间加上周期时间
    if (p > 0)
        time += p;
    // 相对固定延迟执行，使用当前系统时间加上周期时间
    else
        time = triggerTime(-p);
}
```

从这里就可以看出scheduleAtFixedRate和scheduleWithFixedDelay的区别。下面看一下triggerTime方法。

triggerTime方法用于获取下一次执行的具体时间：

```java
private long triggerTime(long delay, TimeUnit unit) {
    return triggerTime(unit.toNanos((delay < 0) ? 0 : delay));
}


long triggerTime(long delay) {
    return now() +
        ((delay < (Long.MAX_VALUE >> 1)) ? delay : overflowFree(delay));
}
```

这里的`delay < (Long.MAX_VALUE >> 1`是为了判断是否要防止Long类型溢出，如果delay的值小于Long类型最大值的一半，则直接返回delay，否则需要进行防止溢出处理。

overflowFree方法的作用是限制队列中所有节点的延迟时间在Long.MAX_VALUE之内，防止在compareTo方法中溢出。

```java
private long overflowFree(long delay) {
    // 获取队列中的第一个节点
    Delayed head = (Delayed) super.getQueue().peek();
    if (head != null) {
        // 获取延迟时间
        long headDelay = head.getDelay(NANOSECONDS);
        // 如果延迟时间小于0，并且 delay - headDelay 超过了Long.MAX_VALUE
        // 将delay设置为 Long.MAX_VALUE + headDelay 保证delay小于Long.MAX_VALUE
        if (headDelay < 0 && (delay - headDelay < 0))
            delay = Long.MAX_VALUE + headDelay;
    }
    return delay;
}
```

当一个任务已经可以执行出队操作，但还没有执行，可能由于线程池中的工作线程不是空闲的。具体分析一下这种情况：

- 为了方便说明，假设Long.MAX_VALUE=1023，也就是11位，并且当前的时间是100，调用triggerTime时并没有对delay进行判断，而是直接返回了`now() + delay`，也就是相当于`100 + 1023`，这肯定是溢出了，那么返回的时间是-925；
- 如果头节点已经可以出队但是还没有执行出队，那么头节点的执行时间应该是小于当前时间的，假设是95；
- 这时调用offer方法向队列中添加任务，在offer方法中会调用siftUp方法来排序，在siftUp方法执行时又会调用ScheduledFutureTask中的compareTo方法来比较执行时间；
- 这时如果执行到了compareTo方法中的`long diff = time - x.time;`时，那么计算后的结果就是`-925 - 95 = -1020`，那么将返回-1，而正常情况应该是返回1，因为新加入的任务的执行时间要比头结点的执行时间要晚，这就不是我们想要的结果了，这会导致队列中的顺序不正确。
- 同理也可以算一下在执行compareTo方法中的`long diff = getDelay(NANOSECONDS) - other.getDelay(NANOSECONDS);`时也会有这种情况；
- 所以在triggerTime方法中对delay的大小做了判断，就是为了防止这种情况发生。

如果执行了overflowFree方法呢，这时`headDelay = 95 - 100 = -5`，然后执行`delay = 1023 + (-5) = 1018`，那么triggerTime会返回`100 + 1018 = -930`，再执行compareTo方法中的`long diff = time - x.time;`时，`diff = -930 - 95 = -930 - 100 + 5 = 1018 + 5 = 1023`，没有溢出，符合正常的预期。

所以，overflowFree方法中把已经超时的部分时间给减去，就是为了避免在compareTo方法中出现溢出情况。

（这段代码看的很痛苦，一般情况下也不会发生这种情况，谁会传一个Long.MAX_VALUE呢。要知道Long.MAX_VALUE的纳秒数换算成年的话是292年）

###  reExecutePeriodic方法

```java
void reExecutePeriodic(RunnableScheduledFuture<?> task) {
    if (canRunInCurrentRunState(true)) {
        super.getQueue().add(task);
        if (!canRunInCurrentRunState(true) && remove(task))
            task.cancel(false);
        else
            ensurePrestart();
    }
}
```

该方法和delayedExecute方法类似，不同的是：

1. 由于调用reExecutePeriodic方法时已经执行过一次周期性任务了，所以不会reject当前任务；
2. 传入的任务一定是周期性任务。

### onShutdown方法

onShutdown方法是ThreadPoolExecutor中的钩子方法，在ThreadPoolExecutor中什么都没有做，该方法是在执行shutdown方法时被调用：

```java
@Override void onShutdown() {
    BlockingQueue<Runnable> q = super.getQueue();
    // 获取在线程池已 shutdown 的情况下是否继续执行现有延迟任务
    boolean keepDelayed =
        getExecuteExistingDelayedTasksAfterShutdownPolicy();
    // 获取在线程池已 shutdown 的情况下是否继续执行现有定期任务
    boolean keepPeriodic =
        getContinueExistingPeriodicTasksAfterShutdownPolicy();
    // 如果在线程池已 shutdown 的情况下不继续执行延迟任务和定期任务
    // 则依次取消任务，否则则根据取消状态来判断
    if (!keepDelayed && !keepPeriodic) {
        for (Object e : q.toArray())
            if (e instanceof RunnableScheduledFuture<?>)
                ((RunnableScheduledFuture<?>) e).cancel(false);
        q.clear();
    }
    else {
        // Traverse snapshot to avoid iterator exceptions
        for (Object e : q.toArray()) {
            if (e instanceof RunnableScheduledFuture) {
                RunnableScheduledFuture<?> t =
                    (RunnableScheduledFuture<?>)e;
                // 如果有在 shutdown 后不继续的延迟任务或周期任务，则从队列中删除并取消任务
                if ((t.isPeriodic() ? !keepPeriodic : !keepDelayed) ||
                    t.isCancelled()) { // also remove if already cancelled
                    if (q.remove(t))
                        t.cancel(false);
                }
            }
        }
    }
    tryTerminate();
}
```

## 参考

1. [深入理解Java线程池：ScheduledThreadPoolExecutor](https://www.jianshu.com/p/925dba9f5969)