title: Java 集合系列09之 Map架构
tags:
  - 集合
categories:
  - java
date: 2019-03-04 17:40:00
---

---
abbrlink: 6
title: Java集合系列09 之 Map架构

date: 2019-03-04 18:18:02

# Java集合系列09 之 Map架构

我们先学习Map，然后再学习Set；因为**Set的实现类都是基于Map来实现的**(如，HashSet是通过HashMap实现的，TreeSet是通过TreeMap实现的)。

首先，我们看看Map架构。

![upload successful](/images/pasted-161.png)

如上图：

1. Map 是**映射 接口**，Map中存储的内容是**键值对(key-value)**。
2.  AbstractMap 是**继承于Map的抽象类，它实现了Map中的大部分API**。其它Map的实现类可以通过继承AbstractMap来减少重复编码。
3. SortedMap 是继承于Map的接口。SortedMap中的内容是**排序的键值对**，排序的方法是通过比较器(Comparator)。
4. NavigableMap 是继承于SortedMap的接口。相比于SortedMap，NavigableMap有一系列的导航方法；如"获取大于/等于某对象的键值对"、“获取小于/等于某对象的键值对”等等。 
5. TreeMap 继承于AbstractMap，且实现了NavigableMap接口；因此，TreeMap中的内容是“**有序的键值对**”！
6. HashMap 继承于AbstractMap，但没实现NavigableMap接口；因此，HashMap的内容是“**键值对，但不保证次序**”！
7. LinkedHashMap继承HashMap并实现了Map接口，同时具有可预测的迭代顺序（按照插入顺序排序）。
8. Hashtable 虽然不是继承于AbstractMap，但它继承于Dictionary(Dictionary也是键值对的接口)，而且也实现Map接口；因此，Hashtable的内容也是“**键值对，也不保证次序**”。但和HashMap相比，Hashtable是线程安全的，而且它支持通过Enumeration去遍历。
9. WeakHashMap 继承于AbstractMap。它和HashMap的键类型不同，**WeakHashMap的键是“弱键”**。

