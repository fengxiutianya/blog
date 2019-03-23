---
title: Java CompletableFuture 详解
tags:
  - JUC
  - Future
categories:
  - java
  - java8
author: zhangke
abbrlink: 931a340
date: 2019-01-04 16:49:00
---
### 概述
1. 前言
2. 准备工作
3. CompleteableFuture基本使用
4. CompletableFuture 类使用示例
### 前言
Java 5 并发库主要关注于异步任务的处理，它采用了这样一种模式，producer 线程创建任务并且利用阻塞队列将其传递给任务的 consumer。这种模型在 Java 7 和 8 中进一步发展，并且开始支持另外一种风格的任务执行，那就是将任务的数据集分解为子集，每个子集都可以由独立且同质的子任务来负责处理。

这种风格的基础库也就是 fork/join 框架，它允许程序员规定数据集该如何进行分割，并且支持将子任务提交到默认的标准线程池中，也就是通用的**ForkJoinPool**。Java 8 中，fork/join 并行功能借助并行流的机制变得更加具有可用性。但是，不是所有的问题都适合这种风格的并行处理：所处理的元素必须是独立的，数据集要足够大，并且在并行加速方面，每个元素的处理成本要足够高，这样才能补偿建立 fork/join 框架所消耗的成本。CompletableFuture 类则是 Java 8 在并行流方面的创新。
<!--  more -->

### 准备工作

这里主要介绍下面我们需要使用的一些知识点，主要是为了是读者可以更好的理解。

#### 异步计算

所谓异步调用其实就是实现一个可无需等待被调用函数的返回值而让操作继续运行的方法。在 Java 语言中，简单的讲就是另启一个线程来完成调用中的部分计算，使调用继续运行或返回，而不需要等待计算结果。但调用者仍需要取线程的计算结果。

#### 回调函数

回调函数比较通用的解释是，它是一个通过函数指针调用的函数。如果你把函数的指针（地址）作为参数传递给另一个函数，当这个指针被用为调用它所指向的函数时，我们就说这是回调函数。回调函数不是由该函数的实现方直接调用，而是在特定的事件或条件发生时由另外一方调用的，用于对该事件或条件进行响应。

回调函数的机制：

1. 定义一个回调函数；
2. 提供函数实现的一方在初始化时候，将回调函数的函数指针注册给调用者；
3. 当特定的事件或条件发生的时候，调用者使用函数指针调用回调函数对事件进行处理。

回调函数通常与原始调用者处于同一层次，如图 1 所示：

##### 图 1. 回调函数示例图

![]()

#### Future接口

JDK5 新增了 Future 接口，用于描述一个异步计算的结果。虽然 Future 以及相关使用方法提供了异步执行任务的能力，但是对于结果的获取却是很不方便，只能通过阻塞或者轮询的方式得到任务的结果。阻塞的方式显然和我们的异步编程的初衷相违背，轮询的方式又会耗费无谓的 CPU 资源，而且也不能及时地得到计算结果，为什么不能用观察者设计模式呢？即当计算结果完成及时通知监听者。

有一些开源框架实现了我们的设想，例如 Netty 的 ChannelFuture 类扩展了 Future 接口，通过提供 addListener 方法实现支持回调方式的异步编程。Netty 中所有的 I/O 操作都是异步的,这意味着任何的 I/O 调用都将立即返回，而不保证这些被请求的 I/O 操作在调用结束的时候已经完成。取而代之地，你会得到一个返回的 ChannelFuture 实例，这个实例将给你一些关于 I/O 操作结果或者状态的信息。当一个 I/O 操作开始的时候，一个新的 Future 对象就会被创建。在开始的时候，新的 Future 是未完成的状态－－它既非成功、失败，也非被取消，因为 I/O 操作还没有结束。如果 I/O 操作以成功、失败或者被取消中的任何一种状态结束了，那么这个 Future 将会被标记为已完成，并包含更多详细的信息（例如：失败的原因）。请注意，即使是失败和被取消的状态，也是属于已完成的状态。阻塞方式的示例代码如清单 1 所示。

