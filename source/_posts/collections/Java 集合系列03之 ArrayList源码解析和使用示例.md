---
title: Java 集合系列03之ArrayList源码解析和使用示例
tags:
  - 集合
categories:
  - java
abbrlink: 4dcbcf5f
date: 2019-03-04 12:09:00
---
### 概要

本篇博客主要的内容是介绍ArrayList的使用和对其源码进行分析，并比较ArrayList不同迭代器之间的性能

内容包括：

1. ArrayList 简介
2. ArrayList数据结构
3. ArrayList源码分析
4. ArrayList遍历方式分析
5. toArray 异常
6. ArrayList 基本使用示例

## 1. ArrayList 简介

ArrayList 是一个数组队列，可以动态的改变大小，相当于动态数组。与Java中的数组相比，它的容量能动态增长。他继承于AbstractList，实现了List，RandomAccess，Cloneable，java.io.Serializable接口。

ArrayList 继承了AbstractList，实现了List。因此就具有相关的添加、删除、修改、遍历等功能。

ArrayList 实现了RandmoAccess接口，即提供了随机访问功能。RandmoAccess是java中用来被List实现，为List提供快速访问功能的。在ArrayList中，我们即可以通过元素的序号快速获取元素对象；这就是快速随机访问。稍后，我们会比较List的“快速随机访问”和“通过Iterator迭代器访问”的效率。

ArrayList 实现了Cloneable接口，即覆盖了函数clone()，能被克隆。

ArrayList 实现java.io.Serializable接口，这意味着ArrayList支持序列化，能通过序列化去传输。

**注意的一点是：ArrayList不是线程安全的！所以不要再并发程序中使用**

<!-- more --->

## 2. ArrayList 数据结构

Arraylist的类图如下

![upload successful](/images/pasted-156.png)

ArrayList包含了两个重要的对象：elementData 和 size。

1. elementData 是"Object[]类型的数组"，它保存了添加到ArrayList中的元素。实际上，elementData是个动态数组，我们能通过构造函数 ArrayList(int initialCapacity)来执行它的初始容量为initialCapacity；如果通过不含参数的构造函数ArrayList()来创建ArrayList，则elementData的容量默认是10。elementData数组的大小会根据ArrayList容量的增长而动态的增长，具体的增长方式，请参考源码分析中的ensureCapacity()函数。
2. size 则是动态数组的实际大小。

## 3. ArrayList源码分析

下面所有源码都是基于**java 8** 来进行的分析：按照add，remove，get，Iterator，ListIterator的顺序来进行源码分析

首先看一下一些比较重要的属性，可以方便后面理解源码：

```java
//默认初始容量
private static final int DEFAULT_CAPACITY = 10;

//如果是空实例，这个就会减少创建的开销，
private static final Object[] EMPTY_ELEMENTDATA = {};

//使用new ArrayList()创建时，elementData会指向下面这个数组
private static final Object[] DEFAULTCAPACITY_EMPTY_ELEMENTDATA = {};

//当开始添加任何元素时，此属性就会指向EMPTY_ELEMENTDATA
transient Object[] elementData; 

//集合包含元素的数量
private int size;
```

**构造函数**

```java
//设置ArrayList的初始容量，当时负数时抛出错误
public ArrayList(int initialCapacity) {
    if (initialCapacity > 0) {
        this.elementData = new Object[initialCapacity];
    } else if (initialCapacity == 0) {
        this.elementData = EMPTY_ELEMENTDATA;
    } else {
        throw
            new IllegalArgumentException("Illegal Capacity: " + 
                                         initialCapacity);
    }
}

//初始化ArrayList
public ArrayList() {
    this.elementData = DEFAULTCAPACITY_EMPTY_ELEMENTDATA;
}

//添加指定的集合到此集合中并初始化
public ArrayList(Collection<? extends E> c) {
    elementData = c.toArray();
    if ((size = elementData.length) != 0) {
        //c.toArray 返回的数组类型有可能和此集合的类型不相同，
        //则重新拷贝元素到本集合的数组中去
        if (elementData.getClass() != Object[].class)
            elementData = Arrays.copyOf(elementData, size, 
                                        Object[].class);
    } else {
        // 利用空集合来初始化
        this.elementData = EMPTY_ELEMENTDATA;
    }
}
```

从上面可知，提供了三个默认构造函数，分别是默认构造函数，将会初始化一个空数组，指定长度的构造函数，根据指定的长度来初始化数组，添加一个集合来初始化数组，这个会初始化一个和集合长度相等的数组，并把数据添加进去。

### **添加：add**

我们先了解一下具体的添加过程首先会检测数组是否还能添加元素，如果已经满了，则创建一个更长的数组，将原先数组的数据拷贝过来，然后在添加元素。具体源码如下

