---
title: Java集合系列14 之WeakHashMap源码解析和使用示例
tags:
  - 集合
categories:
  - java
  - collections
abbrlink: 8ab0f653
date: 2019-03-04 23:58:00
---
### 概要

>1. WeakHashMap 介绍
>2. WeakHashMap源码解析
>3. WeakHasMap示例
<!-- more -->

### **1.  WeakHashMap介绍**#

>  WeakHashMap 继承于AbstractMap，实现了Map接口。
>  WeakHashMap 也是一个**散列表**，它存储的内容也是**键值对(key-value)映射**，而且**键和值都可以是null**。
>   不过WeakHashMap的**键是“弱键”**。在 WeakHashMap 中，当某个键不再正常使用时，会被从WeakHashMap中被自动移除。更精确地说，对于一个给定的键，其映射的存在并不阻止垃圾回收器对该键的丢弃，这就使该键成为可终止的，被终止，然后被回收。某个键被终止时，它对应的键值对也就从映射中有效地移除了。
>     这个“弱键”的原理呢？大致上就是，**通过WeakReference和ReferenceQueue实现的**。 WeakHashMap的key是“弱键”，即是WeakReference类型的；ReferenceQueue是一个队列，它会保存被GC回收的“弱键”。实现步骤是：
>     (01) 新建WeakHashMap，将“**键值对**”添加到WeakHashMap中。
>            实际上，WeakHashMap是通过数组table保存Entry(键值对)；每一个Entry实际上是一个单向链表，即Entry是键值对链表。
>    (02) 当**某“弱键”不再被其它对象引用**，并**被GC回收**时。在GC回收该“弱键”时，**这个“弱键”也同时会被添加到ReferenceQueue(queue)队列**中。
>    (03) 当下一次我们需要操作WeakHashMap时，会先同步table和queue。table中保存了全部的键值对，而queue中保存被GC回收的键值对；同步它们，就是**删除table中被GC回收的键值对**。
>    这就是“弱键”如何被自动从WeakHashMap中删除的步骤了。
>
> 和HashMap一样，WeakHashMap是不同步的。可以使用 Collections.synchronizedMap 方法来构造同步的 WeakHashMap。
>
> **WeakHashMap的构造函数**
>
> WeakHashMap共有4个构造函数,如下：
>
> ```java
> // 默认构造函数。
> WeakHashMap()
>
> // 指定“容量大小”的构造函数
> WeakHashMap(int capacity)
>
> // 指定“容量大小”和“加载因子”的构造函数
> WeakHashMap(int capacity, float loadFactor)
>
> // 包含“子Map”的构造函数
> WeakHashMap(Map<? extends K, ? extends V> map)
> ```
>
> 
>
> **WeakHashMap的API**
>
> ```java
> void                   clear()
> Object                 clone()
> boolean                containsKey(Object key)
> boolean                containsValue(Object value)
> Set<Entry<K, V>>       entrySet()
> V                      get(Object key)
> boolean                isEmpty()
> Set<K>                 keySet()
> V                      put(K key, V value)
> void                   putAll(Map<? extends K, ? extends V> map)
> V                      remove(Object key)
> int                    size()
> Collection<V>          values()
> ```
>
> 

   ### 2. 源码解析

>
>(01) WeakHashMap继承于AbstractMap，并且实现了Map接口。
>(02) WeakHashMap是哈希表，但是它的键是"弱键"。WeakHashMap中保护几个重要的成员变量：table, size, threshold, loadFactor, modCount, queue。
>　　table是一个Entry[]数组类型，而Entry实际上就是一个单向链表。哈希表的"key-value键值对"都是存储在Entry数组中的。 
>　　size是Hashtable的大小，它是Hashtable保存的键值对的数量。 
>　　threshold是Hashtable的阈值，用于判断是否需要调整Hashtable的容量。threshold的值="容量*加载因子"。
>　　loadFactor就是加载因子。 
>　　modCount是用来实现fail-fast机制的
>　　queue保存的是“已被GC清除”的“弱引用的键”。
>
>(03)WeakHashMap和HashMap都是通过"拉链法"实现的散列表。但是WeakHashMap没有使用红黑树。
>
>​    WeakReference是“弱键”实现的哈希表。它这个“弱键”的目的就是：实现对“键值对”的动态回收。当“弱键”不再被使用到时，GC会回收它，WeakReference也会将“弱键”对应的键值对删除。
>    “弱键”是一个“弱引用(WeakReference)”，在Java中，WeakReference和ReferenceQueue 是联合使用的。在WeakHashMap中亦是如此：如果弱引用所引用的对象被垃圾回收，Java虚拟机就会把这个弱引用加入到与之关联的引用队列中。 接着，WeakHashMap会根据“引用队列”，来删除“WeakHashMap中已被GC回收的‘弱键’对应的键值对”。
>    另外，理解上面思想的重点是通过 expungeStaleEntries() 函数去理解。

### 3. 使用示例

>```
>/**************************************
> *      Author : zhangke
> *      Date   : 2018/4/1 20:57
> *      Desc   : WeakHashMap 使用示例
> ***************************************/
>public class WeakHashMapTest {
>    public static void main(String[] args) {
>        test();
>    }
>
>    public static void test() {
>        String one = new String("one");
>        String two = new String("two");
>        String three = new String("three");
>
>        //创建WeakHashMap
>        WeakHashMap<String, Integer> wh = new WeakHashMap<>();
>
>        //插入键值对
>        wh.put(one, new Integer(1));
>        wh.put(two, 2);
>        wh.put(three, 3); //这个利用自动装箱技术
>
>        //输出键值对
>        System.out.println(wh);
>
>        //测试是否包含键值
>        System.out.println("contains two: " + wh.containsKey("two"));
>        System.out.println("contains one: " + wh.containsKey("one"));
>
>        //测试是够包含value
>        System.out.println("contains value 1 : " + wh.containsValue(1));
>
>        //删除节点three
>        wh.remove("three");
>        System.out.println("after remove three: " + wh);
>
>
>        //测试WeakHashMap的自动回收技术
>        //将one设置为null
>        // 这意味着“弱键”one再没有被其它对象引用，调用gc时会回收WeakHashMap中与“w1”对应的键值对
>        one = null;
>
>        System.gc(); //执行GC
>
>        //下面是等待GC回收，GC回收可能需要一段时间
>        try {
>            Thread.sleep(10000);
>        } catch (InterruptedException e) {
>            e.printStackTrace();
>        }
>
>        //遍历WeakHashMap
>        Iterator<Map.Entry<String, Integer>> iterator =
>                wh.entrySet().iterator();
>        while (iterator.hasNext()) {
>            Map.Entry<String, Integer> en = iterator.next();
>            System.out.println(en.getKey() + " : " + en.getValue());
>        }
>        //打印键值对个数
>        System.out.println(wh.size());
>
>        //清空Map
>        wh.clear();
>    }
>}
>```
>
>注意一点的是：其中GC过之后，打印的Map值可能不同。因为gc回收需要一段时间，这是你需要去调整等待GC的时间。就可以看到弱引用被回收