##### 清单 1. 阻塞方式示例代码

```java
`// Start the connection attempt.``ChannelFuture Future = bootstrap.connect(new InetSocketAddress(host, port));``// Wait until the connection is closed or the connection attempt fails.``Future.getChannel().getCloseFuture().awaitUninterruptibly();``// Shut down thread pools to exit.``bootstrap.releaseExternalResources();`
```

上面代码使用的是 awaitUninterruptibly 方法，源代码如清单 2 所示。

##### 清单 2. awaitUninterruptibly 源代码

```java
publicChannelFutureawaitUninterruptibly() {
    boolean interrupted = false;
    synchronized (this) {
        //循环等待到完成
        while (!done) {
            checkDeadLock();
            waiters++;
            try {
                wait();
            } catch (InterruptedException e) {
                //不允许中断
                interrupted = true;
            } finally {
                waiters--;
            }
   		 }
	}
    if (interrupted) {
   		Thread.currentThread().interrupt();
	}
	return this;
}
```

##### 清单 3. 异步非阻塞方式示例代码

```java
// 尝试建立一个连接
ChannelFuture Future = bootstrap.connect(new InetSocketAddress(host, port));
// 注册连接完成监听器
Future.addListener(new ChannelFutureListener(){
    public void operationComplete(final ChannelFuture Future)
        throws Exception {    
        System.out.println("连接建立完成");
    }
});
 printTime("异步时间：");
// 连接关闭，释放资源
bootstrap.releaseExternalResources();
```

可以明显的看出，在异步模式下，上面这段代码没有阻塞，在执行 connect 操作后直接执行到** printTime("异步时间： ")**，随后 connect 完成，Future 的监听函数输出 connect 操作完成。

非阻塞则是添加监听类 ChannelFutureListener，通过覆盖 ChannelFutureListener 的 operationComplete 执行业务逻辑。

##### 清单 4. 异步非阻塞方式示例代码

```java
`public void addListener(final ChannelFutureListener listener) {``    ``if (listener == null) {``    ``throw new NullPointerException("listener");``}``    ``booleannotifyNow = false;``    ``synchronized (this) {``        ``if (done) {``        ``notifyNow = true;``    ``} else {``        ``if (firstListener == null) {``        ``//listener 链表头``        ``firstListener = listener;``    ``} else {``        ``if (otherListeners == null) {``        ``otherListeners = new ArrayList<``ChannelFutureListener``>(1);``        ``}``        ``//添加到 listener 链表中，以便操作完成后遍历操作``        ``otherListeners.add(listener);``    ``}``    ``......``    ``if (notifyNow) {``        ``//通知 listener 进行处理``        ``notifyListener(listener);``        ``}``}`
```

这部分代码的逻辑很简单，就是注册回调函数，当操作完成后自动调用回调函数，就达到了异步的效果。

### CompleteableFuture基本使用

在Java 8中, 新增加了一个包含50个方法左右的类: [CompletableFuture](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/CompletableFuture.html)，提供了非常强大的Future的扩展功能，可以帮助我们简化异步编程的复杂性，提供了函数式编程的能力，可以通过回调的方式处理计算结果，并且提供了转换和组合CompletableFuture的方法。

如果想使用以前阻塞或者轮询方式来使用，依然可以通过 CompletableFuture 类来实现，因为CompleteableFuture实现了 CompletionStage 和 Future 接口方，因此也支持这种方式。

CompletableFuture 类声明了 CompletionStage 接口，CompletionStage 接口实际上提供了同步或异步运行计算的舞台，所以我们可以通过实现多个 CompletionStage 命令，并且将这些命令串联在一起的方式实现多个命令之间的触发。

#### 同步方式完成计算

CompletableFuture类实现了[CompletionStage](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/CompletionStage.html)和[Future](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/Future.html)接口，所以你还是可以像以前一样通过阻塞或者轮询的方式获得结果，尽管这种方式不推荐使用。

```java
public T 	get()
public T 	get(long timeout, TimeUnit unit)
public T 	getNow(T valueIfAbsent)
public T 	join()
```

`getNow`有点特殊，如果结果已经计算完则返回结果或者抛出异常，否则返回给定的`valueIfAbsent`值。
`join`返回计算的结果或者抛出一个unchecked异常(CompletionException)，可以不进行捕捉，它和`get`对抛出的异常的处理有些细微的区别，你可以运行下面的代码进行比较：

```java
CompletableFuture<Integer> future = CompletableFuture.supplyAsync(() -> {
    int i = 1/0;
    return 100;
});
// join的使用方式
//future.join();

