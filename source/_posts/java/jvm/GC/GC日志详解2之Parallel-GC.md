---
title: GC日志详解2之Parallel GC
tags:
  - GC日志
  - Parallel Scavenge
  - Parallel Old
abbrlink: 5319940a
categories:
  - java
  - jvm
  - GC
date: 2019-04-18 11:45:15
---
前面写了一篇文章[GC日志详解1之serial](/posts/f857a2aa/)已经详细介绍了Serial和Serial Old搭配使用时输出日志的解析。这篇文章将详细介绍Parallel Scavenge 和 Parallel Old搭配使用时输出日志的解析。

Parallel Scavenge在年轻代使用，采用**标记-复制**的方法来进行垃圾回收，而Paralle Old是在老年代进行回收，采用的是**标记-整理**的方法来进行垃圾回收。俩个垃圾回收器都会暂停所用应用程序的线程，也就是STW现象。叫做Parallel是因为，这俩个垃圾回收器都会使用多线程来进行垃圾的回收，通过这种方式，GC执行的时间也因此减少。

GC在执行的时候，线程的数量是可以配置的。通过参数`XX:ParallelGCThreads=NNN`来进行配置，如果没有配置，默认的收集线程数等于机器的核心数。

如果你的目标是提高系统的吞吐量，并且运行应用的机器是多核机器，特别适用于这种搭配。能够提高吞吐量的原因是这种搭配能够更高效的使用系统资源：
 * 在GC执行的过程中，所有核心都在并行清理垃圾，从而缩短暂停时间
 * 在GC回收周期之间，也就是在应用执行的过程中，收集者都没有消耗任何资源。（这点我还没搞懂）

另一方面，由于GC收集器的所有阶段都必须在没有任何中断的情况下发生，因此这组收集器仍然容易受到长时间暂停的影响，在此期间应用程序线程将被停止。因此，如果延迟是您的主要目标，您可以选择我在上一篇文章里面提到的后俩种搭配。
<!-- more -->
下面我们一起来看看，这种搭配方式输出的日志信息。测试代码如下
``` java

/**************************************
 *      Author : zhangke
 *      Date   : 2019-02-20 11:34
 *      email  : 398757724@qq.com
 *      Desc   : 年轻代使用 Parallec Scanvenge老年代使用Parallel Old
 *
 *      -verbose:gc -Xms20M -Xmx20M -Xmn10M
 *      -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCTimeStamps
 *      -XX:MaxTenuringThreshold=1
 *      -XX:+UseParallelGC -XX:+UseParallelOldGC
 *
 ***************************************/
public class Parallel {
    private static final int _1MB = 1024 * 1024;


    public static void main(String[] args) throws InterruptedException {
        byte[] allocation1, allocation2, allocation3, allocation4;
        allocation1 = new byte[4 * _1MB];
        allocation2 = new byte[3 * _1MB];
        allocation3 = new byte[4 * _1MB];
        allocation4 = new byte[2 * _1MB];
        allocation1[0] = 'd';
        allocation2[1] = 'd';

    }
}
```
在运行代码的时候，加上` -XX:+UseParallelGC `参数，可以在年轻代使用Parallel Scavenge收集器，加上`-XX:+UseParallelOldGC`参数，可以在老年代使用Parallel Old收集器。
运行上面代码，输出的日志如下：
```
2019-04-18T13:52:42.068+0800: 0.110: [GC (Allocation Failure) [PSYoungGen: 5643K->432K(9216K)] 5643K->4528K(19456K), 0.0046494 secs] [Times: user=0.01 sys=0.00, real=0.00 secs] 
2019-04-18T13:52:42.078+0800: 0.120: [GC (Allocation Failure) --[PSYoungGen: 7838K->7838K(9216K)] 11934K->15342K(19456K), 0.0052090 secs] [Times: user=0.00 sys=0.00, real=0.01 secs] 
2019-04-18T13:52:42.083+0800: 0.125: [Full GC (Ergonomics) [PSYoungGen: 7838K->4096K(9216K)] [ParOldGen: 7504K->7496K(10240K)] 15342K->11593K(19456K), [Metaspace: 2995K->2995K(1056768K)], 0.0074408 secs] [Times: user=0.02 sys=0.00, real=0.01 secs] 
```
### 年轻代（Minor GC）
上面头俩行日志输出的是年轻代日志回收信息，这里拿第一行来举例说明
```
2019-04-18T13:52:42.068+0800: 0.110: [GC (Allocation Failure) [PSYoungGen: 5643K->432K(9216K)] 5643K->4528K(19456K), 0.0046494 secs] [Times: user=0.01 sys=0.00, real=0.00 secs] 
```
1. `2019-04-18T13:52:42.068+0800:`GC开始的时间
2.  `0.110`：GC开始相对于JVM启动开始的时间，单位秒
3.   `GC` ：标记用于辨别是Full GC还是Minor GC，这里是Minor GC
4.   `(Allocation Failure)`：造成这次GC的原因，这里是因为年轻代没有足够的空间来满足对象的分配。
5.    `PSYoungGen`：垃圾回收器的名称，这里表示使用的是Parallel Scavenge
6.    `5643K->432K(9216K)`：年轻代回收前和回收后已被使用的内存大小，后面是年轻代可被使用内存的总的空间大小
7.    `5643K->4528K(19456K)`：堆区可以在垃圾回收前和回收后已使用的空间大小，和整个堆区可被使用的空间大小。
8.    `0.0046494 secs`：GC回收器执行的时间 
9.   ` [Times: user=0.01 sys=0.00, real=0.00 secs]`：GC持续的时间，从不同的角度来测量：
    1. **user：**GC垃圾回收器在用户态花费的时间
    2.  **sys：**GC垃圾回收器在核心太花费的时间
    3.  **real：**GC垃圾回收器执行的时间。这里因为是多线程执行，因此这个值理论上应该是`(user + sys) /core numbers`的值接近。此外由于一些任务是不能并行，所以这个值一直超过前面计算出来的值。

