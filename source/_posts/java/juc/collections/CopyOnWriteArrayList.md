---
title: CopyOnWriteArrayList
tags:
  - juc
  - 集合
categories:
  - java
  - juc
  - collections
author: fengxiutianya
abbrlink: 843bee8d
date: 2019-03-07 03:07:00
---
# CopyOnWriteArrayList

## 概述

Copy-On-Write简称COW，是一种用于程序设计中的优化策略。其基本思路是，从一开始大家都在共享同一个内容，当某个人想要修改这个内容的时候，才会真正把内容Copy出去形成一个新的内容然后再改，这是一种延时懒惰策略。从JDK1.5开始Java并发包里提供了两个使用CopyOnWrite机制实现的并发容器,它们是CopyOnWriteArrayList和CopyOnWriteArraySet。CopyOnWrite容器非常有用，可以在非常多的并发场景中使用到。
<!-- more -->

1. CopyOnWriteArrayList简介
2. CopyOnWriteArrayList源码分析
3. CopyOnWriteArrayList简单使用
4. CopyOnWriteArrayList使用注意事项
5. CopyOnWriteArraySet分析

## 1. CopyOnWriteArrayList简介

CopyOnWrite容器即写时复制的容器。通俗的理解是当我们往一个容器添加元素的时候，不直接往当前容器添加，而是先将当前容器进行Copy，复制出一个新的容器，然后新的容器里添加元素，添加完元素之后，再将原容器的引用指向新的容器。这样做的好处是我们可以对CopyOnWrite容器进行并发的读，而不需要加锁，因为当前容器不会添加任何元素。所以CopyOnWrite容器也是一种读写分离的思想，读和写不同的容器。

类图如下

![upload successful](/images/pasted-163.png)

从类图可以看出，CopyOnWriteArrayList是List的一种，从名字其实也可以猜到，他是线程安全的ArrrayList，底层的实现也是数组，这个后面会详细介绍。

## 2.源码分析

这里我们主要分析add，remove，get和迭代器

首先讲一下下面要用到一些属性：

```java
// 可重入锁，用于add，remove操作时进行同步
final transient ReentrantLock lock = new ReentrantLock();

// volatile类型属性，当一个线程修改了array的引用，其他线程会立刻知道
private transient volatile Object[] array;

```

### add 操作

```java
 public boolean add(E e) {
     	
        final ReentrantLock lock = this.lock;
     	// 加锁 
        lock.lock();
        try {
            // 获取array数组
            Object[] elements = getArray();
            int len = elements.length;
            // 拷贝array数组中的内容到新数组中
            Object[] newElements = Arrays.copyOf(elements, len + 1);
            // 在末尾添加指定元素
            newElements[len] = e;
            // 设置array属性的引用为新数组
            setArray(newElements);
            return true;
        } finally {
            // 释放锁
            lock.unlock();
        }
    }
final Object[] getArray() {
    return array;
}
```

从上面可以看出，添加操作就是先将数组内容拷贝到一个新数组中，然后再添加。

**add(int index, E element)**操作也差不多，只不过要比上面的操作多一个次拷贝，具体源码如下

```java
 public void add(int index, E element) {
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            Object[] elements = getArray();
            int len = elements.length;
            if (index > len || index < 0)
                throw new IndexOutOfBoundsException("Index: "+index+
                                                    ", Size: "+len);
            Object[] newElements;
            int numMoved = len - index;
            // 如果是在末尾添加，则直接拷贝原先数据到新数组，然后添加
            if (numMoved == 0)
                newElements = Arrays.copyOf(elements, len + 1);
            else {
                // 如果实在中间添加元素，则要拷贝俩次到新数组
                newElements = new Object[len + 1];
                System.arraycopy(elements, 0, newElements, 0, index);
                System.arraycopy(elements, index, newElements, index + 1,
                                 numMoved);
            }
            //添加元素
            newElements[index] = element;
            setArray(newElements);
        } finally {
            lock.unlock();
        }
    }
```

### remove删除操作