// get必须要捕捉异常，对异常进行处理
  try {
            future.get();
        } catch (InterruptedException e) {
            e.printStackTrace();
        } catch (ExecutionException e) {
            e.printStackTrace();
        }
```

尽管Future可以代表在另外的线程中执行的一段异步代码，但是你还是可以在本身线程中执行：

```java
public static CompletableFuture<Integer> compute() {
    final CompletableFuture<Integer> future = new CompletableFuture<>();

    return future;
}
```

上面的代码中`future`没有关联任何的`Callback`、线程池、异步任务等，如果客户端调用`future.get`就会一直傻等下去。你可以通过下面的代码完成一个计算，触发客户端的等待：

```
f.complete(100);
```

当然你也可以抛出一个异常，而不是一个成功的计算结果：

```
f.completeExceptionally(new Exception());
```

完整的代码如下：

```java
public class BasicMain {
    public static CompletableFuture<Integer> compute() {
        final CompletableFuture<Integer> future = new CompletableFuture<>();
        return future;
    }
    public static void main(String[] args) throws Exception {
        final CompletableFuture<Integer> f = compute();
        class Client extends Thread {
            CompletableFuture<Integer> f;
            Client(String threadName, CompletableFuture<Integer> f) {
                super(threadName);
                this.f = f;
            }
            @Override
            public void run() {
                try {
                    System.out.println(this.getName() + ": " + f.get());
                } catch (InterruptedException e) {
                    e.printStackTrace();
                } catch (ExecutionException e) {
                    e.printStackTrace();
                }
            }
        }
        new Client("Client1", f).start();
        new Client("Client2", f).start();
        System.out.println("waiting");
        f.complete(100);
        //f.completeExceptionally(new Exception());
        System.in.read();
    }
}
```

可以看到我们并没有把`f.complete(100);`放在另外的线程中去执行，但是在大部分情况下我们可能会用一个线程池去执行这些异步任务。`CompletableFuture.complete()`、`CompletableFuture.completeExceptionally`只能被调用一次。但是我们有两个后门方法可以重设这个值:`obtrudeValue`、`obtrudeException`，但是使用的时候要小心，因为`complete`已经触发了客户端，有可能导致客户端会得到不期望的结果。

#### 创建CompletableFuture对象

`CompletableFuture.completedFuture`是一个静态辅助方法，用来返回一个已经计算好的`CompletableFuture`。

```java
public static <U> CompletableFuture<U> completedFuture(U value)
```

而以下四个静态方法用来为一段异步执行的代码创建`CompletableFuture`对象：

```java
public static CompletableFuture<Void> 	runAsync(Runnable runnable)
public static CompletableFuture<Void> 	runAsync(Runnable runnable, Executor executor)
public static <U> CompletableFuture<U> 	supplyAsync(Supplier<U> supplier)
public static <U> CompletableFuture<U> 	supplyAsync(Supplier<U> supplier, Executor executor)
```

以`Async`结尾并且没有指定`Executor`的方法会使用`ForkJoinPool.commonPool()`作为它的线程池执行异步代码。

`runAsync`方法也好理解，它以`Runnable`函数式接口类型为参数，所以`CompletableFuture`的计算结果为空。

`supplyAsync`方法以`Supplier<U>`函数式接口类型为参数,`CompletableFuture`的计算结果类型为`U`。

因为方法的参数类型都是函数式接口，所以可以使用lambda表达式实现异步任务，比如：

```java
CompletableFuture<String> future = CompletableFuture.supplyAsync(() -> {
    //长时间的计算任务
    return "处理完成";
});
```

#### 计算结果完成时的处理

当`CompletableFuture`的计算结果完成，或者抛出异常的时候，我们可以执行特定的`Action`。主要是下面的方法：

```java
public CompletableFuture<T> 	whenComplete(BiConsumer<? super T,? super Throwable> action)
public CompletableFuture<T> 	whenCompleteAsync(BiConsumer<? super T,? super Throwable> action)
public CompletableFuture<T> 	whenCompleteAsync(BiConsumer<? super T,? super Throwable> action, Executor executor)
public CompletableFuture<T>     exceptionally(Function<Throwable,? extends T> fn)
```

可以看到`Action`的类型是`BiConsumer<? super T,? super Throwable>`，它可以处理正常的计算结果，或者异常情况。
方法不以`Async`结尾，意味着`Action`使用相同的线程执行，而`Async`可能会使用其它的线程去执行(如果使用相同的线程池，也可能会被同一个线程选中执行)。

注意这几个方法都会返回`CompletableFuture`，当`Action`执行完毕后它的结果返回原始的`CompletableFuture`的计算结果或者返回异常。

```java
public class Main {
    private static Random rand = new Random();
    private static long t = System.currentTimeMillis();
    static int getMoreData() {
        System.out.println("begin to start compute");
        try {
            Thread.sleep(10000);
        } catch (InterruptedException e) {
            throw new RuntimeException(e);
        }
        System.out.println("end to start compute. passed " + 
                           (System.currentTimeMillis() - t)/1000 + " seconds");
        return rand.nextInt(1000);
    }
    public static void main(String[] args) throws Exception {
        CompletableFuture<Integer> future = 
            CompletableFuture.supplyAsync(Main::getMoreData);
        Future<Integer> f = future.whenComplete((v, e) -> {
            System.out.println(v);
            System.out.println(e);
        });
        System.out.println(f.get());
        System.in.read();
    }
}
```

`exceptionally`方法返回一个新的CompletableFuture，当原始的CompletableFuture抛出异常的时候，就会触发这个CompletableFuture的计算，调用function计算值，否则如果原始的CompletableFuture正常计算完后，这个新的CompletableFuture也计算完成，它的值和原始的CompletableFuture的计算的值相同。也就是这个`exceptionally`方法用来处理异常的情况。

下面一组方法虽然也返回CompletableFuture对象，但是对象的值和原来的CompletableFuture计算的值不同。当原先的CompletableFuture的值计算完成或者抛出异常的时候，会触发这个CompletableFuture对象的计算，结果由`BiFunction`参数计算而得。因此这组方法兼有`whenComplete`和转换的两个功能。

```java
public <U> CompletableFuture<U> 	handle(BiFunction<? super T,Throwable,? extends U> fn)
public <U> CompletableFuture<U> 	handleAsync(BiFunction<? super T,Throwable,? extends U> fn)
public <U> CompletableFuture<U> 	handleAsync(BiFunction<? super T,Throwable,? extends U> fn, Executor executor)
```

同样，不以`Async`结尾的方法由原来的线程计算，以`Async`结尾的方法由默认的线程池`ForkJoinPool.commonPool()`或者指定的线程池`executor`运行。

#### 组合

`CompletableFuture`可以作为monad(单子)和functor。由于回调风格的实现，我们不必因为等待一个计算完成而阻塞着调用线程，而是告诉`CompletableFuture`当计算完成的时候请执行某个`function`。而且我们还可以将这些操作串联起来，或者将`CompletableFuture`组合起来。

```java
public <U> CompletableFuture<U> 	thenApply(Function<? super T,? extends U> fn)
public <U> CompletableFuture<U> 	thenApplyAsync(Function<? super T,? extends U> fn)
public <U> CompletableFuture<U> 	thenApplyAsync(Function<? super T,? extends U> fn, Executor executor)
```

这一组函数的功能是当原来的CompletableFuture计算完后，将结果传递给函数`fn`，将`fn`的结果作为新的`CompletableFuture`计算结果。因此它的功能相当于将`CompletableFuture<T>`转换成`CompletableFuture<U>`。

这三个函数的区别和上面介绍的一样，不以`Async`结尾的方法由原来的线程计算，以`Async`结尾的方法由默认的线程池`ForkJoinPool.commonPool()`或者指定的线程池`executor`运行。Java的CompletableFuture类总是遵循这样的原则，下面就不一一赘述了。

使用例子如下：

```java
CompletableFuture<Integer> future = CompletableFuture.supplyAsync(() -> {
    return 100;
});
CompletableFuture<String> f =  future
								.thenApplyAsync(i -> i * 10)
    							.thenApply(i -> i.toString());