```java
 public boolean add(E e) {
     // 确认数组是否已满
     ensureCapacityInternal(size + 1);  // Increments modCount!!
     // 在集合的末尾添加元素
     elementData[size++] = e;
     return true;
}


private void ensureCapacityInternal(int minCapacity) {
    // 判断数组是否为空，如果为空，比较DEFAULT_CAPACITY
    // 和minCapacity大小，使用较大的那个来初始化数组
    if (elementData == DEFAULTCAPACITY_EMPTY_ELEMENTDATA) {
        minCapacity = Math.max(DEFAULT_CAPACITY, minCapacity);
    }
	// 初始化一个指定的长度
    ensureExplicitCapacity(minCapacity);
}


private void ensureExplicitCapacity(int minCapacity) {
    // 修改modCount 防止出现fail-fast
    modCount++;

    // 如果miniCapacity大于数组的长度，说明数组已满，
    // 则创建一个更大的数组
    if (minCapacity - elementData.length > 0)
        grow(minCapacity);
}

// 初始化一个更大的数组
private void grow(int minCapacity) {

    int oldCapacity = elementData.length;
    // 设置新的数组长度为原来的三倍
    int newCapacity = oldCapacity + (oldCapacity >> 1);
    // 检测新的数组长度是否大于指定索引位置，如果小于，则使用minCapacity
    if (newCapacity - minCapacity < 0)
        newCapacity = minCapacity;
    if (newCapacity - MAX_ARRAY_SIZE > 0)
        newCapacity = hugeCapacity(minCapacity);
   // 初始化newCapacity长度的数组，并拷贝旧数据
    elementData = Arrays.copyOf(elementData, newCapacity);
}
```

在上面已经将添加过程注释的很清楚，下面主要介绍一下添加过程：

1.  首先判断数组是否为null，如果为null然后判断指定的下标位置和默认长度谁大则使用谁，若使用默认构造函数，则ArrayList的**默认容量大小是10**。
2.  判断当钱ArrayList容量是否足以容纳指定下标的元素，不足ArrayList会重新设置容量：**新的容量=原始容量*3**。然后初始化新容量的数组，然后将旧的数组数据拷贝到新数组中去
3. 在指定下标添加元素

至于`add(int index, E element) `,大体上差不多，不过在指定位置添加元素后，需要将原先位置的元素以及后面的元素往后順移一位，大概过程如下

```java
public void add(int index, E element) {
    // 检查范围是否合适，如果小于0和大于size则抛出错误
    rangeCheckForAdd(index);
    // 判断数组是否已满
    ensureCapacityInternal(size + 1);  // Increments modCount!!
    // 拷贝index下标之后的元素往后移以为
    System.arraycopy(elementData, index, elementData, index + 1,
    size - index);
    //添加元素
    elementData[index] = element;
    size++;
}
```

### **删除 remove**

具体源码如下

```java
 public E remove(int index) {
     // 判断下标是否合适
     rangeCheck(index);

     // 操作数加1，
    modCount++;
    E oldValue = elementData(index);

    int numMoved = size - index - 1;
    // 下标之后的数据向前移动一位
    if (numMoved > 0)
    	System.arraycopy(elementData, index+1, elementData, index,
    numMoved);
     // 设置最后一个元素为空，方便GC
    elementData[--size] = null; // clear to let GC do its work

    return oldValue;
}
```

**remove(object)**

```java
 public boolean remove(Object o) {
 		// 查找到素有和o相同的对象，并删除
        if (o == null) {
            for (int index = 0; index < size; index++)
                if (elementData[index] == null) {
                    fastRemove(index);
                    return true;
                }
        } else {
            for (int index = 0; index < size; index++)
                if (o.equals(elementData[index])) {
                    fastRemove(index);
                    return true;
                }
        }
        return false;
    }

 	// 这个相对于上面的remove(index),省略了异步索引的校验，因此比上面删除少一次检查，
	// 其他一样
    private void fastRemove(int index) {
        modCount++;
        int numMoved = size - index - 1;
        if (numMoved > 0)
            System.arraycopy(elementData, index+1, elementData, index,
                             numMoved);
        elementData[--size] = null; // clear to let GC do its work
    }

```

### get

这个操作就比较简单，检查index范围是否正确，然后返回指定下标的元素

```java
public E get(int index) {
    rangeCheck(index);

    return elementData(index);
}
```

### Iterator和ListIterator

这俩个是通过内部维持一个当前操作的下标来实现的，当判断hashNext的时候判断当前下标是否超过size即可。

不过要注意的一点是，每一此next操作，都会进行如下操作

```java
 final void checkForComodification() {
            if (modCount != expectedModCount)
                throw new ConcurrentModificationException();
        }
```

会检测modCounrt和迭代器保存的modCount是否相等，如果相同，则说明有其他线程修改了集合，会抛出并发修改异常。

## 4. ArrayList 遍历方式