```java
    public E remove(int index) {
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            Object[] elements = getArray();
            int len = elements.length;
            E oldValue = get(elements, index);
            int numMoved = len - index - 1;
            if (numMoved == 0)
                setArray(Arrays.copyOf(elements, len - 1));
            else {
                Object[] newElements = new Object[len - 1];
                System.arraycopy(elements, 0, newElements, 0, index);
                System.arraycopy(elements, index + 1, newElements, index,
                                 numMoved);
                setArray(newElements);
            }
            return oldValue;
        } finally {
            lock.unlock();
        }
    }
```

删除操作，和上面在指定位置添加元素差不过，都是先拷贝索引前后元素到新数组，然后将新数组的引用赋值给array属性。

### get操作

读的时候不需要加锁，如果读的时候有多个线程正在向ArrayList添加数据，读还是会读到旧的数据，因为写的时候不会锁住旧的ArrayList。

```java
    public E get(int index) {
        return get(getArray(), index);
    }

```

###  迭代器

Iterator并发操作不会抛出并发修改异常，因为他和get一样，操作的都是从getArray函数中获取的数组引用，因此当有线程修改了数组内容，不会影响这个就得数组的访问。

ListIterator大致原理和Iterator一样，不过移除了来个操作，remove和set，因为修改的操作有可能体现在旧的数组上，因此修改不会被保存，所以这俩个操作就直接不支持。

## 3. 简单使用

```java
package JUC.collect;

/**************************************
 *      Author : zhangke
 *      Date   : 2018/7/17 17:50
 *      Desc   : 
 ***************************************/

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.CountDownLatch;

/*
 *   CopyOnWriteArrayList是“线程安全”的动态数组，而ArrayList是非线程安全的。
 *
 *   下面是“多个线程同时操作并且遍历list”的示例
 *   (01) 当list是CopyOnWriteArrayList对象时，程序能正常运行。
 *   (02) 当list是ArrayList对象时，程序会产生ConcurrentModificationException异常。
 *
 */
public class CopyOnWriteArrayListTest {

    // TODO: list是ArrayList对象时，程序会出错。
//    private static List<String> list = new ArrayList<String>();
    private static List<String> list = new CopyOnWriteArrayList<>();

    private static CountDownLatch latch = new CountDownLatch(2);


    public static void main(String[] args) {

        // 同时启动两个线程对list进行操作！
        new MyThread("ta").start();
        new MyThread("tb").start();
    }


    private static void printAll() {
        String value = null;
        Iterator iter = list.iterator();
//        System.out.println(list.size());
        while (iter.hasNext()) {
            value = (String) iter.next();
            System.out.print(value + ", ");
        }
        System.out.println();
    }


    private static class MyThread extends Thread {
        MyThread(String name) {
            super(name);
        }


        @Override
        public void run() {
            latch.countDown();
            try {
                latch.await();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            int i = 0;
            while (i++ < 6) {
                // “线程名” + "-" + "序号"
                String val = Thread.currentThread().getName() + "-" + i;
                list.add(val);
                // 通过“Iterator”遍历List。
                printAll();
            }
        }
    }
}
```

你可以分别运行以下扇面的代码，调整list的为COW类和ArrayList类，COW不会出错，ArrayList会抛出并发修改异常。

## 5. 使用注意事项

#### CopyOnWrite的应用场景

CopyOnWrite并发容器用于读多写少的并发场景。比如白名单，黑名单，商品类目的访问和更新场景，假如我们有一个搜索网站，用户在这个网站的搜索框中，输入关键字搜索内容，但是某些关键字不允许被搜索。这些不能被搜索的关键字会被放在一个黑名单当中，黑名单每天晚上更新一次。当用户搜索时，会检查当前关键字在不在黑名单当中，如果在，则提示不能搜索。

代码很简单，但是使用CopyOnWriteList需要注意两件事情：

1. 最好顺序添加不要随机添加。

2. 使用批量添加。因为每次添加，容器每次都会进行复制，所以减少添加次数，可以减少容器的复制次数。如使用上面代码里的addAll方法。

#### CopyOnWrite的缺点

CopyOnWrite容器有很多优点，但是同时也存在两个问题，即内存占用问题和数据一致性问题。所以在开发的时候需要注意一下。

