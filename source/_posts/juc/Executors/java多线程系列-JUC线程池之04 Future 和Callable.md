---
title: java多线程系列-JUC线程池之04 Future 和Callable
tags:
  - 线程池
  - JUC
categories:
  - java
  - 线程池
author: zhangke
abbrlink: d4c4bc29
date: 2018-07-24 15:12:00
---
# java多线程系列-JUC线程池之04 Future、Callable和FutureTask分析

### 概要

1. Callable和Future简介
2. ThreadPoolExecutor中submit分析
3. FutureTask源码分析

### 1. Callable 和 Future 简介

Executor框架使用Runnable作为其基本的任务表示形式。Runnable是一种有很大局限的抽象，虽然run能写入到日志文件或者将结果放入某个共享的数据结构，但它不能返回一个值或抛出一个受检查的异常。

许多任务实际上都是存在延迟的计类如执行数据库插叙、网络上获取资源，或者计算某个复杂的功能，对于这些任务，Callable是一种更好的抽象：他认为主入口点（即call）将返回一个值，并可能抛出一个异常。
<!-- more -->

在Executor中包含了一些辅助的方法能将其他类型的任务封装为一个Callabe，其实主要是Runnable类型对象。

Runnable和Callable描述的都是抽象的计算任务。这些任务通常是有范围的，即都有一个明确的起始点，并且最终会结束。Executor执行的任务有4个声明周期阶段：创建、提交、开始和完成。由于有些任务可能要执行很长的时间，因此通常希望能够取消这些任务。在Executor框架中，已提交但尚未开始的任务可以取消，但对于那些已经开始执行的任务，只能当他们响应中断时，才能取消，也就是你自己在封装任务的时候，在里面封装了响应中断的逻辑，即`Thread.interput()`。

Future表示一个任务的生命周期，并定义相应的方法来判断是否已经完成或取消，以及获取任务的结果和取消任务等。并且在Future规范中的隐含意义是，任务声明周期只能前进，不能后退，就像ExecutorService的生命周期一样。当某个任务完成后，他就永远停留在完成状态上。

**1. Callable**

Callable 是一个接口，它只包含一个call()方法。Callable是一个返回结果并且可能抛出异常的任务。为了便于理解，我们可以将Callable比作一个Runnable接口，而Callable的call()方法则类似于Runnable的run()方法。

Callable的源码如下：

```
public interface Callable<V> {
		V call() throws Exception;
}
```

**说明**：从中我们可以看出Callable支持泛型。 

### 2. Future

Future 是一个接口。它用于表示异步计算的结果。提供了检查计算是否完成的方法，以等待计算的完成，并获取计算的结果。

Future的源码如下：

```java
public interface Future<V> {
// 试图取消对此任务的执行。
boolean cancel(boolean mayInterruptIfRunning)

// 如果在任务正常完成前将其取消，则返回 true。
boolean isCancelled()

// 如果任务已完成，则返回 true。
boolean isDone()

// 如有必要，等待计算完成，然后获取其结果。
V  get() throws InterruptedException, ExecutionException;

// 如有必要，最多等待为使计算完成所给定的时间之后，获取其结果（如果结果可用）。
V  get(long timeout, TimeUnit unit)
     throws InterruptedException, ExecutionException, TimeoutException;
}
```

### 2. ThreadPoolExecutor中submit分析

前面我们已经对ThreadPoolExecutor中execute进行了分析，在execute中执行的任务是没有返回结果。这在很大程度上限制了这个方法的使用，因此在ExecutorService中提供了submit方法，可以在任务执行完成后返回结果，这个方法有三个重载方法，源码如下：

```java
//执行Runnable接口，返回一个没有任何结果的Future
public Future<?> submit(Runnable task) {
   if (task == null) 
       throw new NullPointerException();
   RunnableFuture<Void> ftask = newTaskFor(task, null);
   execute(ftask);
   return ftask;
}
//执行Runnable接口，并返回一个带有result结果的Future
public <T> Future<T> submit(Runnable task, T result) {
   if (task == null) 
       throw new NullPointerException();
   RunnableFuture<T> ftask = newTaskFor(task, result);
   execute(ftask);
   return ftask;
}
	
//执行Callable接口，并返回Future对象
public <T> Future<T> submit(Callable<T> task) {
   if (task == null) 
       throw new NullPointerException();
   RunnableFuture<T> ftask = newTaskFor(task);
   execute(ftask);
   return ftask;
}
```

