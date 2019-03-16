---
tags:
  - JUC
  - 线程池
categories:
  - java
  - 线程池
author: zhangke
title: java多线程系列-JUC线程池之02 ThreadPoolExecutor 执行流程分析
abbrlink: ca60f1d2
date: 2018-07-23 14:35:00
---
# java多线程系列-JUC线程池之02 ThreadPoolExecutor 执行流程分析

### 概要

>1. 线程池使用例子
>2. 线程池状态
>3. 任务执行流程分析
<!-- more -->

### 1. 线程池使用例子

>简单例子
>
>```
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
>示例中，使用了Excutors工具类来创建线程池，并提交任务到线程池上运行，然后关闭线程池，这是一个简单的实例。接下来我们将进行ThreadPoolExecutor深入分析。
>
>

### 2. 线程池状态

>在线程池中使用了一个AtomicInteger对象来表示线程的状态和任务的数量。其中Integer是32位，用高三位来表示线程池的状态，至于怎么计算不是这里的重点，这里我们先讲解任务的状态。
>
>线程池中任务的状态有以下5种：
>
>```
>RUNNING   :接收新的任务和处理队列中的任务
>SHUTDOWN  :不在接收新的任务和但是处理队列中的任务。
>STOP  	  :不在接收新的任务，同时不在处理队列中的任务，线程上正在运行的任务也会被打断。
>TIDYING   :所有的任务已经结束，并且线程的数量为0，线程的状态转换成清理的状态，接下来将会运行
>			terminated()方法。
>TERMINATED:terminated()执行完成
>```
>
>状态的转换:
>
>```
>RUNNING -> SHUTDOWN：调用 shutdown()方法后，也会包含一些回收的处理
>(RUNNING or SHUTDOWN) -> STOP：调用shutdownNow()
>SHUTDOWN -> TIDYING：当线程池和任务队列都为空
>STOP -> TIDYING：当线程池为空
>TIDYING -> TERMINATED： 当terminated() 方法已经完成
>```
>
>具体的状态转换如上面所示。另外线程池的状态是通过比特为来表示的，使用ctl这个原子变量的高三位来确定的。具体的如下所示。
>
>```java
>private static final int RUNNING    = -1 << COUNT_BITS;
>private static final int SHUTDOWN   =  0 << COUNT_BITS;
>private static final int STOP       =  1 << COUNT_BITS;
>private static final int TIDYING    =  2 << COUNT_BITS;
>private static final int TERMINATED =  3 << COUNT_BITS;
>```

### 3. 线程池执行任务分析

>在讲解运行过程前，我们先看下`ThreadPoolExecutor`中的几个比较重要的成员变量：
>
>```java
>// 高三位表示当前线程池的状态，低29为表示线程的数量,所以线程的数量最大是(2^29)-1
> private final AtomicInteger ctl = new AtomicInteger(ctlOf(RUNNING, 0));
> 
>// 任务队列
> private final BlockingQueue<Runnable> workQueue;
>
>// 用于同步线程池，也就是线面对workers的操作
>private final ReentrantLock mainLock = new ReentrantLock();
>
>// 线程池存放线程的地点
>private final HashSet<Worker> workers = new HashSet<Worker>();
>
>// 用于支持awaitTermination的等待条件
>private final Condition termination = mainLock.newCondition();
>
>// 记录线程池中同时存在的最大线程数的历史记录
>private int largestPoolSize;
>
>//完成任务的数量，在工作线程结束时才会进行更新
>private long completedTaskCount
>
>// 创建线程的工厂
>private volatile ThreadFactory threadFactory;
>
>// 线程池的拒绝策略
>private volatile RejectedExecutionHandler handler;
>
>// 线程空闲的最大时间，如果超过这个会关闭这个线程，
>// 和下面的allowCoreThreadTimeOut一起使用
>private volatile long keepAliveTime;
>
>// true 核心线程也可以被关闭，false，核心线程不能被关闭
>private volatile boolean allowCoreThreadTimeOut;
>
>// 核心线程的大小
>private volatile int corePoolSize;
>
>//最大线程的数量
>private volatile int maximumPoolSize;
>```
>
>这边重点解释下 `corePoolSize`、`maximumPoolSize`、`workQueue`两个变量，这两个变量涉及到线程池中创建线程个数的一个策略。
>`corePoolSize`： 这个变量我们可以理解为线程池的核心大小，举个例子来说明（corePoolSize假设等于10，maximumPoolSize等于20）：
>
>1. 有一个部门，其中有10（corePoolSize）名工人，当有新任务来了后，领导就分配任务给工人去做，每个工人只能做一个任务。
>2. 当10个工人都在忙时，新来的任务就要放到队列（workQueue）中等待。
>3. 当任务越积累越多，远远超过工人做任务的速度时，领导就想了一个办法：从其他部门借10个工人来，借的数量有一个公式（maximumPoolSize - corePoolSize）来计算。然后把新来的任务分配给借来的工人来做。
>4. 但是如果速度还是还不急的话，可能就要采取措施来放弃一些任务了（RejectedExecutionHandler）。
>等到一定时间后，任务都完成了，工人比较闲的情况下，就考虑把借来的10个工人还回去（根据keepAliveTime判断）
>5. 也就是说corePoolSize就是线程池大小，maximumPoolSize在我看来是线程池的一种补救措施，即任务量突然过大时的一种补救措施。
>
>### 任务执行：execute
>
>这个方法在ThreadPoolExecutor中的源码如下
>
>```java
>public void execute(Runnable command) {
>	//如果任务是空，则抛出空指针异常
>   if (command == null)
>       throw new NullPointerException();
>	//得到当前ctl的值，方便下面计算	
>   int c = ctl.get();
>	//计算当前线程池中线程的数量，如果小于核心线程数，则添加线程
>   if (workerCountOf(c) < corePoolSize) {
>       // 则通过addWorker(command, true)新建一个线程，并将任务(command)添加到该线程
>       //中；然后，启动该线程从而执行任务。
>       if (addWorker(command, true))
>           return;
>       c = ctl.get();
>   }
>    // 当线程池中的任务数量 >= "核心池大小"时，
>	 // 而且，"线程池处于运行状态"时，则尝试将任务添加到阻塞队列中。
>   if (isRunning(c) && workQueue.offer(command)) {
>        // 再次确认“线程池状态”，若线程池异常终止了，则删除任务；
>       //然后通过reject()执行相应的拒绝策略的内容。
>       int recheck = ctl.get();
>       if (! isRunning(recheck) && remove(command))
>           reject(command);
>       // 否则，如果"线程池中任务数量"为0，则通过addWorker(null, false)尝试新建一个线
>       // 程，新建线程对应的任务为null。防止线程池被关闭
>       else if (workerCountOf(recheck) == 0)
>           addWorker(null, false);
>   }
>  //这里是启动小于maxpoolSize的线程
>  //如果添加任务到队列中不成功，则试图通过addWorker(command, false)新建一个线程，
>  //并将任务(command)添加到该线程中；然后，启动该线程从而执行任务。
>  // 如果addWorker(command, false)执行失败，则通过reject()执行相应的拒绝策略的内容。
>   else if (!addWorker(command, false))
>       reject(command);
>}
>}
>```
>
>**说明**：execute()的作用是将任务添加到线程池中执行。它会分为3种情况进行处理：        
>
> **情况1** -- 如果"线程池中任务数量" < "核心池大小"时，即线程池中少于corePoolSize个任务；此时就新建一个线程，并将该任务添加到线程中进行执行。         
>
>**情况2** -- 如果"线程池中任务数量" >= "核心池大小"，并且"线程池是允许状态"；此时，则将任务添加到阻塞队列中阻塞等待。在该情况下，会再次确认"线程池的状态"，如果"第2次读到的线程池状态"和"第1次读到的线程池状态"不同，则从阻塞队列中删除该任务。         
>
>**情况3** -- 非以上两种情况。在这种情况下，尝试新建一个线程，并将该任务添加到线程中进行执行。如果执行失败，则通过reject()拒绝该任务。
>
>到这里，大部分朋友应该对任务提交给线程池之后到被执行的整个过程有了一个基本的了解，下面总结一下：
>
>1. 首先，要清楚corePoolSize和maximumPoolSize的含义；
>2. 其次，要知道Worker是用来起到什么作用的；
>3. 要知道任务提交给线程池之后的处理策略，这里总结一下主要有4点：
>
>- 如果当前线程池中的线程数目小于corePoolSize，则每来一个任务，就会创建一个线程去执行这个任务；
>- 如果当前线程池中的线程数目>=corePoolSize，则每来一个任务，会尝试将其添加到任务缓存队列当中，若添加成功，则该任务会等待空闲线程将其取出去执行；若添加失败（一般来说是任务缓存队列已满），则会尝试创建新的线程去执行这个任务；
>- 如果当前线程池中的线程数目达到maximumPoolSize，则会采取任务拒绝策略进行处理；
>- 如果线程池中的线程数量大于 corePoolSize时，如果某线程空闲时间超过keepAliveTime，线程将被终止，直至线程池中的线程数目不大于 corePoolSize；如果允许为核心池中的线程设置存活时间，那么核心池中的线程空闲时间超过keepAliveTime，线程也会被终止。
>
>###  **addWorker**
>
>源码如下
>
>```java
>private boolean addWorker(Runnable firstTask, boolean core) {
>   retry:
>   // 更新"线程池状态和计数"标记，即更新ctl。
>   for (;;) {
>      // 更新"线程池状态和计数"标记，即更新ctl。
>       int c = ctl.get();
>        // 获取线程池状态。
>       int rs = runStateOf(c);
>
>       // Check if queue empty only if necessary.
>       // 有效性检查
>       if (rs >= SHUTDOWN &&
>           ! (rs == SHUTDOWN &&
>              firstTask == null &&
>              ! workQueue.isEmpty()))
>           return false;
>
>       for (;;) {
>          // 获取线程池中任务的数量。
>           int wc = workerCountOf(c);
>           // 如果"线程池中任务的数量"超过限制，则返回false。
>           if (wc >= CAPACITY ||
>               wc >= (core ? corePoolSize : maximumPoolSize))
>               return false;
>           // 通过CAS函数将c的值+1。操作失败的话，则退出循环。
>           if (compareAndIncrementWorkerCount(c))
>               break retry;
>           c = ctl.get();  // Re-read ctl
>           // 检查"线程池状态"，如果与之前的状态不同，则从retry重新开始。
>           if (runStateOf(c) != rs)
>               continue retry;
>           // else CAS failed due to workerCount change; retry inner loop
>       }
>   }
>
>boolean workerStarted = false;
>boolean workerAdded = false;
>Worker w = null;
>// 添加任务到线程池，并启动任务所在的线程。
>try {
>   final ReentrantLock mainLock = this.mainLock;
>   // 新建Worker，并且指定firstTask为Worker的第一个任务。
>   w = new Worker(firstTask);
>   // 获取Worker对应的线程。
>   final Thread t = w.thread;
>   if (t != null) {
>       // 获取锁
>       mainLock.lock();
>       try {
>           int c = ctl.get();
>           int rs = runStateOf(c);
>
>           // 再次确认"线程池状态"
>           if (rs < SHUTDOWN ||
>               (rs == SHUTDOWN && firstTask == null)) {
>               if (t.isAlive()) // precheck that t is startable
>                   throw new IllegalThreadStateException();
>               // 将Worker对象(w)添加到"线程池的Worker集合(workers)"中
>               workers.add(w);
>               // 更新largestPoolSize
>               int s = workers.size();
>               if (s > largestPoolSize)
>                   largestPoolSize = s;
>               workerAdded = true;
>           }
>       } finally {
>           // 释放锁
>           mainLock.unlock();
>       }
>       // 如果"成功将任务添加到线程池"中，则启动任务所在的线程。 
>       if (workerAdded) {
>           t.start();
>           workerStarted = true;
>       }
>   }
>} finally {
>   if (! workerStarted)
>       addWorkerFailed(w);
>}
>// 返回任务是否启动。
>return workerStarted;
>}
>
>```
>
>**说明**：
>
>1.  addWorker(Runnable firstTask, boolean core) 的作用是将任务(firstTask)添加到线程池中，并启动该任务。core为true的话，则以corePoolSize为界限，若"线程池中已有任务数量>=corePoolSize"，则返回false；core为false的话，则以maximumPoolSize为界限，若"线程池中已有任务数量>=maximumPoolSize"，则返回false。
>
>2. addWorker()会先通过for循环不断尝试更新ctl状态，ctl记录了"线程池中任务数量和线程池状态"。更新成功之后，再通过try模块来将任务添加到线程池中，并启动任务所在的线程。
>
>3.  从addWorker()中，我们能清晰的发现：线程池在添加任务时，会创建任务对应的Worker对象；而一个Workder对象包含一个Thread对象。
>
>(01) 通过将Worker对象添加到"线程的workers集合"中，从而实现将任务添加到线程池中。
>
>(02) 通过启动Worker对应的Thread线程，则执行该任务。
>
>### addWorkerFailed:
>
>如果Worker创建成功，但是没有启动，这时我们需要将从线程对象从works上移除，否则会影响线程池的性能，源码如下
>
>```java
>/**
>    * Rolls back the worker thread creation.
>    * - removes worker from workers, if present
>    * - decrements worker count
>    * - rechecks for termination, in case the existence of this
>    *   worker was holding up termination
>*/
>private void addWorkerFailed(Worker w) {
>   
>   final ReentrantLock mainLock = this.mainLock;
>   //获取锁
>   mainLock.lock();
>   try {
>       //从workers上移除线程
>       if (w != null)
>           workers.remove(w);
>       //减少线程的数量
>       decrementWorkerCount();
>       //由于线程数量的减少，可能会使得当前线程池上线程的数量变成0，这时有可能进入
>       //TIDYING状态，所以尝试结束线程池
>       tryTerminate();
>   } finally {
>       mainLock.unlock();
>   }
>}
>```
>
>这时你们会不会有个疑问，一般我们写程序时，如果想让线程一直运行，则会向下面这样写:
>
>```
>public void run(){
>while(true){
>   //doSomething
>}
>}
>```
>
>但是上面执行流程分析完了，但是没看到ThreadPoolExecutor怎么定义线程一直运行，这时我们就要去分析Worker这个内部类的源码，这里面有我们想要的结果：
>
>源码如下：
>
>```java
>private final class Worker
>   extends AbstractQueuedSynchronizer
>   implements Runnable {      
>   private static final long serialVersionUID = 6138294804551838833L;
>		//当前woker正在运行的线程
>   final Thread thread;
>   //初始化这个工作线程时的第一个任务，可能为null
>   Runnable firstTask;
>  	//每个线程完成任务的数量
>   volatile long completedTasks;
>   
>   Worker(Runnable firstTask) {
>       setState(-1); // inhibit interrupts until runWorker
>       this.firstTask = firstTask;       
>       //使用线程池提供的线程创建工厂来创建线程
>       this.thread = getThreadFactory().newThread(this);
>   }
>   //委派当前线程的run方法到外部类的runWorker上，
>   public void run() {
>       runWorker(this);
>   }
>   // Lock methods
>   //
>   // The value 0 represents the unlocked state.
>   // The value 1 represents the locked state.
>   protected boolean isHeldExclusively() {
>       return getState() != 0;
>   }
>
>   protected boolean tryAcquire(int unused) {
>       if (compareAndSetState(0, 1)) {
>           setExclusiveOwnerThread(Thread.currentThread());
>           return true;
>       }
>       return false;
>   }
>
>   protected boolean tryRelease(int unused) {
>       setExclusiveOwnerThread(null);
>       setState(0);
>       return true;
>   }
>
>   public void lock()        { acquire(1); }
>   public boolean tryLock()  { return tryAcquire(1); }
>   public void unlock()      { release(1); }
>   public boolean isLocked() { return isHeldExclusively(); }
>
>   void interruptIfStarted() {
>       Thread t;
>       if (getState() >= 0 && (t = thread) != null && !t.isInterrupted()) {
>           try {
>               t.interrupt();
>           } catch (SecurityException ignore) {
>           }
>       }
>   }
>}
>```
>
>分析：
>
>1. 从上面我们可以看出，Worker继承AQS，实现Runnable接口，继承AQS实现了一个简单的互斥锁，是不想在Worker运行的时候使用外部类的互斥锁，这样可以减少线程的等待。
>2. 线程创建时通过外部类的threadFactory来创建的，后面我会讲解这个类，其实很简单
>
>从上面可以看出Worker类的run方法实现实际上是外部类的runWorker方法实现的，源码如下：
>
>```java
>final void runWorker(Worker w) {
>		//获取当前cpu上运行的线程，其实也就是worker中的thread
>   Thread wt = Thread.currentThread();
>	//获取第一个运行任务，可以为null
>   Runnable task = w.firstTask;
>   w.firstTask = null;
>	//释放锁
>   w.unlock(); // allow interrupts
>	//判断当前线程是否是中断结束 true 不是
>   boolean completedAbruptly = true;
>   try {
>       //当任务不为空，一直运行
>       while (task != null || (task = getTask()) != null) {
>           w.lock();
>           // If pool is stopping, ensure thread is interrupted;
>           // if not, ensure thread is not interrupted.  This
>           // requires a recheck in second case to deal with
>           // shutdownNow race while clearing interrupt
>           if ((runStateAtLeast(ctl.get(), STOP) ||
>                (Thread.interrupted() &&
>                 runStateAtLeast(ctl.get(), STOP))) &&
>               !wt.isInterrupted())
>               wt.interrupt();
>           try {
>               //hook方法，我们可以通过集成ThreadPoolExecutor来实现这个方法，
>               //默认什么也不做
>               beforeExecute(wt, task);
>               Throwable thrown = null;
>               try {
>                   //执行任务
>                   task.run();
>               } catch (RuntimeException x) {
>                   thrown = x; throw x;
>               } catch (Error x) {
>                   thrown = x; throw x;
>               } catch (Throwable x) {
>                   thrown = x; throw new Error(x);
>               } finally {
>                    //hook方法，我们可以通过集成ThreadPoolExecutor来实现这个方法，
>                    //默认什么也不做
>                   afterExecute(task, thrown);
>               }
>           } finally {
>               task = null;
>               w.completedTasks++;
>               w.unlock();
>           }
>       }
>       completedAbruptly = false;
>   } finally {
>       //线程死亡，使用此方法执行后续清理工作，
>       processWorkerExit(w, completedAbruptly);
>   }
>}
>```
>
>从上面代码可以看到这边在循环获取任务，并执行，直到任务全部执行完毕。除了第一个任务，其他任务都是通过`getTask()`方法去取，这个方法是ThreadPoolExecutor中的一个方法。我们猜一下，整个类中只有任务缓存队列中保存了任务，应该就是去缓存队列中取了。
>
>```
>Runnable getTask() {
>for (;;) {
>   try {
>       int state = runState;
>       if (state > SHUTDOWN)
>           return null;
>       Runnable r;
>       if (state == SHUTDOWN)  // Help drain queue
>           r = workQueue.poll(); //取任务
>       else if (poolSize > corePoolSize || allowCoreThreadTimeOut) //如果线程数大于核心池大小或者允许为核心池线程设置空闲时间，
>           //则通过poll取任务，若等待一定的时间取不到任务，则返回null
>           r = workQueue.poll(keepAliveTime, TimeUnit.NANOSECONDS);
>       else
>           r = workQueue.take();
>       if (r != null)
>           return r;
>       if (workerCanExit()) {    //如果没取到任务，即r为null，则判断当前的worker是否可以退出
>           if (runState >= SHUTDOWN) // Wake up others
>               interruptIdleWorkers();   //中断处于空闲状态的worker
>           return null;
>       }
>       // Else retry
>   } catch (InterruptedException ie) {
>       // On interruption, re-check runState
>   }
>}
>}
>```
>
>这里有一个非常巧妙的设计方式，假如我们来设计线程池，可能会有一个任务分派线程，当发现有线程空闲时，就从任务缓存队列中取一个任务交给 空闲线程执行。但是在这里，并没有采用这样的方式，因为这样会要额外地对任务分派线程进行管理，无形地会增加难度和复杂度，这里直接让执行完任务的线程Worker去任务缓存队列里面取任务来执行，因为每一个Worker里面都包含了一个线程thread。
>
>还需要注意的是，当线程死亡如何处理：
>
>源码如下：
>
>```
>	//处理线程结束时的清理工作
>private void processWorkerExit(Worker w, boolean completedAbruptly) {
>   //如果是中断结束，则线程数量不做调整
>   if (completedAbruptly) 
>       decrementWorkerCount();
>
>   final ReentrantLock mainLock = this.mainLock;
>   //获取锁
>   mainLock.lock();
>   try {
>       //将当前worker线程上的完成任务数量记录下来
>       completedTaskCount += w.completedTasks;
>       //移除当前此worker
>       workers.remove(w);
>   } finally {
>       mainLock.unlock();
>   }
>   //尝试关闭线程池
>   tryTerminate();
>   int c = ctl.get();
>   //如果当前线程池状态不是stop，则添加woker线程
>   if (runStateLessThan(c, STOP)) {
>       //如果是异常导致线程的中断，则判断当前线程池中线程的
>       //数量是否大于min，min表示当前线程池最少应该有多少线程
>       //如果少于，则创建一个新的worker线程
>       if (!completedAbruptly) {
>           int min = allowCoreThreadTimeOut ? 0 : corePoolSize;
>           if (min == 0 && ! workQueue.isEmpty())
>               min = 1;
>           if (workerCountOf(c) >= min)
>               return; // replacement not needed
>       }
>       addWorker(null, false);
>   }
>}
>```
>
>
>
>### 关闭“线程池”
>
>shutdown()的源码如下：
>
>```java
>public void shutdown() {
>final ReentrantLock mainLock = this.mainLock;
>// 获取锁
>mainLock.lock();
>try {
>   // 检查终止线程池的“线程”是否有权限。
>   checkShutdownAccess();
>   // 设置线程池的状态为关闭状态。
>   advanceRunState(SHUTDOWN);
>   // 中断线程池中空闲的线程。
>   interruptIdleWorkers();
>   // 钩子函数，在ThreadPoolExecutor中没有任何动作。
>   onShutdown(); // hook for ScheduledThreadPoolExecutor
>} finally {
>   // 释放锁
>   mainLock.unlock();
>}
>// 尝试终止线程池
>tryTerminate();
>}
>```
>
>**说明**：shutdown()的作用是关闭线程池。
>
>shutdownNow()源码如下：
>
>```java
>public List<Runnable> shutdownNow() {
>   List<Runnable> tasks;
>   final ReentrantLock mainLock = this.mainLock;
>   //获取所
>   mainLock.lock();
>   try {
>   	
>       checkShutdownAccess();
>       //设置线程池状态为stop状态
>       advanceRunState(STOP);
>       //中断所有线程
>       interruptWorkers();
>       //取出队列上还未被执行的任务
>       tasks = drainQueue();
>   } finally {
>       mainLock.unlock();
>   }
>   tryTerminate();
>   //返回队列上的任务
>   return tasks;
>}
>```
>