>(01) 第一种，**通过迭代器遍历**。即通过Iterator去遍历。
>
>```
>Integer value = null;
>Iterator iter = list.iterator();
>while (iter.hasNext()) {
>    value = (Integer)iter.next();
>}
>```
>
>(02) 第二种，**随机访问，通过索引值去遍历。**
>由于ArrayList实现了RandomAccess接口，它支持通过索引值去随机访问元素。
>
>```
>Integer value = null;
>int size = list.size();
>for (int i=0; i<size; i++) {
>    value = (Integer)list.get(i);        
>}
>```
>
>(03) 第三种，**for循环遍历**。如下：
>
>```
>Integer value = null;
>for (Integer integ:list) {
>    value = integ;
>}
>```
>
>下面通过一个实例来演示效率问题
>
>```java
>package Collections.cnblog.collection.list;
>
>import java.util.ArrayList;
>import java.util.Iterator;
>import java.util.List;
>
>/**************************************
> *      Author : zhangke
> *      Date   : 2018/1/18 19:37
> *      Desc   : 测出ArrayList三种哪一种遍历最快
> ***************************************/
>public class StudyArrayList {
>
>    public static void main(String[] args) {
>        List<Integer> list = new ArrayList<>();
>        for (int i = 0; i < 100000; i++) {
>            list.add(i);
>        }
>        iteratorThroughFor(list);
>        iteratorThroughFor2(list);
>        iteratorThroughRandomAccess(list);
>    }
>
>    public static void iteratorThroughRandomAccess(List list) {
>        long startTime;
>        long endTime;
>        startTime = System.currentTimeMillis();
>        for (int i = 0; i < list.size(); i++) {
>            list.get(i);
>        }
>        endTime = System.currentTimeMillis();
>        System.out.println("iteractorRandomAccess interval: " + (endTime - startTime));
>    }
>
>    public static void iteratorThroughFor2(List list) {
>        long startTime;
>        long endTime;
>        startTime = System.currentTimeMillis();
>        for (Object object : list) {
>
>        }
>        endTime = System.currentTimeMillis();
>        System.out.println("iteractorfor interval: " + (endTime - startTime));
>    }
>
>    public static void iteratorThroughFor(List list) {
>        long startTime;
>        long endTime;
>        startTime = System.currentTimeMillis();
>        for (Iterator iterator = list.iterator(); iterator.hasNext(); ) {
>            iterator.next();
>        }
>        endTime = System.currentTimeMillis();
>        System.out.println("iteractor interval: " + (endTime - startTime));
>    }
>}
>
>```
>
>结果如下
>
>```
>iteractor interval: 7
>iteractorfor2 interval: 4
>iteractorRandomAccess interval: 4
>```
>
>我测试了几次，感觉java8里面随机访问和foreach访问比较快，不过相差也不是太大。不过数据量大的话，还是推介使用随机访问。
>
>

## 5. toArray 异常

>```java
>Object[] toArray()
><T> T[] toArray(T[] arr)
>```
>
>调用 toArray() 函数会抛出“java.lang.ClassCastException”异常，但是调用 toArray(T[] contents) 能正常返回 T[]。
>
>toArray() 会抛出异常是因为 toArray() 返回的是 Object[] 数组，将 Object[] 转换为其它类型(类如，将Object[]转换为的Integer[])则会抛出“java.lang.ClassCastException”异常，因为**Java不支持向下转型**。具体的可以参考前面ArrayList.java的源码介绍部分的toArray()。
>解决该问题的办法是调用 < T > T[] toArray(T[] contents) ， 而不是 Object[] toArray()。

## 6. ArrayList基本使用

>```java
>import java.util.*;
>
>public class ArrayListTest {
>
>    public static void main(String[] args) {
>        
>        // 创建ArrayList
>        ArrayList list = new ArrayList();
>
>        // 将“”
>        list.add("1");
>        list.add("2");
>        list.add("3");
>        list.add("4");
>        // 将下面的元素添加到第1个位置
>        list.add(0, "5");
>
>        // 获取第1个元素
>        System.out.println("the first element is: "+ list.get(0));
>        // 删除“3”
>        list.remove("3");
>        // 获取ArrayList的大小
>        System.out.println("Arraylist size=: "+ list.size());
>        // 判断list中是否包含"3"
>        System.out.println("ArrayList contains 3 is: "+ list.contains(3));
>        // 设置第2个元素为10
>        list.set(1, "10");
>
>        // 通过Iterator遍历ArrayList
>        for(Iterator iter = list.iterator(); iter.hasNext(); ) {
>            System.out.println("next is: "+ iter.next());
>        }
>
>        // 将ArrayList转换为数组
>        String[] arr = (String[])list.toArray(new String[0]);
>        for (String str:arr)
>            System.out.println("str: "+ str);
>
>        // 清空ArrayList
>        list.clear();
>        // 判断ArrayList是否为空
>        System.out.println("ArrayList is empty: "+ list.isEmpty());
>    }
>}
>```
>
>