通过看上面的代码，大体上代码的结构都是相同的，首先通过newTaskFor方法创建一个RunnableFuture对象，然后使用execute执行这个任务。

下面我们看一下newTaskFor这个方法，这个方法也包括俩个重载的方法，源码如下

```java
protected <T> RunnableFuture<T> newTaskFor(Runnable runnable, T value) {
		return new FutureTask<T>(runnable, value);
}

protected <T> RunnableFuture<T> newTaskFor(Callable<T> callable) {
 		return new FutureTask<T>(callable);
}
```

这个方法是将提供的Runnable和Callable接口封装在FutureTask内，然后返回一个RunnableFuture对象，事实上，FutureTask实现了RunnablFuture这个接口，下面我们来具体看一下`FutureTask`

###3.  FutureTask源码分析

Future继承体系如下

![upload successful](/images/pasted-170.png)

从上面可以看出FutureTask实现了RunnableFuture，而这个接口就是讲Future和Runnable俩个接口集成在一起。所以上面newTaskFor方法返回RunnableFuture，这也体现了面向接口编程，方便以后进行扩展。

下面开始分析源码，首先介绍后面要用到的属性已经这个对象的生命周期（毕竟Future的一个责任就是检测任务是否已完成）

```java
// 当前Future的状态
private volatile int state;
// 当前运行的任务，运行完成后变为null
private Callable<V> callable;
//保存运行的结果或者异常，任务完成后返回
private Object outcome; // non-volatile, protected by state reads/writes
// 执行当前callable的线程，使用CAS设置当运行任务时
private volatile Thread runner;
/** 等待获取的记过的线程 */
private volatile WaitNode waiters;

```

下面我们先来了解一下，Future表示一个任务的状态，有以下几种，

```java
NEW      ：任务新创建状态   
COMPLETING  ：任务完成状态
NORMAL 		：正常完成状态
EXCEPTIONAL ：异常完成状态
CANCELLED    ：取消状态
INTERRUPTING ：正在中断状态
INTERRUPTED  ：已经被中断状态
```

状态只能从一个状态转变到另外一个状态，不能后退，状态的转换大致上有以下几种：

```
NEW -> COMPLETING -> NORMAL
NEW -> COMPLETING -> EXCEPTIONAL
NEW -> CANCELLED
NEW -> INTERRUPTING -> INTERRUPTED
```

 FutureTask构造函数

```java
public FutureTask(Callable<V> callable) {
    if (callable == null)
       throw new NullPointerException();
    this.callable = callable;
    // state记录FutureTask的状态
    this.state = NEW;       // ensure visibility of callable
}

public FutureTask(Runnable runnable, V result) {
	//将给定的runnable接口封装成Callable类，
   this.callable = Executors.callable(runnable, result);
   this.state = NEW;       // ensure visibility of callable
}
```

下面来具体分析一下 FutureTask中run函数

在newTaskFor()新建一个ftask对象之后，会通过execute(ftask)执行该任务。此时ftask被当作一个Runnable对象进行执行，最终会调用到它的run()方法:源码如下：

```java
public void run() {
    //如果当前状态不处于NEW状态，则直接返回，
    if (state != NEW ||
       !UNSAFE.compareAndSwapObject(this, runnerOffset,
                                    null, Thread.currentThread()))
       return;
    try {
       // 将callable对象赋值给c。
       Callable<V> c = callable;
        // 如果任务不为空并且当前任务状态为NEW，则执行
       if (c != null && state == NEW) {
           V result;
           boolean ran;
           try {
               // 执行Callable的call()方法，并保存结果到result中。
               result = c.call();
               ran = true;
           } catch (Throwable ex) {
               // 出现异常，则将结果设置为null
               result = null;
               ran = false;
               setException(ex);
           }
           // 如果运行成功，则将result保存
           if (ran)
               set(result);
       }
    } finally {
       runner = null;
       // 设置“state状态标记”
       int s = state;
       if (s >= INTERRUPTING)
           handlePossibleCancellationInterrupt(s);
    }
}
```

