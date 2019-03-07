abbrlink: 2
title: Fail-fast
date: 2019-03-04 08:18:21
---
### 概要

前面已经讲解了Arraylist，但是留下了一个知识点没有说明，Iterator的fail-fast机制。本篇博客主要讲解一下这个机制。

主要内容：

1. Fail-fast简介
2. fail-fast示例
3. fail-fast解决办法
4. fail-fast原理
5. 解决fail-fast的原理

<!-- more  -->

### 1. Fail-fast简介

下面是Java官方在Arraylist的介绍中一段描述fail-fast的话

> if the list is structurally modified at any time after the iterator is created, in any way except through the iterator's own remove or add methods, the iterator will throw a ConcurrentModificationException. Thus, in the face of concurrent modification, the iterator fails quickly and cleanly, rather than risking arbitrary, non-deterministic behavior at an undetermined time in the future.

大概的意思就是说：当通过list返回一个Iterator或者ListIterator对象之后，除了Iterator和ListIterator对象自己对集合的修改之外的其他任何修改集合的行为，都会报ConcurrentModificationException。因此在面对并发修改时，迭代器会快速而干净的失败，也就是不对List对象的状态有任何的修改，同时不会再未来某个不确定的时间产生任意的风险和不确定的行为。

用下面通俗的话来说就是：

**fail-fast 机制是java集合(Collection)中的一种错误机制。**当多个线程对同一个集合的内容进行操作时，就可能会产生fail-fast事件。
例如：当某一个线程A通过iterator去遍历某集合的过程中，若该集合的内容被其他线程所改变了；那么线程A访问集合时，就会抛出ConcurrentModificationException异常，产生fail-fast事件。

### 2. Fail-fast示例

>```java
>/**
> * java集合中Fast-Fail的测试程序。
> * 
> * fast-fail事件产生的条件：
> * 当多个线程对Collection进行操作时，若其中某一个线程通过iterator去遍历集合时，
> * 该集合的内容被其他线程所改变；则会抛出ConcurrentModificationException异常。
> * fast-fail解决办法：通过util.concurrent集合包下的相应类去处理，则不会产生fast-fail事件。
> *
> * 本例中，分别测试ArrayList和CopyOnWriteArrayList这两种情况。
> * ArrayList会产生fast-fail事件，而CopyOnWriteArrayList不会产生fast-fail事件。
> * 
> * 1.  使用ArrayList时，会产生fast-fail事件，抛出ConcurrentModificationException异常；
> * 定义如下：
> * private static List<String> list = new ArrayList<String>();
> * 2.  使用时CopyOnWriteArrayList，不会产生fast-fail事件；
> * 定义如下：
> * private static List<String> list = new CopyOnWriteArrayList<String>();
> */
>public class FailFastTest {
>
>    private static List<String> list = new ArrayList<>();
>
>    public static void main(String[] args) {
>
>        // 启动两个线程对list进行操作！
>        new ThreadOne().start();
>        new ThreadTwo().start();
>    }
>
>    public static void printAll() {
>        System.out.println(Thread.currentThread().getName());
>        Iterator iterator = list.iterator();
>        while (iterator.hasNext()) {
>            System.out.println(iterator.next());
>        }
>    }
>
>    /**
>     * 向list中依次添加0,1,2,3,4,5，每添加一个数之后，就通过printAll()遍历整个list
>     */
>    private static class ThreadOne extends Thread {
>        public void run() {
>            int i = 0;
>            while (i < 6) {
>                list.add(String.valueOf(i));
>                printAll();
>                i++;
>            }
>        }
>    }
>
>    /**
>     * 向list中依次添加10,11,12,13,14,15，每添加一个数之后，就通过printAll()遍历整个list
>     */
>    private static class ThreadTwo extends Thread {
>        public void run() {
>            int i = 10;
>            while (i < 16) {
>                list.add(String.valueOf(i));
>                printAll();
>                i++;
>            }
>        }
>    }
>}
>
>```
>
>运行上面代码，会抛出异常：java.util.ConcurrentModificationException！即，产生fail-fast事件！
>
>**结果说明**：
>FastFailTest中通过 new ThreadOne().start() 和 new ThreadTwo().start() 同时启动两个线程去操作list。
> **ThreadOne线程**：向list中依次添加0,1,2,3,4,5。每添加一个数之后，就通过printAll()遍历整个list。
> **ThreadTwo线程**：向list中依次添加10,11,12,13,14,15。每添加一个数之后，就通过printAll()遍历整个list。
>
> 当某一个线程遍历list的过程中，list的内容被另外一个线程所改变了；就会抛出ConcurrentModificationException异常，产生fail-fast事件。
>
>

### 3. Fail-fast的解决办法

>fail-fast机制，使用错误检测机制。他只能被用来检测错误，因为JDK并不会保证fail-fast机制一定会发生。若在多线程环境下使用fail-fast机制集合，建议使用线程安全的集合类，类如“java.util.concurrent包下的类”去取代“java.util包下的类”。如果你的代码水平不是太高还是不要自己去用synchronize或者lock等机制来实现线程安全。同时java.util.concurent包下面的代码运行效率还是挺高的。
>
>上面的那段代码就可以用下面的方式来解决,
>
>```
>private static List<String> list = new ArrayList<String>();
>```
>
>替换为
>
>```
>private static List<String> list = new CopyOnWriteArrayList<String>();
>```