System.out.println(f.get()); //"1000"
```

需要注意的是，这些转换并不是马上执行的，也不会阻塞，而是在前一个stage完成后继续执行。

**它们与`handle`方法的区别在于`handle`方法会处理正常计算值和异常，因此它可以屏蔽异常，避免异常继续抛出。而`thenApply`方法只是用来处理正常值，因此一旦有异常就会抛出。**

上面的前一个CompleteFuture执行完成执行后一个，下面的是同时执行或者其中一个执行完成就代表执行完成。

```java
public <U> CompletableFuture<U> 	thenCompose(Function<? super T,? extends 
                                                CompletionStage<U>> fn)
public <U> CompletableFuture<U> 	thenComposeAsync(Function<? super T,? extends 
                                                     CompletionStage<U>> fn)
public <U> CompletableFuture<U> 	thenComposeAsync(Function<? super T,? extends 
                                                     CompletionStage<U>> fn,
                                                     Executor executor)
```

这一组方法接受一个Function作为参数，这个Function的输入是当前的CompletableFuture的计算值，返回结果将是一个新的CompletableFuture，这个新的CompletableFuture会组合原来的CompletableFuture和函数返回的CompletableFuture。因此它的功能类似:

```
A +--> B +---> C
```

记住，`thenCompose`返回的对象并不一定是函数`fn`返回的对象，如果原来的`CompletableFuture`还没有计算出来，它就会生成一个新的组合后的CompletableFuture。

例子：

```java
CompletableFuture<Integer> future = CompletableFuture.supplyAsync(() -> {
    return 100;
});
CompletableFuture<String> f =  future.thenCompose( i -> {
    return CompletableFuture.supplyAsync(() -> {
        return (i * 10) + "";
    });
});
System.out.println(f.get()); //1000
```

而下面的一组方法`thenCombine`用来复合另外一个CompletionStage的结果。它的功能类似：

```
A +
  |
  +------> C
  +------>