**说明**：run()中会执行Callable对象的call()方法，如果正常执行完成，最终将结果保存到result中，通过set(result)将result保存，并唤醒所有等待的获取结果的线程。 或者执行遇到异常，通过setException将异常保存，并唤醒所有等待结果的线程。现在我们来具体看看set和setException这俩个函数

```java
//任务执行完成，设置执行结果，并设置当前任务状态   
protected void set(V v) {
   if (UNSAFE.compareAndSwapInt(this, stateOffset, NEW, COMPLETING)) {
       outcome = v;
       UNSAFE.putOrderedInt(this, stateOffset, NORMAL); // final state
       //唤醒所有等待的此任务完成的线程
       finishCompletion();
   }
}
//此方法和上面的set方法执行流程一样，只是改变当前任务的状态时异常状态
protected void setException(Throwable t) {
   if (UNSAFE.compareAndSwapInt(this, stateOffset, NEW, COMPLETING)) {
       outcome = t;
       UNSAFE.putOrderedInt(this, stateOffset, EXCEPTIONAL); // final state
       finishCompletion();
   }
}
```

其实方法大体上是类似的，首先通过CAS变量设置任务状态，并设置执行的结果或异常到outcome中，然后唤醒所有的等待的线程，这个等待的线程是通过future.get()获取任务结果而造成的等待，这里我们先说这个方法，然后在来说唤醒等待。

 FutureTask的get函数源码

get是用来得到任务执行的结果，如果任务没有执行完成，就会暂停当前任务的执行：

```java
public V get() throws InterruptedException, ExecutionException {
   int s = state;
   if (s <= COMPLETING)
       s = awaitDone(false, 0L);
   return report(s);
}
```

基本上代码逻辑很清晰，先判断任务是否完成，如果没有完成则进入等待直到完成，任务完成之后通过report方法返回结果

我们首先看看后面涉及到的一个对象，不过这里涉及到一个链表节点的表示，源码如下

```java
static final class WaitNode {
    volatile Thread thread;
    volatile WaitNode next;
    WaitNode() { thread = Thread.currentThread(); }
}
```

上面可以看出，就是将所有等待的线程用链表的形式表示出来，下面具体看看awaitDone方法：

```java
private int awaitDone(boolean timed, long nanos)
   throws InterruptedException {
   //得到截止时间
   final long deadline = timed ? System.nanoTime() + nanos : 0L;
   WaitNode q = null;
   boolean queued = false;
   //循环判断，直到任务执行完成
   for (;;) {
       // 如果线程被中止，将当前线程从等待节点中移除
       if (Thread.interrupted()) {
           removeWaiter(q);
           throw new InterruptedException();
       }

       //得到任务状态
       int s = state;
       
       //如果任务是完成状态，则直接返回结果
       if (s > COMPLETING) {
           if (q != null)
               q.thread = null;
           return s;
       }
       //如果是正在执行状态，当前线程让出cpu
       else if (s == COMPLETING) // cannot time out yet
           Thread.yield();
       //创建等待节点
       else if (q == null)
           q = new WaitNode();
       //将等待节点插入等待队列
       else if (!queued)
           queued = UNSAFE.compareAndSwapObject(this, waitersOffset,
                                                q.next = waiters, q);
       //如果是有等待时间限制
       else if (timed) {
           nanos = deadline - System.nanoTime();
           //过了等待时间，则删除等待对应的等待节点
           if (nanos <= 0L) {
               removeWaiter(q);
               return state;
           }
           //阻塞当前线程
           LockSupport.parkNanos(this, nanos);
       }
       else
           // 阻塞当前线程，这回让出cpu
           LockSupport.park(this);
   }
}
```

