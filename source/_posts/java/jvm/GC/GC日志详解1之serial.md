title: GC日志详解1之serial
abbrlink: f857a2aa
categories:
  - java
  - jvm
  - GC
tags:
  - JVM
  - GC
  - GC日志
  - serial
date: 2019-04-17 11:03:00
---
前面我有写过一篇文章来详细介绍JVM中的各种GC,如果你还不了解，可以看这篇文章[JVM 垃圾回收器](/posts/1d97a19/)。本篇文章以及后面几篇文章，将对每种GC产生的日志进行详细的解析，主要是由于写成一篇文章的话，篇幅太长，所以分成几篇文章来写。这篇文章主要介绍Serial垃圾回收器的日志解析。
<!-- more -->

在详细介绍Serial 垃圾回收器的日志之前，我们先来看看JVM中几种比较常见的GC垃圾回收器的搭配。知道垃圾回收器的人应该都明白，在java8之前，每种垃圾回收器要么在年轻代使用，要么在老年代使用。所以在使用的时候，需要对年轻代和老年代的垃圾回收器进行搭配。不过G1垃圾回收器比较特殊，可以在老年代和年轻代同时运行。下面我们在生产场景下经常会用到的垃圾回收器的搭配，也是这几篇文章会详细介绍的垃圾回收器的日志解析：
1. Serial 和Serial old
2. Parallel  Scavenge 和 Parallel Old
3. Parallel New(ParNew) 和  Concurrent Mark and Sweep (CMS) 
4. G1

下面我们开始详细分析Serial 和Serial Old的日志。

使用Serial 和Serial Old这种垃圾回收器的搭配方式，在年轻代使用的是**标记-拷贝**算法，在老年代使用的**标记-整理**算法。就像他们俩的名字一样，这俩个垃圾回收器都是使用的单线程的来进行回收。俩个回收器在回收的时候都会暂停当前运行的所有下次你哼，产生STW（Stop-The-World）这种现象。另外他们都不能利用计算机多核带来的好处。
如果想在年轻代和老年代启动Serial垃圾回收器，在运行程序的时候，加上下面的参数就可以使用：
```
-XX:+UseSerialGC
```
此选项有意义，建议仅用于具有几百兆字节堆大小的JVM，在具有单个CPU的环境中运行。对于大多数服务器端部署，这是一种罕见的组合。大多数服务器端部署都是在具有多个内核的平台上完成的，这实际上意味着如果你选择Serial GC这种组合，就是在JVM使用的系统资源进行人为的限制。这会导致空闲资源增加，不过也可以用于减少延迟或增加吞吐量。

下面是我使用的一段代码，来打印Serial 和Serial old的日志信息
``` java
/**************************************
 *      Author : zhangke
 *      Date   : 2019-02-20 11:34
 *      email  : 398757724@qq.com
 *      Desc   : 年轻代使用 serial 老年代使用 serial old
 *
        运行时需要添加的参数
 *      -verbose:gc -Xms20M -Xmx20M -Xmn10M
 *      -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCTimeStamps
 *      -XX:+UseSerialGC
 *      -XX:MaxTenuringThreshold=1
 ***************************************/
public class SerialGC {
    private static final int _1MB = 1024 * 1024;


    public static void main(String[] args) throws InterruptedException {
        byte[] allocation1, allocation2, allocation3, allocation4;
        allocation1 = new byte[4 * _1MB];
        allocation2 = new byte[4 * _1MB];
        allocation3 = new byte[2 * _1MB];
        allocation4 = new byte[3 * _1MB];
        allocation1[0] = 'd';
        allocation2[1] = 'd';
    }
}
```
输出的日志信息如下：
``` log
2019-04-17T20:02:57.654+0800: 0.078: [GC (Allocation Failure) 2019-04-17T20:02:57.654+0800: 0.078: [DefNew: 5643K->360K(9216K), 0.0028108 secs] 5643K->4456K(19456K), 0.0028533 secs] [Times: user=0.00 sys=0.00, real=0.00 secs] 

2019-04-17T20:02:57.658+0800: 0.082: [GC (Allocation Failure) 2019-04-17T20:02:57.658+0800: 0.082: [DefNew (promotion failed) : 7682K->7322K(9216K), 0.0022621 secs]2019-04-17T20:02:57.661+0800: 0.084: [Tenured: 7522K->7522K(10240K), 0.0024226 secs] 11778K->11618K(19456K), [Metaspace: 3006K->3006K(1056768K)], 0.0047392 secs] [Times: user=0.01 sys=0.00, real=0.01 secs] 

```
上面的日志信息会显示很多的信息，下面依次来介绍上面的俩条日志，第一条发生在年轻代，第二条发生在老年代。
### 年轻代
```
2019-04-17T20:02:57.654+0800: 0.078: [GC (Allocation Failure) 2019-04-17T20:02:57.654+0800: 0.078: [DefNew: 5643K->360K(9216K), 0.0028108 secs] 5643K->4456K(19456K), 0.0028533 secs] [Times: user=0.00 sys=0.00, real=0.00 secs] 
```
按照显示的顺序来进行介绍：
1. `2019-04-17T20:02:57.654+0800`：GC开始的时间
2. `0.078`：GC开始相对于JVM启动的开始时间，单位是秒
3. `GC`:标记用于辨别是年轻代GC还是Full GC(回收年轻代和老年代)
4. `Allocation Failure`：造成GC的原因。在这个案例里，GC被启动的原因是年轻代所剩的空间不能满足对象的分配。
5. `DefNew`:GC回收器使用的名称。这里代表Serial垃圾回收器。
6. `5643K->360K(9216K)`: GC回收前年轻代使用的空间大小->GC回收后年轻代使用的空间大小（年轻代总空间大小）
7. ` 0.0028108 secs`：收集持续的时间，还没有最终的清理
8. ` 5643K->4456K(19456K)`:GC前堆已被使用的空间大小->GC后堆中已被使用的空间大小（堆可被使用的总大小）
9. `0.0028533 secs`:整个GC持续的时间，标记和复制年轻代活着的对象所花费的时间（包括和老年代通信的开销、对象晋升到老年代开销、垃圾收集周期结束一些最后的清理对象等的花销）
10. `[Times: user=0.00 sys=0.00, real=0.00 secs] `：描述GC回收器整个操作过程中花费的时间，其实和inux中time命令输出的信息是一样的。如果你不懂这个命令可以看这篇文章[linux命令之time](/posts/3374b24f/)
    1.  user:GC垃圾回收器在用户态花费的时间
    2.  sys：GC垃圾回收器在核心太花费的时间
    3.  real：GC垃圾回收器真正在CPU上执行的时间。因为Serial是单线程应用，因此这里real=user+sys。并且这个时间也可以代表你的应用被暂停的时间。