B +
```

两个CompletionStage是并行执行的，它们之间并没有先后依赖顺序，other并不会等待先前的CompletableFuture执行完毕后再执行。

```java
public <U,V> CompletableFuture<V> 	thenCombine(CompletionStage<? extends U> other, 
                                        BiFunction<? super T,? super U,? extends V> fn)
public <U,V> CompletableFuture<V> 	thenCombineAsync(CompletionStage<? extends U> other, 
                                        BiFunction<? super T,? super U,? extends V> fn)
public <U,V> CompletableFuture<V> 	thenCombineAsync(CompletionStage<? extends U> other,
                    BiFunction<? super T,? super U,? extends V> fn, Executor executor)
```

其实从功能上来讲,它们的功能更类似`thenAcceptBoth`，只不过`thenAcceptBoth`是纯消费，它的函数参数没有返回值，而`thenCombine`的函数参数`fn`有返回值。

```java
CompletableFuture<Integer> future = CompletableFuture.supplyAsync(() -> {
    return 100;
});
CompletableFuture<String> future2 = CompletableFuture.supplyAsync(() -> {
    return "abc";
});
CompletableFuture<String> f =  future.thenCombine(future2, (x,y) -> y + "-" + x);
System.out.println(f.get()); //abc-100
```

#### 纯消费(执行Action)

上面的方法是当计算完成的时候，会生成新的计算结果(`thenApply`, `handle`)，或者返回同样的计算结果`whenComplete`，`CompletableFuture`还提供了一种处理结果的方法，只对结果执行`Action`,而不返回新的计算值，因此计算值为`Void`:

```java
public CompletableFuture<Void> 	thenAccept(Consumer<? super T> action)
public CompletableFuture<Void> 	thenAcceptAsync(Consumer<? super T> action)
public CompletableFuture<Void> 	thenAcceptAsync(Consumer<? super T> action, Executor executor)
```

看它的参数类型也就明白了，它们是函数式接口`Consumer`，这个接口只有输入，没有返回值。

```java
CompletableFuture<Integer> future = CompletableFuture.supplyAsync(() -> {
    return 100;
});
CompletableFuture<Void> f =  future.thenAccept(System.out::println);
System.out.println(f.get());
```

`thenAcceptBoth`以及相关方法提供了类似的功能，当两个CompletionStage都正常完成计算的时候，就会执行提供的`action`，它用来组合另外一个异步的结果。

`runAfterBoth`是当两个CompletionStage都正常完成计算的时候,执行一个Runnable，这个Runnable并不使用计算的结果。

```java
public <U> CompletableFuture<Void> 	thenAcceptBoth(CompletionStage<? extends U> other,
                                             BiConsumer<? super T,? super U> action)