1. **内存占用问题**。因为CopyOnWrite的写时复制机制，所以在进行写操作的时候，内存里会同时驻扎两个对象的内存，旧的对象和新写入的对象（注意:在复制的时候只是复制容器里的引用，只是在写的时候会创建新对象添加到新容器里，而旧容器的对象还在使用，所以有两份对象内存）。如果这些对象占用的内存比较大，比如说200M左右，那么再写入100M数据进去，内存就会占用300M，那么这个时候很有可能造成频繁的Yong GC和Full GC。之前我们系统中使用了一个服务由于每晚使用CopyOnWrite机制更新大对象，造成了每晚15秒的Full GC，应用响应时间也随之变长。

   针对内存占用问题，可以通过压缩容器中的元素的方法来减少大对象的内存消耗，比如，如果元素全是10进制的数字，可以考虑把它压缩成36进制或64进制。或者不使用CopyOnWrite容器，而使用其他的并发容器，如[ConcurrentHashMap](https://taolove.top/2019/03/04/juc/collections/ConcurrentHashMap/)。

2. **数据一致性问题**。CopyOnWrite容器只能保证数据的最终一致性，不能保证数据的实时一致性。所以如果你希望写入的的数据，马上能读到，请不要使用CopyOnWrite容器。



## 6. CopyOnWriteArraySet分析

它是线程安全的无序的集合，可以将它理解成线程安全的HashSet。有意思的是，CopyOnWriteArraySet和HashSet虽然都继承于共同的父类AbstractSet；但是，HashSet是通过“散列表(HashMap)”实现的，而CopyOnWriteArraySet则是通过“动态数组(CopyOnWriteArrayList)”实现的，并不是散列表。
和CopyOnWriteArrayList类似，CopyOnWriteArraySet具有以下特性：

1. 它最适合于具有以下特征的应用程序：Set 大小通常保持很小，只读操作远多于可变操作，需要在遍历期间防止线程间的冲突。
2. 它是线程安全的。
3. 因为通常需要复制整个基础数组，所以可变操作（add()、set() 和 remove() 等等）的开销很大。
4. 迭代器支持hasNext(), next()等不可变操作，但不支持可变 remove()等 操作。
5. 使用迭代器进行遍历的速度很快，并且不会与其他线程发生冲突。在构造迭代器时，迭代器依赖于不变的数组快照。

方法都是借助于CopyOnWriteArrayList一样，对外封装了一下，事实上内部都是调用的CopyOnWriteArrayList方法。主要的实现是内部有一个CopyOnWriteArrayList类型的属性，只不过添加的时候需要先检查是否有相同的元素在进行添加。具体源码如下

```java
 // 保存数据的属性
 private final CopyOnWriteArrayList<E> al;
 
public boolean add(E e) {
        return al.addIfAbsent(e);
}

// 下面三个都是CopyOnWriteArrayList的方法，上面没有单拿出来分析，
public boolean addIfAbsent(E e) {
        Object[] snapshot = getArray();
    	// 先判断元素是否存在，如果存在直接返回，否则进行添加
   		// 但是这里是俩个操作，会出现snapshot数组中没有，但是另一个线程
    	// 在查找期间添加一个相同的元素，看看addIfAbsent如何保证安全的
        return indexOf(e, snapshot, 0, snapshot.length) >= 0 ? false :
            addIfAbsent(e, snapshot);
}


// 大致的思想就是，先检查传进来的引用和当前数组引用是否相等
//如果相等，则直接添加，不相等，进行循环判断是否添加进来一个和e相同的
// 元素，如果没有，则添加，如果有，则直接返回false
 private boolean addIfAbsent(E e, Object[] snapshot) {
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            Object[] current = getArray();
            int len = current.length;
            if (snapshot != current) {
                // Optimize for lost race to another addXXX operation
                int common = Math.min(snapshot.length, len);
                for (int i = 0; i < common; i++)
                    if (current[i] != snapshot[i] && eq(e, current[i]))
                        return false;
                if (indexOf(e, current, common, len) >= 0)
                        return false;
            }
            Object[] newElements = Arrays.copyOf(current, len + 1);
            newElements[len] = e;
            setArray(newElements);
            return true;
        } finally {
            lock.unlock();
        }
    }

```



## 参考

1. [聊聊并发-Java中的Copy-On-Write容器](http://ifeve.com/java-copy-on-write/)