从这些信息可以看出，经过在年轻代执行垃圾回收，年轻代可被使用的空间增加了`5211K`，但是整个堆区可被使用的空间只增加了`1115K`，所以可以得到，有`5211k - 1115k=4096K`内存从年轻代移动到老年代。，如下图所示
![ParallelGC-in-Young-Generation-Java](/source/images/ParallelGC-in-Young-Generation-Java.png)

### Full GC
日志信息如下：
```
2019-04-18T13:52:42.083+0800: 0.125: [Full GC (Ergonomics) [PSYoungGen: 7838K->4096K(9216K)] [ParOldGen: 7504K->7496K(10240K)] 15342K->11593K(19456K), [Metaspace: 2995K->2995K(1056768K)], 0.0074408 secs] [Times: user=0.02 sys=0.00, real=0.01 secs] 
```
1. `2019-04-18T13:52:42.083+0800:`GC开始的时间
2. `0.125:`GC开始相对于JVM启动的时间，单位秒
3. `Full GC`:表明这次GC是会同时执行年轻代和老年代的垃圾回收器
4. `Ergonomics`：表明产生这次GC的原因。这表明这次回收是一个恰当的时间。（后面在补充）
5. `[PSYoungGen: 7838K->4096K(9216K)`：和上面一样，表明年轻代使用Parallel Scavenge垃圾回收器进行回收，回收前年轻代内存已经被使用7838K，回收后年轻代已经使用了4096k大小的内存，年轻代总的内存大小9216K。
6. `[ParOldGen: 7504K->7496K(10240K)]`老年代采用Parallel Old垃圾回收器来进行回收，回收前，老年代已经被使用了7504K大小的内存空间，回收后，已经被使用的内存大小是7496K大小的内存，老年代总的内存大小是10240K。 
7. `15342K->11593K(19456K)`：堆区可以在垃圾回收前和回收后已使用的空间大小，和整个堆区可被使用的空间大小。
8. `[Metaspace: 2995K->2995K(1056768K)], 0.0074408 secs] `元空间在GC执行前和执行后内存的使用情况，1056768K表示元空间可以使用的内存大小，`0.0074408 secs`,表示GC在这一部分执行花费的时间
9. `[Times: user=0.02 sys=0.00, real=0.01 secs]`：和上面一样，这里就不解释了。

再次，与Minor GC的区别很明显 - 除了年轻代被回收之外，在此GC执行期间，老年代和Metaspace也被清理干净。GC之前和之后的内存布局看起来如下：
![Java-ParallelGC-in-Old-Generation](/source/images/Java-ParallelGC-in-Old-Generation.png)
## 参考
1. [GC Algorithms Implementations](https://plumbr.io/handbook/garbage-collection-algorithms-implementations)
2. 