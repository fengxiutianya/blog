---
title: String、StringBuffer和StringBuilder对比
tags:
  - java
  - java基础
  - String
categories:
  - java
  - 基础
author: zhangke
abbrlink: 190054bc
date: 2019-01-02 13:24:00
---
## 概述
1. 简单介绍
2. 性能对比
3. 字符串常量池

## 1. 简单介绍
这里只对这三个类做个简单的总结，如果你希望详细了解这三个类，可以看一下三篇文章，我觉得写得很好。
1. [String 详解(String系列之1)](https://www.cnblogs.com/skywang12345/p/string01.html)
2. [StringBuilder 详解 (String系列之2)](http://www.cnblogs.com/skywang12345/p/string02.html)
3. [StringBuffer 详解 (String系列之3)](http://www.cnblogs.com/skywang12345/p/string03.html)

首先一个简单的对比
**String 字符串常量**
**StringBuffer 字符串变量（线程安全）**
**StringBuilder 字符串变量（非线程安全）**
StringBuffer与StringBuilder的实现几乎是一样的，只是StringBufferr为了保证线程安全，在方法前面加上Synchronize关键字来保证安全性，StringBuilder是在Jdk1.5之后才出现的，因此下面先用StringBuffer来和String进行对比
### String VS StringBuffer
String类型和StringBuffer类型俩者都是线程安全，主要区别其实在于String是不可变的对象, 因此在每次对String类型进行改变的时候其实都等同于生成了一个新的String对象，然后将指针指向新的String对象，所以经常改变内容的字符串最好不要用String，因为每次生成对象都会对系统性能产生影响，特别当内存中无引用对象多了以后， JVM的GC就会开始工作，那速度是一定会相当慢的。

而如果是使用StringBuffer类则结果就不一样了，每次结果都会对StringBuffer对象本身进行操作，而不是生成新的对象，再改变对象引用。所以在一般情况下我们推荐使用StringBuffer，特别是字符串对象经常改变的情况下。而在某些特别情况下，String对象的字符串拼接其实是被JVM解释成了StringBuffer对象的拼接，所以这些时候String对象的速度并不会比StringBuffer对象慢，而特别是以下的字符串对象生成中， String效率是远要比StringBuffer快：
```java
 String S1 = “This is only a” + “ simple” + “ test”;
 StringBuffer Sb = new StringBuffer(“This is only a”).append(“ simple”).append(“ test”);
```
测试结果：
```
Benchmark                         Mode  Cnt   Score    Error  Units
StringBenchmark.testString        avgt    3   5.701 ±  2.431  ns/op
StringBenchmark.testStringBuffer  avgt    3  27.077 ± 21.828  ns/op
```
**其中score对应是每次操作花费的纳秒数**你会很惊讶的发现，生成S1对象的速度简直太快了，而这个时候StringBuffer居然速度上根本一点都不占优势。其实这是JVM做的一次优化，在JVM眼里，这个**String S1 = “This is only a” + “ simple” + “test”;**其实就是：**String S1 = “This is only a simple test”**; 所以拼接速度很快。但大家这里要注意的是，如果你的字符串是来自另外的String对象的话，速度就没那么快了，下面就是一个例子：
``` java
String S2 = “This is only a”;
String S3 = “ simple”;
String S4 = “ test”;
String S1 = S2 +S3 + S4;
```
这时候 JVM 会规规矩矩的按照原来的方式去做,在大部分情况下StringBuffer的性能要好于String。
### StringBuffer VS StringBuilder
**StringBuffer**
Java.lang.StringBuffer线程安全的可变字符序列。虽然在任意时间点上它都包含某种特定的字符序列，但通过某些方法调用可以改变该序列的长度和内容。可将字符串缓冲区安全地用于多个线程。可以在必要时对这些方法进行同步，因此任意特定实例上的所有操作就好像是以串行顺序发生的，该顺序与所涉及的每个线程进行的方法调用顺序一致。StringBuffer上的主要操作是append和insert方法，可重载这些方法，以接受任意类型的数据。每个方法都能有效地将给定的数据转换成字符串，然后将该字符串的字符追加或插入到字符串缓冲区中。append方法始终将这些字符添加到缓冲区的末端；而insert方法则在指定的点添加字符。
**StringBuilder**
java.lang.StringBuilder一个可变的字符序列，是5.0新增的。此类提供一个与StringBuffer兼容的 API，但不保证同步。该类被设计用作StringBuffer的一个简易替换，用在字符串缓冲区被单个线程使用的时候（这种情况很普遍）。如果可能，建议优先采用该类，因为在大多数实现中，它比StringBuffer要快。两者的方法基本相同。

## 2. 性能对比
测试性能源码(使用了JMH来进行基准测试)
``` java
@BenchmarkMode({Mode.AverageTime})
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@Warmup(iterations = 3, time = 3)
@Measurement(iterations = 3, time = 3)
@Threads(1)
@Fork(1)
@State(Scope.Thread)
public class StringBenchmark {
    String s1;
    StringBuffer stringBuffer;
    StringBuilder stringBuilder;

    @Setup(Level.Iteration)
    public void before() {
        s1 = "s1";
        stringBuffer = new StringBuffer("s1");
        stringBuilder = new StringBuilder("s1");
    }
    @Benchmark
    public String testStringAppend() {
        return s1 += "s2";
    }
    @Benchmark
    public StringBuffer testStringBufferAppend() {
        return stringBuffer.append("s2");
    }
    @Benchmark
    public StringBuilder testStringBuilderAppend() {
        //下面这个还会单独生成一个String对象，因此性能上有所损失，所以调整一下
//        return new StringBuilder("s1").append("s2").toString();
        return stringBuilder.append("s2");
    }
    public static void main(String[] args) throws RunnerException {
        Options opt = new OptionsBuilder()
                .include(StringBenchmark.class.getSimpleName())
                .build();
        new Runner(opt).run();
    }
}
```
测试结果
```
Benchmark                                Mode  Cnt      Score       Error  Units
StringBenchmark.testStringAppend         avgt    3  28179.211 ± 25587.942  ns/op
StringBenchmark.testStringBufferAppend   avgt    3     26.152 ±   189.157  ns/op
StringBenchmark.testStringBuilderAppend  avgt    3     21.150 ±    48.648  ns/op
```
从结果可以验证，在上面简单介绍中所说的，如果字符串拼接操作，最好选择StringBuilder，如果要保证线程安全选择StringBuffer，另外上面结果有一点需要注意的是，从测试结果看，StringBuffer和StringBuilder的性能差不多，这是因为我是在jdk8上运行并且只有一个线程，因此对Synchronize做了优化，使得StringBuffer性能得到提升。
## 3.字符串常量池
我觉得这篇文章已经写得非常好因此可以看这篇文章
[String：字符串常量池](https://segmentfault.com/a/1190000009888357)
但是我对这个持有疑问
**String str2 = new String("ABC") + "ABC" ; 会创建多少个对象?**
str2 ：
字符串常量池："ABC" : 1个
堆：new String("ABC") ：1个
引用： str2 ：1个
总共 ： 3个
我认为结果是这样的：
字符串常量池 “ABC” 1个
堆：new String("ABC"),new String("ABCABC"),new StringBuilder()
new String("ABCABC") 是由于new String("ABC")+"ABC"在编译的时候会按照下面这种方式来生成
```java
StringBuilder  stringBuilder = new StringBuilder();
stringBuilder.append("ABC");
stringBuilder.append("ABC);
stringBuilder.toString();// 这时就会产生 new String("ABCABC)
```
另外由于这个是使用new String("ABC") + "ABC"，因此ABCABC不会进入常量池，除非调用String.intern()方法
不知道对不对，欢迎大家讨论
### 参考

1.  [String,StringBuffer与StringBuilder的区别|线程安全与线程不安全](https://www.cnblogs.com/xingzc/p/6277581.html)
2. [字面量和常量池初探](https://mccxj.github.io/blog/20130615_java-string-constant-pool.html) 基于java1.6