其实上面逻辑还是比较简单，首先判断任务是否已经执行完成，如果没有则创建一个等待节点，将当前线程插入到等待链表中，然后进入等待状态，等待任务完成被唤醒，同时会让出cpu。如果已经完成，则直接返回。这里为什么用for循环，是因为有可能任务还没有完成，但线程被唤醒，类如线程响应中断信号，这里就需要在此检查唤醒的条件是否是任务已经执行完成（完成还代表任务执行出现异常）。

下面我们来看上面遗留的一个方法，任务执行完成后，唤醒所有等待的线程：源码如下：

```java
//唤醒锁等带此任务执行完成的线程
private void finishCompletion() {
   // assert state > COMPLETING;
   for (WaitNode q; (q = waiters) != null;) {
       if (UNSAFE.compareAndSwapObject(this, waitersOffset, q, null)) {
           for (;;) {
               Thread t = q.thread;
               if (t != null) {
                   q.thread = null;
                   LockSupport.unpark(t);
               }
               WaitNode next = q.next;
               if (next == null)
                   break;
               q.next = null; // unlink to help gc
               q = next;
           }
           break;
       }
   }
   //这个方法是一个空方法，如果希望任务执行完成后调用一个类似于callback回调，继承此类，
   //然后封装此方法
   done();

   callable = null;        // to reduce footprint
}
```

源码比较简单，就不在解释了，我们来看看为什么将唤醒逻辑放置在run方法中。其实这样设计是因为任务是否执行完成，Future是无法决定的，只有执行这个任务的线程才知道，所以就把唤醒线程的代码放在run方法里面。

**取消任务**

```java
public boolean cancel(boolean mayInterruptIfRunning) {
    // 如果任务处于NEW状态，则直接返回false，
    if (!(state == NEW &&
          UNSAFE.compareAndSwapInt(this, stateOffset, NEW,
                                   mayInterruptIfRunning ? INTERRUPTING : CANCELLED)))
        return false;
    
	// mayInterruptIfRunning如果true，则会直接发出线程终端信号
    // 让当前执行的任务退出，至于退不退出，则要看任务里面有没有响应中断信号的处理逻辑
    try {   
        if (mayInterruptIfRunning) {
            try {
                Thread t = runner;
                if (t != null)
                    t.interrupt();
            } finally { // final state
                UNSAFE.putOrderedInt(this, stateOffset, INTERRUPTED);
            }
        }
    } finally {
        finishCompletion();
    }
    return true;
}

```

上面取消只有在任务处于NEW状态时才能取消成功，如果强制正在执行的任务取消，则要看任务中有没有响应中断的处理逻辑。这个我们看下面的例子就能明白

```java
package JUC.executor;

import java.util.concurrent.*;

public class ExecutorStudy {

    public static void main(String[] args) throws InterruptedException, ExecutionException {

        ExecutorService executorService = Executors.newSingleThreadExecutor();
        Future future = executorService.submit(() -> {
            while (true) {
                System.out.println("Thread is running...");
                long time = System.currentTimeMillis();
                // 使用while循环模拟 sleep
                while ((System.currentTimeMillis() - time < 1000)) {
                }
            }
        });
		// 等待线程启动
        Thread.sleep(1000);
        
        while (true) {
            Thread.sleep(1000);
            System.out.println(future.cancel(true));
            System.out.println(future.isCancelled());
            System.out.println(future.isDone());
            future.get();
        }
    }
}
```

上面就是一个，任务正在执行，我们发出了强制任务取消执行，但是任务依然回执行，因为我们没有在任务执行逻辑中封装响应中断的处理逻辑。这个例子你运行一下就会明白。

### 总结

我们来看看FutureTask的执行流程，首先创建一个任务，并将任务放置在队列中，等待被运行，这时任务处于NEW状态，如果任务执行完成，则进入完成状态，否则进入其他的状态。如果在执行期间，调用了get方法，线程就会被阻塞，让出cpu等待任务执行完成之后被唤醒。当然还有可能出现异常被唤醒。这就不在仔细解释。具体的可以看上面的流程分析。