### 4. Fail-fast原理

>产生fail-fast事件，是通过抛出ConcurrentModificationException异常来触发的。那么，ArrayList是如何抛出ConcurrentModificationException异常的呢?
>
>在前一篇博客里面我们已经分析了ArrayList的源码。下面是摘录
>
>```java
> //实现list通用的迭代器
>    private class Itr implements Iterator<E> {
>        int cursor; //当前迭代器指向的位置
>        int lastRet; //指向next操作的前一个元素
>        int expectedModCount; //当前list的大小
>
>        private Itr() {
>            this.cursor = 0; //开始的位置
>            this.lastRet = -1; //没有开始进行迭代操作
>            this.expectedModCount = AbstractList.this.modCount; //外部类设置list的长度
>        }
>
>        //利用当前指向的游标和外部类list的大小来判断是否还有下一个元素
>        public boolean hasNext() {
>            return this.cursor != AbstractList.this.size();
>        }
>
>        //返回元素
>        public E next() {
>            //首先利用fail-fast来检测list是否改变，
>            this.checkForComodification();
>
>            try {
>                int var1 = this.cursor;
>                Object var2 = AbstractList.this.get(var1);
>                this.lastRet = var1;
>                this.cursor = var1 + 1;
>                return var2;
>            } catch (IndexOutOfBoundsException var3) { //捕获超出边界异常
>  				 //判断是否是当前list被并发修改，如果是，则抛出此异常
>                this.checkForComodification(); 
>           
>                throw new NoSuchElementException(); //正常抛出异常
>            }
>        }
>
>        //实现Iterator 接口 的remove方法
>        public void remove() {
>            if (this.lastRet < 0) {
>                throw new IllegalStateException();
>            } else {
>                this.checkForComodification();
>
>                try {
>                    AbstractList.this.remove(this.lastRet);
>                    if (this.lastRet < this.cursor) { //当期那游标减1
>                        --this.cursor;
>                    }
>
>                    this.lastRet = -1;
> 						//重新设置list的大小
>                    this.expectedModCount = AbstractList.this.modCount;
>                } catch (IndexOutOfBoundsException var2) {
>                    throw new ConcurrentModificationException();
>                }
>            }
>        }
>
>        // 判断list是否已经修改，
>        // 如果修改则抛出并发修改错误
>        final void checkForComodification() {
>            if (AbstractList.this.modCount != this.expectedModCount) {
>                throw new ConcurrentModificationException();
>            }
>        }
>    }
>```
>
>从中，我们可以发现在调用 next() 和 remove()时，都会执行 checkForComodification()。若 “**modCount 不等于 expectedModCount**”，则抛出ConcurrentModificationException异常，产生fail-fast事件。
>
>要搞明白 fail-fast机制，我们就要需要理解什么时候“modCount 不等于 expectedModCount”！从Itr类中，我们知道 expectedModCount 在创建Itr对象时，被赋值为 modCount。通过Itr，我们知道：expectedModCount不可能被修改为不等于 modCount。所以，需要考证的就是modCount何时会被修改。
>
>上一篇博客里面分析ArrayList源码时，里面只要涉及到修改ArrayList的地点，都会对modCount加1，这些修改包括add(),remove(),clear()等等。
>
>接下来，我们再系统的梳理一下fail-fast是怎么产生的。步骤如下：
>(01) *新建了一个ArrayList，名称为arrayList。*
>(02) *向arrayList中添加内容。*
>(03)新建一个“**线程a**，并在“线程a”中**通过Iterator反复的读取arrayList的值**
>(04) 新建一个**线程b**，在“线程b”中**删除arrayList中的一个节点A**
>(05) 这时，就会产生有趣的事件了。  在某一时刻，“线程a”创建了arrayList的Iterator。此时“节点A”仍然存在于arrayList中，**创建arrayList时，expectedModCount = modCount**(假设它们此时的值为N)。在“线程a”在遍历arrayList过程中的某一时刻，“线程b”执行了，并且“线程b”删除了arrayList中的“节点A”。“线程b”执行remove()进行删除操作时，在remove()中执行了“modCount++”，此时**modCount变成了N+1**！“线程a”接着遍历，当它执行到next()函数时，调用checkForComodification()比较“expectedModCount”和“modCount”的大小；而“expectedModCount=N”，“modCount=N+1”,这样，便抛出ConcurrentModificationException异常，产生fail-fast事件。
>
>至此，**我们就完全了解了fail-fast是如何产生的！**
>即，当多个线程对同一个集合进行操作的时候，某线程访问集合的过程中，该集合的内容被其他线程所改变(即其它线程通过add、remove、clear等方法，改变了modCount的值)；这时，就会抛出ConcurrentModificationException异常，产生fail-fast事件。
>
>

### 5. 解决fail-fast的原理

抛出这种错误的原因是因为出现并发操作，主要由以下俩种方式来解决

1. 我们可以使用`Collections.synchronizedList`包装一下Arraylist，对每个方法都是用Synchronize进行同步
2. 使用JUC中线程安全的集合类，类如`CopyOnWriteList`来替代ArrayList