从上面的分析，我们知道在整个GC执行的过程中，伴随着内存的回收。不过有一点需要注意的是，年轻代减少的内存是`5643K  -  360K=5283k`，但是从后面的整个堆区已被使用的空间仅减少了` 5643K - 4456K=1187k`。从这可以看出，应该有4096的对象被移动到堆区。也就是下面这幅图所描述的：
![serial-gc-in-young-generation ](/images/serial-gc-in-young-generation.png)
### Full GC
如果你看懂了上面的解释，在看第二条日志信息应该hi轻松点。
```
2019-04-17T20:02:57.658+0800: 0.082: [GC (Allocation Failure) 2019-04-17T20:02:57.658+0800: 0.082: [DefNew (promotion failed) : 7682K->7322K(9216K), 0.0022621 secs]2019-04-17T20:02:57.661+0800: 0.084: [Tenured: 7522K->7522K(10240K), 0.0024226 secs] 11778K->11618K(19456K), [Metaspace: 3006K->3006K(1056768K)], 0.0047392 secs] [Times: user=0.01 sys=0.00, real=0.01 secs] 
```
1. `2019-04-17T20:02:57.658+0800`：GC开始的时间
2. `0.082`:GC相对去JVM启动的开始时间，单位是秒
3. ` [DefNew (promotion failed) : 7682K->7322K(9216K), 0.0022621 secs]`：这个和前面是一致的，显示了GC回收前年轻代内存使用的的情况和回收后年轻代内存的使用情况。从上面可以看出，回收了`7682K - 7322K = 360k`。不过有一点需要注意的是，如果这条信息显示年轻代内存已经被使用完，可能不是真的使用完，可能是由于JVM比较繁忙，所以报告了一个错误信息。最后时间表示，整个回收花费了多长时间。
4. `Tenured`:表示用于老年代垃圾回收器的名称。这里显示的是使用Serial Old这个垃圾回收器用于老年代。
5. `7522K->7522K(10240K)，.0024226 secs`：老年代在GC执行前和执行后内存的使用情况。这个例子显示没有内存被回收，已被使用的内存是7522K，后面的`.0024226 secs`表示GC执行的时间。
6. `11778K->11618K(19456K)`：表示年轻代和老年代GC执行前和执行后堆中内存使用的情况。`19456K`表示堆可被使用的内存大小。
7. `[Metaspace: 3006K->3006K(1056768K)], 0.0047392 secs`：元空间在GC执行前和执行后内存的使用情况，1056768K表示元空间可以使用的内存大小，`0.0047392 secs`,表示GC在这一部分执行花费的时间
8. `[Times: user=0.01 sys=0.00, real=0.01 secs]`：GC持续的时间，从不同的角度来测量：
    1. user:GC垃圾回收器在用户态花费的时间
    2.  sys：GC垃圾回收器在核心太花费的时间
    3.  real：GC垃圾回收器真正在CPU上执行的时间。因为Serial是单线程应用，因此这里real=user+sys。并且这个时间也可以代表你的应用被暂停的时间。

与年轻代垃圾回收的区别很明显 - 除了Young Generation之外，在此GC执行期间，Old Generation和Metaspace也被清理干净。GC执行之前和之后的内存布局看起来如下图所示：

![serial-gc-in-old-gen-java](/images/serial-gc-in-old-gen-java.png)



## 参考
1. [GC Algorithms Implentations](https://plumbr.io/handbook/garbage-collection-algorithms-implementations)