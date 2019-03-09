abbrlink: 14
title: Java 集合系列16之 Set架构
tags:
  - 集合
categories:
  - java
date: 2019-03-05 07:58:00
---
>接下来主要学习Set。由于Set的很多实现都是就与Map来实现的，前面通过对Map的了解之后，相对来说比较好学习
>
>下图是Set架构
>
>![]()
>
>(01) Set 是继承于Collection的接口。它是一个不允许有重复元素的集合。其中接口与Collection中方法完全一样。
>(02) AbstractSet 是一个抽象类，它继承于AbstractCollection，AbstractCollection实现了Set中的绝大部分函数，为Set的实现类提供了便利。
>(03) HastSet 和TreeSet 是Set的两个实现类。
>        HashSet依赖于HashMap，它实际上是通过HashMap实现的。HashSet中的元素是无序的。
>        TreeSet依赖于TreeMap，它实际上是通过TreeMap实现的。TreeSet中的元素是有序的。
>
>​	LinkedHashSet是继承于HashSet，主要是保证元素按照插入的顺序存储
>
>