public <U> CompletableFuture<Void> 	thenAcceptBothAsync(CompletionStage<? extends U> 
                                        other, BiConsumer<? super T,? super U> action)
public <U> CompletableFuture<Void> 	thenAcceptBothAsync(CompletionStage<? extends U> 
                     other, BiConsumer<? super T,? super U> action, Executor executor)
public     CompletableFuture<Void> 	runAfterBoth(CompletionStage<?> other, 
                                                 Runnable action)
```

例子如下：

```java
CompletableFuture<Integer> future = CompletableFuture.supplyAsync(() -> {
    return 100;
});
CompletableFuture<Void> f = future.thenAcceptBoth(CompletableFuture.completedFuture(10), 
                         			(x, y) -> System.out.println(x * y));
System.out.println(f.get());
```

更彻底地，下面一组方法当计算完成的时候会执行一个Runnable,与`thenAccept`不同，Runnable并不使用CompletableFuture计算的结果。

```java
public CompletableFuture<Void> 	thenRun(Runnable action)
public CompletableFuture<Void> 	thenRunAsync(Runnable action)
public CompletableFuture<Void> 	thenRunAsync(Runnable action, Executor executor)
```

因此先前的CompletableFuture计算的结果被忽略了,这个方法返回`CompletableFuture<Void>`类型的对象。

```java
CompletableFuture<Integer> future = CompletableFuture.supplyAsync(() -> {
    return 100;
});
CompletableFuture<Void> f =  future.thenRun(() -> System.out.println("finished"));
System.out.println(f.get());
```

> 因此，你可以根据方法的参数的类型来加速你的记忆。`Runnable`类型的参数会忽略计算的结果，`Consumer`是纯消费计算结果，`BiConsumer`会组合另外一个`CompletionStage`纯消费，`Function`会对计算结果做转换，`BiFunction`会组合另外一个`CompletionStage`的计算结果做转换。

####  Either

`thenAcceptBoth`和`runAfterBoth`是当两个CompletableFuture都计算完成，而我们下面要了解的方法是当任意一个CompletableFuture计算完成的时候就会执行。

```java
public CompletableFuture<Void> 	acceptEither(CompletionStage<? extends T> other, Consumer<? super T> action)
public CompletableFuture<Void> 	acceptEitherAsync(CompletionStage<? extends T> other, Consumer<? super T> action)
public CompletableFuture<Void> 	acceptEitherAsync(CompletionStage<? extends T> other, Consumer<? super T> action, Executor executor)

