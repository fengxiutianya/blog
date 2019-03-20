---
title: java多线程系列-JUC线程池之 01 线程池架构
tags:
  - JUC
  - 线程池
categories:
  - java
  - juc
  - 线程池
abbrlink: 984191f2
date: 2018-07-23 14:07:00
---
# java多线程系列-JUC线程池之 01 线程池架构

### 概要

>1. 线程池整体架构介绍
>2. 简单示例
<!-- more -->

### 1. 线程池整体架构介绍

>### 1. Executor
>
>> Executor将任务的执行和任务的创建分离开来。他提供了执行的接口，是来执行任务的。只要提交的任务实现了Runnable接口，就可以将此任务交给Executor来执行，这个接口只包含一个函数，代码如下:
>>
>> ```
>> public interface Executor{
>>     //在未来执行给定的任务
>>     void	execute(Runnable command)
>> }
>> ```
>>
>> 
>
>### 2. ExecutorService
>
>>现在可以通过Executor来实现任务的运行。通常Executor的实现通常会创建线程来执行任务。但JVM只有在所有非守护线程全部终止后才会退出，因此如果无法正确的关闭Executor，那么JVM将无法结束。
>>
>>关闭任务的方式：
>>
>>1. 直接关闭，相当于断开电源
>>2. 执行完所有当前线程上执行的任务，不在接收新的任务。然后关闭
>>
>>此时Executor接口定义的方法不足以满足这些要求的实现，所以有了ExecutorService接口。添加了一些用于生命周期管理的方法（同时还有一些用于任务提交的便利方法）：
>>
>>```java
>>// 请求关闭、发生超时或者当前线程中断，无论哪一个首先发生之后，都将导致阻塞，直到所有任务完成执行。
>>boolean awaitTermination(long timeout, TimeUnit unit)
>>    
>>// 执行给定的任务，当所有任务完成时，返回保持任务状态和结果的 Future 列表。
>><T> List<Future<T>> invokeAll(Collection<? extends Callable<T>> tasks)
>>// 执行给定的任务，当所有任务完成或超时期满时（无论哪个首先发生），返回保持任务状态和结果的 Future 列表。
>><T> List<Future<T>> invokeAll(Collection<? extends Callable<T>> tasks, long timeout, TimeUnit unit)
>>// 执行给定的任务，如果某个任务已成功完成（也就是未抛出异常），则返回其结果。
>><T> T invokeAny(Collection<? extends Callable<T>> tasks)
>>// 执行给定的任务，如果在给定的超时期满前某个任务已成功完成（也就是未抛出异常），则返回其结果。
>><T> T invokeAny(Collection<? extends Callable<T>> tasks, long timeout, TimeUnit unit)
>>    
>>    
>>// 如果此执行程序已关闭，则返回 true。
>>boolean isShutdown()
>>// 如果关闭后所有任务都已完成，则返回 true。
>>boolean isTerminated()
>>    
>>    
>>// 启动一次顺序关闭，执行以前提交的任务，但不接受新任务。
>>void shutdown()
>>// 试图停止所有正在执行的活动任务，暂停处理正在等待的任务，并返回等待执行的任务列表。
>>List<Runnable> shutdownNow()
>>    
>>    
>>// 提交一个返回值的任务用于执行，返回一个表示任务的未决结果的 Future。
>><T> Future<T> submit(Callable<T> task)
>>// 提交一个 Runnable 任务用于执行，并返回一个表示该任务的 Future。
>>Future<?> submit(Runnable task)
>>// 提交一个 Runnable 任务用于执行，并返回一个表示该任务的 Future。
>><T> Future<T> submit(Runnable task, T result)
>>```
>>
>>ExecutorService的生命周期有三种状态：运行、关闭和已终止。
>>
>>1. 在初始创建时处于运行状态，
>>
>>2. shutdown方法将执行平缓的关闭状态：不在接收新的任务，同时等待已经提交的任务执行完成，包括那些还未开始执行的任务
>>
>>3. shutdownNow方法将执行粗暴的关闭过程，将尝试取消所有运行中的任务。
>>
>>   通过isTerminated来确定线程池是否终止，终止后不同拒绝策略有不同的返回结果的方式。
>
>### **3. AbstractExecutorService**
>
>> AbstractExecutorService是一个抽象类，它实现了ExecutorService接口。AbstractExecutorService存在的目的是为ExecutorService中的函数接口提供了默认实现。方便我们定制线程池。这个类的方法和ExecutorService一样，所有就不列出来，后面再分析线程池源码时我会在来说这个类。
>
>### 4.**ThreadPoolExecutor**
>
>> ThreadPoolExecutor就是大名鼎鼎的"线程池"，它继承于AbstractExecutorService抽象类。是线程池的主要实现类，也是我们后面关注的重点，因此就现在这里提一下，后面会仔细讲。
>>
>> 
>
>### 5. **ScheduledExecutorService**
>
>>ScheduledExecutorService是一个接口，它继承于于ExecutorService。它相当于提供了"延时"和"周期执行"功能的ExecutorService。 ScheduledExecutorService提供了相应的函数接口，可以安排任务在给定的延迟后执行，也可以让任务周期的执行。
>>
>>**ScheduledExecutorService函数列表**
>>
>>````Java
>>// 创建并执行在给定延迟后启用的 ScheduledFuture。
>><V> ScheduledFuture<V> schedule(Callable<V> callable, long delay, TimeUnit unit)
>>// 创建并执行在给定延迟后启用的一次性操作。
>>ScheduledFuture<?> schedule(Runnable command, long delay, TimeUnit unit)
>>// 创建并执行一个在给定初始延迟后首次启用的定期操作，后续操作具有给定的周期；也就是将在 initialDelay 后开始执行，然后在 initialDelay+period 后执行，接着在 initialDelay + 2 * period 后执行，依此类推。
>>ScheduledFuture<?> scheduleAtFixedRate(Runnable command, long initialDelay, long period, TimeUnit unit)
>>// 创建并执行一个在给定初始延迟后首次启用的定期操作，随后，在每一次执行终止和下一次执行开始之间都存在给定的延迟。
>>ScheduledFuture<?> scheduleWithFixedDelay(Runnable command, long initialDelay, long delay, TimeUnit unit)
>>````
>>
>>
>
>### 6. **ScheduledThreadPoolExecutor**
>
>> ScheduledThreadPoolExecutor继承于ThreadPoolExecutor，并且实现了ScheduledExecutorService接口。它相当于提供了"延时"和"周期执行"功能的ExecutorService。 ScheduledThreadPoolExecutor类似于Timer，但是在高并发程序中，ScheduledThreadPoolExecutor的性能要优于Timer。
>>
>> 在没有此接口之前，我们使用Timer来做定时任务，Timer定时任务的缺陷：
>>
>> 1. 执行定时任务时，只创建一个线程，因此如果某个任务执行时间过长，会导致其他定时任务的执行周期加长
>> 2. 由于只创建了一个线程，当这个线程因为异常关闭之后，其他定时任务就无法启动。（这个问题称之为线程泄漏）
>>
>> 因此在5.0 之后很少使用这个类来做定时任务，换成了ScheduledThreadPoolExecutor来做定时任务。
>>
>> 同时要构建自己的调度任务还需要队列的支持，这时可以使用DelayQueue，他实现了BlockingQueue，并为ScheduledThreadPoolExecutor提供调度功能，DelayQUeue管理者一组Delayed对象，每个Delayed对象都有一个相应的延迟时间。在DelayQueue中，只有某个元素逾期后，才能从这个队列中take操作。
>>
>> 参数列表
>>
>> ```Java
>> // 使用给定核心池大小创建一个新 ScheduledThreadPoolExecutor。
>> ScheduledThreadPoolExecutor(int corePoolSize)
>> // 使用给定初始参数创建一个新 ScheduledThreadPoolExecutor。
>> ScheduledThreadPoolExecutor(int corePoolSize, RejectedExecutionHandler handler)
>> // 使用给定的初始参数创建一个新 ScheduledThreadPoolExecutor。
>> ScheduledThreadPoolExecutor(int corePoolSize, ThreadFactory threadFactory)
>> // 使用给定初始参数创建一个新 ScheduledThreadPoolExecutor。
>> ScheduledThreadPoolExecutor(int corePoolSize, ThreadFactory threadFactory, RejectedExecutionHandler handler)
>> 
>> // 修改或替换用于执行 callable 的任务。
>> protected <V> RunnableScheduledFuture<V> decorateTask(Callable<V> callable, RunnableScheduledFuture<V> task)
>> // 修改或替换用于执行 runnable 的任务。
>> protected <V> RunnableScheduledFuture<V> decorateTask(Runnable runnable, RunnableScheduledFuture<V> task)
>> // 使用所要求的零延迟执行命令。
>> void execute(Runnable command)
>> // 获取有关在此执行程序已 shutdown 的情况下、是否继续执行现有定期任务的策略。
>> boolean getContinueExistingPeriodicTasksAfterShutdownPolicy()
>> // 获取有关在此执行程序已 shutdown 的情况下是否继续执行现有延迟任务的策略。
>> boolean getExecuteExistingDelayedTasksAfterShutdownPolicy()
>> // 返回此执行程序使用的任务队列。
>> BlockingQueue<Runnable> getQueue()
>> // 从执行程序的内部队列中移除此任务（如果存在），从而如果尚未开始，则其不再运行。
>> boolean remove(Runnable task)
>> // 创建并执行在给定延迟后启用的 ScheduledFuture。
>> <V> ScheduledFuture<V> schedule(Callable<V> callable, long delay, TimeUnit unit)
>> // 创建并执行在给定延迟后启用的一次性操作。
>> ScheduledFuture<?> schedule(Runnable command, long delay, TimeUnit unit)
>> // 创建并执行一个在给定初始延迟后首次启用的定期操作，后续操作具有给定的周期；也就是将在 initialDelay 后开始执行，然后在 initialDelay+period 后执行，接着在 initialDelay + 2 * period 后执行，依此类推。
>> ScheduledFuture<?> scheduleAtFixedRate(Runnable command, long initialDelay, long period, TimeUnit unit)
>> // 创建并执行一个在给定初始延迟后首次启用的定期操作，随后，在每一次执行终止和下一次执行开始之间都存在给定的延迟。
>> ScheduledFuture<?> scheduleWithFixedDelay(Runnable command, long initialDelay, long delay, TimeUnit unit)
>> // 设置有关在此执行程序已 shutdown 的情况下是否继续执行现有定期任务的策略。
>> void setContinueExistingPeriodicTasksAfterShutdownPolicy(boolean value)
>> // 设置有关在此执行程序已 shutdown 的情况下是否继续执行现有延迟任务的策略。
>> void setExecuteExistingDelayedTasksAfterShutdownPolicy(boolean value)
>> // 在以前已提交任务的执行中发起一个有序的关闭，但是不接受新任务。
>> void shutdown()
>> // 尝试停止所有正在执行的任务、暂停等待任务的处理，并返回等待执行的任务列表。
>> List<Runnable> shutdownNow()
>> // 提交一个返回值的任务用于执行，返回一个表示任务的未决结果的 Future。
>> <T> Future<T> submit(Callable<T> task)
>> // 提交一个 Runnable 任务用于执行，并返回一个表示该任务的 Future。
>> Future<?> submit(Runnable task)
>> // 提交一个 Runnable 任务用于执行，并返回一个表示该任务的 Future。
>> <T> Future<T> submit(Runnable task, T result)
>> ```
>>
>> 
>
>### 7. Executors
>
>>Executors是个静态工厂类。它通过静态工厂方法返回ExecutorService、ScheduledExecutorService、ThreadFactory 和 Callable 等类的对象。
>>
>>```java
>>// 返回 Callable 对象，调用它时可运行给定特权的操作并返回其结果。
>>static Callable<Object> callable(PrivilegedAction<?> action)
>>// 返回 Callable 对象，调用它时可运行给定特权的异常操作并返回其结果。
>>static Callable<Object> callable(PrivilegedExceptionAction<?> action)
>>// 返回 Callable 对象，调用它时可运行给定的任务并返回 null。
>>static Callable<Object> callable(Runnable task)
>>// 返回 Callable 对象，调用它时可运行给定的任务并返回给定的结果。
>>static <T> Callable<T> callable(Runnable task, T result)
>>// 返回用于创建新线程的默认线程工厂。
>>static ThreadFactory defaultThreadFactory()
>>// 创建一个可根据需要创建新线程的线程池，但是在以前构造的线程可用时将重用它们。
>>static ExecutorService newCachedThreadPool()
>>// 创建一个可根据需要创建新线程的线程池，但是在以前构造的线程可用时将重用它们，并在需要时使用提供的 ThreadFactory 创建新线程。
>>static ExecutorService newCachedThreadPool(ThreadFactory threadFactory)
>>// 创建一个可重用固定线程数的线程池，以共享的无界队列方式来运行这些线程。
>>static ExecutorService newFixedThreadPool(int nThreads)
>>// 创建一个可重用固定线程数的线程池，以共享的无界队列方式来运行这些线程，在需要时使用提供的 ThreadFactory 创建新线程。
>>static ExecutorService newFixedThreadPool(int nThreads, ThreadFactory threadFactory)
>>// 创建一个线程池，它可安排在给定延迟后运行命令或者定期地执行。
>>static ScheduledExecutorService newScheduledThreadPool(int corePoolSize)
>>// 创建一个线程池，它可安排在给定延迟后运行命令或者定期地执行。
>>static ScheduledExecutorService newScheduledThreadPool(int corePoolSize, ThreadFactory threadFactory)
>>// 创建一个使用单个 worker 线程的 Executor，以无界队列方式来运行该线程。
>>static ExecutorService newSingleThreadExecutor()
>>// 创建一个使用单个 worker 线程的 Executor，以无界队列方式来运行该线程，并在需要时使用提供的 ThreadFactory 创建新线程。
>>static ExecutorService newSingleThreadExecutor(ThreadFactory threadFactory)
>>// 创建一个单线程执行程序，它可安排在给定延迟后运行命令或者定期地执行。
>>static ScheduledExecutorService newSingleThreadScheduledExecutor()
>>// 创建一个单线程执行程序，它可安排在给定延迟后运行命令或者定期地执行。
>>static ScheduledExecutorService newSingleThreadScheduledExecutor(ThreadFactory threadFactory)
>>// 返回 Callable 对象，调用它时可在当前的访问控制上下文中执行给定的 callable 对象。
>>static <T> Callable<T> privilegedCallable(Callable<T> callable)
>>// 返回 Callable 对象，调用它时可在当前的访问控制上下文中，使用当前上下文类加载器作为上下文类加载器来执行给定的 callable 对象。
>>static <T> Callable<T> privilegedCallableUsingCurrentClassLoader(Callable<T> callable)
>>// 返回用于创建新线程的线程工厂，这些新线程与当前线程具有相同的权限。
>>static ThreadFactory privilegedThreadFactory()
>>// 返回一个将所有已定义的 ExecutorService 方法委托给指定执行程序的对象，但是使用强制转换可能无法访问其他方法。
>>static ExecutorService unconfigurableExecutorService(ExecutorService executor)
>>// 返回一个将所有已定义的 ExecutorService 方法委托给指定执行程序的对象，但是使用强制转换可能无法访问其他方法。
>>static ScheduledExecutorService unconfigurableScheduledExecutorService(ScheduledExecutorService executor)
>>```
>>
>>
>
>

