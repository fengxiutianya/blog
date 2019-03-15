---
title: Java 集合系列07之 Stack源码解析和使用示例
tags:
  - 集合
categories:
  - java
abbrlink: ab3cc2a5
date: 2019-03-04 15:41:00
---

---
### 概要

本篇博客将主要学习Stack。Stack很简单，就是一些简单的栈操作，他继承Vector。

主要内容如下:

1. Stack 介绍
2. Stack 源码解析

<!-- more -->

### 1. Stack介绍

>Stack简介
>
>Stack是栈。它的特性是：先进后出（FILO）。
>
>Stack是继承Vector，因此Stack的数据结构和Vector很相似。在这里就不具体介绍。
>
>**Stack类图**：
>
>![upload successful](/images/pasted-159.png)
>
>Stack的构造函数
>
>```
>只有一个默认构造函数，如下
>stack()
>```
>
>**Stack的API**
>
>Stack是栈，它**常用的API**如下：
>
>```
>             boolean       empty()
>synchronized E             peek()
>synchronized E             pop()
>             E             push(E object)
>synchronized int           search(Object o)
>```

### Stack源码分析

>```java
>package java.util;
>
>/**
> * Stack 顾名思义就是栈，LIFO 后进先出
> * 通过集成Vector来实现
> */
>public class Stack<E> extends Vector<E> {
>    /**
>     * 创建一个空栈
>     */
>    public Stack() {
>    }
>
>    /**
>     * 插入元素到队尾并返回
>     */
>    public E push(E item) {
>        addElement(item);
>
>        return item;
>    }
>
>    /**
>     * 删除并返回栈首元素
>     */
>    public synchronized E pop() {
>        E obj;
>        int len = size();
>
>        obj = peek();
>        removeElementAt(len - 1);
>
>        return obj;
>    }
>
>    /**
>     * 获取栈首元素但不删除
>     */
>    public synchronized E peek() {
>        int len = size();
>
>        if (len == 0)
>            throw new EmptyStackException();
>        return elementAt(len - 1);
>    }
>
>    /**
>     * 判断栈是否为空
>     */
>    public boolean empty() {
>        return size() == 0;
>    }
>
>    /**
>     *从栈顶开始查找第一个和对象o相等的元素
>     */
>    public synchronized int search(Object o) {
>        int i = lastIndexOf(o);
>
>        if (i >= 0) {
>            return size() - i;
>        }
>        return -1;
>    }
>
>    /** use serialVersionUID from JDK 1.0.2 for interoperability */
>    private static final long serialVersionUID = 1224463164541339165L;
>}
>
>```
>
>**总结**：
>
>(01) Stack实际上也是通过数组去实现的。
>​       执行**push**时(即，**将元素推入栈中**)，是通过将元素追加的数组的末尾中。
>​       执行**peek**时(即，**取出栈顶元素，不执行删除**)，是返回数组末尾的元素。
>​       执行**pop**时(即，**取出栈顶元素，并将该元素从栈中删除**)，是取出数组末尾的元素，然后将该元素从数组中删除。
>(02) Stack继承于Vector，意味着Vector拥有的属性和功能，Stack都拥有。
>
>