public <U> CompletableFuture<U> 	applyToEither(CompletionStage<? extends T> other, Function<? super T,U> fn)
public <U> CompletableFuture<U> 	applyToEitherAsync(CompletionStage<? extends T> other, Function<? super T,U> fn)
public <U> CompletableFuture<U> 	applyToEitherAsync(CompletionStage<? extends T> other, Function<? super T,U> fn, Executor executor)

```

**acceptEither`方法是当任意一个CompletionStage完成的时候，`action`这个消费者就会被执行。这个方法返回`CompletableFuture<Void>**

**applyToEither`方法是当任意一个CompletionStage完成的时候，`fn`会被执行，它的返回值会当作新的`CompletableFuture<U>的计算结果。**

下面这个例子有时会输出`100`,有时候会输出`200`,哪个Future先完成就会根据它的结果计算。

```java
Random rand = new Random();
CompletableFuture<Integer> future = CompletableFuture.supplyAsync(() -> {
    try {
        Thread.sleep(10000 + rand.nextInt(1000));
    } catch (InterruptedException e) {
        e.printStackTrace();
    }
    return 100;
});
CompletableFuture<Integer> future2 = CompletableFuture.supplyAsync(() -> {
    try {
        Thread.sleep(10000 + rand.nextInt(1000));
    } catch (InterruptedException e) {
        e.printStackTrace();
    }
    return 200;
});
CompletableFuture<String> f =  future.applyToEither(future2,i -> i.toString());
```

#### 辅助方法 `allOf` 和 `anyOf`

前面我们已经介绍了几个静态方法：`completedFuture`、`runAsync`、`supplyAsync`,下面介绍的这两个方法用来组合多个CompletableFuture。

```java
public static CompletableFuture<Void> 	    allOf(CompletableFuture<?>... cfs)
public static CompletableFuture<Object> 	anyOf(CompletableFuture<?>... cfs)
```

`allOf`方法是当所有的`CompletableFuture`都执行完后执行计算。

`anyOf`方法是当任意一个`CompletableFuture`执行完后就会执行计算，计算的结果相同。

下面的代码运行结果有时是100,有时是"abc"。但是`anyOf`和`applyToEither`不同。`anyOf`接受任意多的CompletableFuture但是`applyToEither`只是判断两个CompletableFuture,`anyOf`返回值的计算结果是参数中其中一个CompletableFuture的计算结果，`applyToEither`返回值的计算结果却是要经过`fn`处理的。当然还有静态方法的区别，线程池的选择等。

```java
Random rand = new Random();
CompletableFuture<Integer> future1 = CompletableFuture.supplyAsync(() -> {
    try {
        Thread.sleep(10000 + rand.nextInt(1000));
    } catch (InterruptedException e) {
        e.printStackTrace();
    }
    return 100;
});
CompletableFuture<String> future2 = CompletableFuture.supplyAsync(() -> {
    try {
        Thread.sleep(10000 + rand.nextInt(1000));
    } catch (InterruptedException e) {
        e.printStackTrace();
    }
    return "abc";
});
//CompletableFuture<Void> f =  CompletableFuture.allOf(future1,future2);
CompletableFuture<Object> f =  CompletableFuture.anyOf(future1,future2);
System.out.println(f.get());
```

我想通过上面的介绍，应该把CompletableFuture的方法和功能介绍完了(`cancel`、`isCompletedExceptionally()`、`isDone()`以及继承于Object的方法无需介绍了， `toCompletableFuture()`返回CompletableFuture本身)，希望你能全面了解CompletableFuture强大的功能，并将它应用到Java的异步编程中。如果你有使用它的开源项目，可以留言分享一下。



### 参考

1. [Java CompletableFuture 详解](https://colobu.com/2016/02/29/Java-CompletableFuture/)
2. [通过实例理解 JDK8 的 CompletableFuture](https://www.ibm.com/developerworks/cn/java/j-cf-of-jdk8/index.html)

