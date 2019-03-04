title: Random 与 ThreadLocalRandom 对比
tags:
  - JUC
categories:
  - java
author: zhangke
abbrlink: 26181
date: 2018-12-12 15:42:00
---
---
# Random 与 ThreadLocalRandom 对比

1. 简介
2. 测试结果与分析
3. 补充

### 1. 简介

首先，如果你看到这篇文章相信对这俩个类有一定的了解，所以我就不再这里介绍具体的用法。简单的介绍一下这个类，Random，ThreadLocalRandom是Java中的随机数生成器，Random是我们比较常用的随机数生成器，他是线程安全的。ThreadLocalRandom是jdk7才出现的，是Random的增强版。在并发访问的环境下，使用ThreadLocalRandom来代替Random可以减少多线程竞争，同时也能保证线程安全和提高性能。

由于本人能力有限，如果你的英文比较好，可以看看StackOverFlow上的这个讨论[https://stackoverflow.com/questions/23396033/random-over-threadlocalrandom](https://stackoverflow.com/questions/23396033/random-over-threadlocalrandom)
<!--  more -->

### 2. 测试结果与分析

我使用的JMH来进行的压测，这篇文章可以帮助你[入门 JMH](https://www.cnkirito.moe/java-jmh/)。具体代码如下

```java
/**************************************
 *      Author : zhangke
 *      Date   : 2018-12-12 11:44
 *      email  : 398757724@qq.com
 *      Desc   : ThreadRandom 和 Random性能对比
 ***************************************/
@BenchmarkMode({Mode.AverageTime})
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@Warmup(iterations = 3, time = 5)
@Measurement(iterations = 3, time = 5)
@Threads(10)
@Fork(1)
@State(Scope.Benchmark)
public class Randombenchmark {
    Random random = new Random();

    ThreadLocalRandom threadLocalRandom = ThreadLocalRandom.current();


    @Benchmark
    public int random() {
        return random.nextInt();
    }


    @Benchmark
    public int threadLocalRandom() {
        return threadLocalRandom.nextInt();
    }


    public static void main(String[] args) throws RunnerException {
        Options opt = new OptionsBuilder()
                .include(Randombenchmark.class.getSimpleName())
                .build();

        new Runner(opt).run();
    }
}

```

测试结果

```
··· 前面一部分省略，主要内容如下
Benchmark                          Mode  Cnt    Score     Error  Units
Randombenchmark.random             avgt    3  349.952 ± 115.007  ns/op
Randombenchmark.threadLocalRandom  avgt    3   26.393 ±  11.538  ns/op
```

从上面结果可以看出，结果验证确实ThreadLocalRandom在多线程环境情况下更快，ThreadLocalRandom比Random快了将近13倍之多。

至于为什么ThreadLocalRandom更快呢，这个要从源码来分析。

Random的实现也比较简单，初始化的时候用当前的事件来初始化一个随机数种子，然后每次取值的时候用这个种子与有些MagicNumber运算，并更新种子。最核心的就是这个next的函数，不管你是调用了nextDouble还是nextInt还是nextBoolean，Random底层都是调这个next(int bits)。

```java
    protected int next(int bits) {
        long oldseed, nextseed;
        AtomicLong seed = this.seed;
        do {
            oldseed = seed.get();
            nextseed = (oldseed * multiplier + addend) & mask;
        } while (!seed.compareAndSet(oldseed, nextseed));
        return (int)(nextseed >>> (48 - bits));
    }
```

　　为了保证多线程下每次生成随机数都是用的不同，next()得保证seed的更新是原子操作，所以用了AtomicLong的compareAndSet()，该方法底层调用了sum.misc.Unsafe的compareAndSwapLong()，也就是大家常听到的CAS， 这是一个native方法，它能保证原子更新一个数。

既然Random是线程安全的，又能满足我们大多说的要求，为什么concurrent包里还要实现一个ThreadLocalRandom。在oracle的jdk文档里发现这样一句话

> use of ThreadLocalRandom rather than shared Random objects in concurrent programs will typically encounter much less overhead and contention. Use of ThreadLocalRandom is particularly appropriate when multiple tasks (for example, each a ForkJoinTask) use random numbers in parallel in thread pools.

大意就是用ThreadLocalRandom更适合用在多线程下，能大幅减少多线程并行下的性能开销和资源争抢。

　既然ThreadLocalRandom在多线程下表现这么牛逼，它究竟是如何做到的？我们来看下源码，它的核心代码是这个（在看源码时需要注意一点，虽然ThreadLocalRandom也实现了next函数，但是在这个函数上面有一句，定义了这个方法，但绝不使用，你也可以从next*方法里面看出，使用的都是mix32(nextSeed)或者mix64(nextSeed)来获取随机数）

```java
    final long nextSeed() {
        Thread t; long r; // read and update per-thread seed
        UNSAFE.putLong(t = Thread.currentThread(), SEED,
                       r = UNSAFE.getLong(t, SEED) + GAMMA);
        return r;
    }
```

上面虽然使用了UNSAFE对象，但是没有调用CAS方法，只是简单的替换Thread对象中的threadLocalRandomSeed属性，所以不要一看到UNSAFE这个类，就当成要调用CAS方法，我刚开始阅读的时候就有这个疑惑，自己太菜了。

在创建ThreadLocalRandom对象时，ThreadLocalRandom是对每个线程都设置了单独的随机数种子，这样就不会发生多线程同时更新一个数时产生的资源争抢了，用空间换时间。

### 3. 补充

在生成验证码的情况下，不要使用Random，因为它是线性可预测的。所以在安全性要求比较高的场合，应当使用SecureRandom。从理论上来说计算机产生的随机数都是伪随机数，要想**产生高强度的随机数，有两个重要的因素：种子和算法。当然算法是可以有很多的，但是如何选择种子是非常关键的因素。如Random，它的种子是System.currentTimeMillis()，所以它的随机数都是可预测的。那么如何得到一个近似随机的种子？这里有一个很别致的思路：收集计算机的各种信息，如键盘输入时间，CPU时钟，内存使用状态，硬盘空闲空间，IO延时，进程数量，线程数量等信息，来得到一个近似随机的种子。这样的话，除了理论上有破解的可能，实际上基本没有被破解的可能。而事实上，现在的高强度的随机数生成器都是这样实现的。**



### 参考

1. [java.util.Random和concurrent.ThreadLocalRandom对比](https://xindoo.me/article/1400)
2. [C 位操作 左移32位 错误](https://blog.csdn.net/huqinweI987/article/details/70941199) 这个是我在进行源码研究时，发先自己int类型的说移动32位还是原数子，从这篇文章找到了答案
3. [Java随机数探秘](https://www.cnkirito.moe/java-random/)