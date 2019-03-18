---
title: Java Reference详解
author: 枫秀天涯
tags:
  - java
categories:
  - java
  - 引用
abbrlink: 2e7bd07f
date: 2019-01-04 10:25:00
---
# Java Reference详解

### 概述

Java引用体系中我们最熟悉的就是强引用类型，如 A a= new A();这是我们经常说的强引用StrongReference，jvm gc时会检测对象是否存在强引用，如果存在由根对象对其有传递的强引用，则不会对其进行回收，即使内存不足抛出OutOfMemoryError。

除了强引用外，Java还引入了SoftReference，WeakReference，PhantomReference，FinalReference ，这些类放在java.lang.ref包下，类的继承体系如下图。Java额外引入这个四种类型引用主要目的是在jvm 在gc时，按照引用类型的不同，在回收时采用不同的逻辑。可以把这些引用看作是对对象的一层包裹，jvm根据外层不同的包裹，对其包裹的对象采用不同的回收策略，或特殊逻辑处理。 这几种类型的引用主要在jvm内存缓存、资源释放、对象可达性事件处理等场景会用到。

![输入图片说明](https://static.oschina.net/uploads/img/201701/21153037_ubGO.png)

本篇文章主要讲解前面三种SoftReference，WeakReference和PhantomReference的使用，以及ReferenceQueue的使用。至于FinalRefeence会在另一篇文章中讲解。
<!-- more -->
主要内容如下

1. 对象可达性判断
2. ReferenceQueue 简介
3. SoftReference简介及使用
4. WeakReference简介及使用
5. PhantomReference简介及使用
6. 总结

**本文名称使用说明**名称说明下：Reference指代引用对象本身，Referent指代被引用对象，下文介绍会以Reference，Referent形式出现。 

### 1. 对象可达性判断

jvm gc时，判断一个对象是否存在引用时，都是从根结合引用(Root Set of References)开始去标识,往往到达一个对象的引用路径会存在多条，如下图。 ![输入图片说明](https://static.oschina.net/uploads/img/201701/21165610_kkb9.png)

那么 垃圾回收时会依据两个原则来判断对象的可达性：

- 单一路径中，以最弱的引用为准
- 多路径中，以最强的引用为准

例如Obj4的引用，存在3个路径:1->6、2->5、3->4, 那么从根对象到Obj4最强的引用是2->5，因为它们都是强引用。如果仅仅存在一个路径对Obj4有引用时，比如现在只剩1->6,那么根对象到Obj4的引用就是以最弱的为准，就是SoftReference引用,Obj4就是softly-reachable对象。如果是WeakReference引用，就称作weakly-reachable对象。只要一个对象是强引用可达，那么这个对象就不会被gc，即使发生OOM也不会回收这个对象。

### 2. ReferenceQueue 简介

引用队列，在检测到适当的可到达性更改后，即Referent对象的可达性发生适当的改变时，垃圾回收器将已注册的引用对象reference添加到该队列中。

简单用下面代码来说明

```java
Object object = new Object();
ReferenceQueue  queue = new ReferenceQueue();
SoftReference<Objecct> soft = new SoftReference<>(object,queue);
object = null;
Systen.gc();
//休眠一会，等待gc完成
Thread.sleep(100);
System.out.println(queue.poll() == soft);
System.out.println(soft.get() == null)
```

输出结果：

```java
true
true
```

结果分析：

对应上面第一句话，就是说当soft引用对象包含的object对象被gc之后，其可达性就会发生改变，同时会将soft对象注册到queue这个引用队列中。可以使用poll()这个方法取出被所有可达性改变的引用对象。

ReferenceQueue实现了一个队列的入队(enqueue)和出队(poll,remove)操作，内部元素就是泛型的Reference，并且Queue的实现，是由Reference自身的链表结构( 单向循环链表 )所实现的。

ReferenceQueue名义上是一个队列，但实际内部并非有实际的存储结构，它的存储是依赖于内部节点之间的关系来表达。可以理解为queue是一个类似于链表的结构，这里的节点其实就是reference本身。可以理解为queue为一个链表的容器，其自己仅存储当前的head节点，而后面的节点由每个reference节点自己通过next来保持即可。

具体源码分析可以参考这个网站：[ReferenceQueue源码分析参考](http://www.importnew.com/26250.html)

因此可以看出，当reference与referenQueue联合使用的主要作用就是当reference指向的referent回收时，提供一种通知机制，通过queue取到这些reference，来做额外的处理工作。当然，如果我们不需要这种通知机制，在创建Reference对象时不传入queue对象即可。

### 3. SoftReference简介及使用

根据上面我们讲的对象可达性原理，我们把一个对象存在根对象对其有直接或间接的SoftReference，并没有其他强引用路径，我们把该对象成为softly-reachable对象。JVM保证在抛出OutOfMemoryError前会回收这些softly-reachable对象。JVM会根据当前内存的情况来决定是否回收softly-reachable对象，但只要referent有强引用存在，该referent就一定不会被清理，因此SoftReference适合用来实现memory-sensitive caches。

可见，SoftReference在一定程度上会影响JVM GC的，例如softly-reachable对应的referent多次垃圾回收仍然不满足释放条件，那么它会停留在heap old区，占据很大部分空间，在JVM没有抛出OutOfMemoryError前，它有可能会导致频繁的Full GC。

下面是我使用SoftReference做的一个简单的缓存图片的测试

```java
public class SoftReferenceImageTest {
    public static void main(String[] args) throws IOException {
        testImageLoad();
    }

    public static void testImageLoad() throws IOException {
        String s = "xmind.png";
        HashMap<String, SoftReference<byte[]>> map = new HashMap<>(100);
        for (int i = 0; i < 100; i++) {
            FileInputStream inputStream = new FileInputStream(s);
            byte[] bytes = new byte[(int) inputStream.getChannel().size()];
            while (inputStream.read(bytes) > 0) ;
            inputStream.close();
            map.put(s + i, new SoftReference<byte[]>(bytes));
        }
        for (int i = 0; i < map.size(); i++) {

            Optional.ofNullable(map.get(s + i))
                    .filter(softReference -> softReference.get() != null)
                    .ifPresent(softReference -> {
                        System.out.println("ok");
                    });
        }

    }
}
```

运行这段代码时，加上jvm参数(**-Xms10M -Xmx10M -Xmn5M -XX:+PrintGCDetails**)

运行结果为空，因为我加载的图片是5M，而分配给运行时的jvm是10M,所以每次加载完一张图片之后，在下一次加载就会清理这个SoftReference对象，因此最后得到的结果为空。

### 4. WeakReference简介及使用

当一个对象被WeakReference引用时，处于weakly-reachable状态时，只要发生GC时，就会被清除，同时会把WeakReference注册到引用队列中(如果存在的话)。 WeakReference不阻碍或影响它们对应的referent被终结(finalized)和回收(reclaimed)，因此，WeakReference经常被用作实现规范映射(canonicalizing mappings)。相比SoftReference来说，WeakReference对JVM GC几乎是没有影响的。

下面是一个简单的demo

```java
public class WeakReferenceTest {
    public static void main(String[] args) {
        weak();
    }

    public static void weak() {
        ReferenceQueue<Integer> referenceQueue = new ReferenceQueue<>();
        WeakReference<Integer> weak = new WeakReference<Integer>(new Integer(100), 
                                                                 referenceQueue);
        System.out.println("GC 前===>" + weak.get());
        System.gc();
        System.out.println("GC 后===>" + weak.get());
      
        try {
            Thread.sleep(100);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        System.out.println(referenceQueue.poll() == weak);
    }
}
```

运行结果

```java
GC 前===>100
GC 后===>null
true
```

结果分析：

从上面我么可以看到，WeakReference所对应的Referent对象被回收了，因此验证了只要发生gc，weakly-reachable对象就会被gc回收。

另外可以查看这篇文章，仔细说明jdk中WeakHashMap在Tomact中使用的场景[WeakHashMap使用场景](https://blog.csdn.net/kaka0509/article/details/73459419)

### 5. PhantomReference简介及使用

 PhantomReference 不同于WeakReference、SoftReference，它存在的意义不是为了获取referent,因为你也永远获取不到，因为它的get如下

```java
 public T get() {
        return null;
 }
```

PhantomReference主要作为其指向的referent被回收时的一种通知机制,它就是利用上文讲到的ReferenceQueue实现的。当referent被gc回收时，JVM自动把PhantomReference对象(reference)本身加入到ReferenceQueue中，像发出信号通知一样，表明该reference指向的referent被回收。然后可以通过去queue中取到reference，此时说明其指向的referent已经被回收，可以通过这个通知机制来做额外的清场工作。 因此有些情况可以用PhantomReference 代替finalize()，做资源释放更明智。

下面举个例子，用PhantomReference来自动关闭文件流。

```java
public class ResourcePhantomReference<T> extends PhantomReference<T> {

    private List<Closeable> closeables;

    public ResourcePhantomReference(T referent, ReferenceQueue<? super T> q, List<Closeable> resource) {
        super(referent, q);
        closeables = resource;
    }

    public void cleanUp() {
        if (closeables == null || closeables.size() == 0)
            return;
        for (Closeable closeable : closeables) {
            try {
                closeable.close();
                System.out.println("clean up:"+closeable);
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }
}
```

```java
public class ResourceCloseDeamon extends Thread {

    private static ReferenceQueue QUEUE = new ReferenceQueue();

    //保持对reference的引用,防止reference本身被回收
    private static List<Reference> references=new ArrayList<>();
    @Override
    public void run() {
        this.setName("ResourceCloseDeamon");
        while (true) {
            try {
                ResourcePhantomReference reference = (ResourcePhantomReference) QUEUE.remove();
                reference.cleanUp();
                references.remove(reference);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
    }

    public static void register(Object referent, List<Closeable> closeables) {
        references.add(new ResourcePhantomReference(referent,QUEUE,closeables));
    }


}
```

```java
public class FileOperation {

    private FileOutputStream outputStream;

    private FileInputStream inputStream;

    public FileOperation(FileInputStream inputStream, FileOutputStream outputStream) {
        this.outputStream = outputStream;
        this.inputStream = inputStream;
    }

    public void operate() {
        try {
            inputStream.getChannel().transferTo(0, inputStream.getChannel().size(), outputStream.getChannel());
        } catch (IOException e) {
            e.printStackTrace();
        }
    }


}
```

测试代码：

```java
public class PhantomTest {

    public static void main(String[] args) throws Exception {
        //打开回收
        ResourceCloseDeamon deamon = new ResourceCloseDeamon();
        deamon.setDaemon(true);
        deamon.start();

        // touch a.txt b.txt
        // echo "hello" > a.txt

        //保留对象,防止gc把stream回收掉,其不到演示效果
        List<Closeable> all=new ArrayList<>();
        FileInputStream inputStream;
        FileOutputStream outputStream;

        for (int i = 0; i < 100000; i++) {
            inputStream = new FileInputStream("/Users/robin/a.txt");
            outputStream = new FileOutputStream("/Users/robin/b.txt");
            FileOperation operation = new FileOperation(inputStream, outputStream);
            operation.operate();
            TimeUnit.MILLISECONDS.sleep(100);

            List<Closeable>closeables=new ArrayList<>();
            closeables.add(inputStream);
            closeables.add(outputStream);
            all.addAll(closeables);
            ResourceCloseDeamon.register(operation,closeables);
            //用下面命令查看文件句柄,如果把上面register注释掉,就会发现句柄数量不断上升
            //jps | grep PhantomTest | awk '{print $1}' |head -1 | xargs  lsof -p  | grep /User/robin
            System.gc();

        }


    }
}
```

运行上面的代码，通过jps | grep PhantomTest | awk '{print $1}' |head -1 | xargs lsof -p | grep /User/robin ｜ wc -l 可以看到句柄没有上升，而去掉ResourceCloseDeamon.register(operation,closeables);时，句柄就不会被释放。

PhantomReference使用时一定要传一个referenceQueue,当然也可以传null,但是这样就毫无意义了。因为PhantomReference的get结果为null,如果在把queue设为null,那么在其指向的referent被回收时，reference本身将永远不会可能被加入队列中，这里我们可以看ReferenceQueue的源码。

### 6. 总结

#### 引用类型对比

| 序号  | 引用类型 | 取得目标对象方式   | 垃圾回收条件  | 是否可能内存泄漏 |
|-----|------|------------|---------|----------|
| 1   | 强引用  | 直接调用       | 不回收     | 可能       |
| 2   | 软引用  | 通过 get()方法 | 视内存情况回收 | 不可能      |
| 3   | 弱引用  | 通过 get()方法 | 永远回收    | 不可能      |
| 4   | 虚引用  | 无法取得       | 不回收     | 可能       |

通过对SoftReference，WeakReference，PhantomReference 的介绍，可以看出JDK提供这些类型的reference 主要是用来和GC交互的，根据reference的不同，让JVM采用不同策略来进行对对象的回收(reclaim)。softly-reachable的referent在保证在OutOfMemoryError之前回收对象，weakly-reachable的referent在发生GC时就会被回收,同时这些reference和referenceQueue在一起提供通知机制，PhantomReference的作用就是仅仅就是提供对象回收通知机制，Finalizer借助这种机制实现referent的finalize执行，SoftReference、WeakReference也可以配合referenceQueue使用，实现对象回收通知机制。

### 参考

[Java中的四种引用类型](https://www.jianshu.com/p/147793693edc)

[Java Reference详解](https://my.oschina.net/robinyao/blog/829983)

[Reference、ReferenceQueue 详解](http://www.importnew.com/26250.html)

[用弱引用堵住内存泄漏](https://www.ibm.com/developerworks/cn/java/j-jtp11225/)