### 2. 简单示例

>```java
>import java.util.concurrent.Executors;
>import java.util.concurrent.ExecutorService;
>
>public class ThreadPoolDemo1 {
>
>    public static void main(String[] args) {
>        // 创建一个可重用固定线程数的线程池
>        ExecutorService pool = Executors.newFixedThreadPool(2);
>        // 创建实现了Runnable接口对象，Thread对象当然也实现了Runnable接口
>        Thread ta = new MyThread();
>        Thread tb = new MyThread();
>        Thread tc = new MyThread();
>        Thread td = new MyThread();
>        Thread te = new MyThread();
>        // 将线程放入池中进行执行
>        pool.execute(ta);
>        pool.execute(tb);
>        pool.execute(tc);
>        pool.execute(td);
>        pool.execute(te);
>        // 关闭线程池
>        pool.shutdown();
>    }
>}
>
>class MyThread extends Thread {
>
>    @Override
>    public void run() {
>        System.out.println(Thread.currentThread().getName()+ " is running.");
>    }
>}
>```
>
>**运行结果**：
>
>```
>pool-1-thread-1 is running.
>pool-1-thread-2 is running.
>pool-1-thread-1 is running.
>pool-1-thread-2 is running.
>pool-1-thread-1 is running.
>```
>
>**结果说明**：
>主线程中创建了线程池pool，线程池的容量是2。即，线程池中最多能同时运行2个线程。
>紧接着，将ta,tb,tc,td,te这3个线程添加到线程池中运行。
>最后，通过shutdown()关闭线程池。