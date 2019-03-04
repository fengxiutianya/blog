abbrlink: 26
title: ConcurrentHashMap
tags:
  - java
categories:
  - ju'c
  - 集合
  - map
author: fengxiutianya
date: 2019-03-04 07:24:00
---
# ConcurrentHashMap

### 概述

本篇文章将要介绍的是ConcurrentHashMap，你可以将这个理解为线程安全的HashMap，但是他不是想HashTable一样对所有的方法都是用Synchronize来保证线程安全。至于是如何保证线程安全的，下文会对此进行详细的介绍，也是我们研究的主要点之一。

下文将按照下面几个方面来进行介绍

1. 重要成员属性的介绍
2. put 方法实现并发添加
3. remove方法法实现并发删除
4. get方法的实现
5. 其他的一些方法的简单介绍
6. 使用注意点

<!-- more -->

## 1. 重要成员属性的介绍

```java
transient volatile Node<K,V>[] table;
```

和 HashMap 中的语义一样，是整个哈希表的桶。

```java
/**
* The next table to use; non-null only while resizing.
*/
private transient volatile Node<K,V>[] nextTable;
```

这是一个连接表，用于哈希表扩容，扩容完成后会被重置为 null。换句话说，当这个不为空的时候，也就是表示当前Hash表正在进行扩容

```java
private transient volatile long baseCount;
```

该属性保存着整个哈希表中存储的所有的结点的个数总和，有点类似于 HashMap 的 size 属性。

```java
private transient volatile int sizeCtl;
```

这是一个重要的属性，无论是初始化哈希表，还是扩容 rehash 的过程，都是需要依赖这个关键属性的。该属性有以下几种取值：

- 0：默认值
- -1：代表哈希表正在进行初始化
- 大于0：相当于 HashMap 中的 threshold，表示阈值
- 小于-1：代表有多个线程正在进行扩容

该属性的使用还是有点复杂的，在我们分析扩容源码的时候再给予更加详尽的描述，此处了解其可取的几个值都分别代表着什么样的含义即可。

> 构造函数的实现也和HashMap 的实现类似，主要就是根据给定的参数来设置拉链法中桶的数量，不过有一点需要注意就是，每次只能是2的n次方，其他的就没什么特殊的，贴出源码供大家比较。

```
public ConcurrentHashMap(int initialCapacity) {
    if (initialCapacity < 0)
        throw new IllegalArgumentException();
    int cap = ((initialCapacity >= (MAXIMUM_CAPACITY >>> 1)) ?
               MAXIMUM_CAPACITY :
               tableSizeFor(initialCapacity + (initialCapacity >>> 1) + 1));
    this.sizeCtl = cap;
}
```

##  2. put 方法实现并发添加

下面我们主要来分析下 ConcurrentHashMap 的一个核心方法 put，我们也会一并解决掉该方法中涉及到的扩容、辅助扩容，初始化哈希表等方法。

对于 HashMap 来说，多线程并发添加元素会导致数据丢失等并发问题，那么 ConcurrentHashMap 又是如何做到并发添加的呢？

put操作的源码如下:

```java
public V put(K key, V value) {
    return putVal(key, value, false);
}
```

从上可知，主要是调用了putVal方法，这个也符合面向对象的思想，将公用的方法提出来，封装成内部私有方法来供调用。

`putVal`方法如下，我们先大致看一下流程，具体的后面会解释，这也是看源码的时候一个比较好的方法，先将流程搞懂，然后在深入细节：

```java
/** Implementation for put and putIfAbsent */
final V putVal(K key, V value, boolean onlyIfAbsent) {
    // 判断添加进来的key，value是否为空，
    // ConcurrentHashMap不允许数据为空
    if (key == null || value == null) 
        throw new NullPointerException();
    // 计算key值获取hash值
    int hash = spread(key.hashCode());
    // 当前桶位置对应链表的长度，后面用于判断是否要将链表转换成红黑树
    int binCount = 0;
   
    // 这里比较特别，使用了一个无限循环来操作插入，
    // 主要是因为下面有一个CAS操作，需要一直不断的尝试进行插入
    for (Node<K,V>[] tab = table;;) {
        Node<K,V> f; int n, i, fh;
        // 如果hash表还未初始化，进行初始化
        if (tab == null || (n = tab.length) == 0)
            tab = initTable();
        // 根据hashcode找到对应桶的索引位置，
        // 如果第一个节点没有数据，则以CAS无锁的方式插入第一个节点
        else if ((f = tabAt(tab, i = (n - 1) & hash)) == null) {
            // 无锁插入节点，如果失败，则进入下一次循环
            if (casTabAt(tab, i, null,
                         new Node<K,V>(hash, key, value, null)))
                break;                   // no lock when adding to empty bin
        }
        //检测当前hash正在进行扩容，则帮助扩容
        else if ((fh = f.hash) == MOVED)
            tab = helpTransfer(tab, f);
        else {
            //桶结点是普通的结点，锁住该桶头结点并试图在该链表的尾部添加一个节点
            V oldVal = null;
            // 以hash值对应的索引位置的第一个节点为监视器
            // 对添加操作进行上锁，这不会影响其他索引位置的添加
            synchronized (f) {
                // 类似单例模式中的双重检索写法，判断索引对应的第一个节点是否发生引用变化
                if (tabAt(tab, i) == f) {
                    // 根据节点的hash值来判断，当前是链表还是红黑树
                    // 如果是链表，则第一个节点的hash值是hashcode，
                    // 如果是红黑树，则第一个节点的值是TREEBIN，-2
                    if (fh >= 0) {
                        binCount = 1;
                        for (Node<K,V> e = f;; ++binCount) {
                            K ek;
                            if (e.hash == hash &&
                                ((ek = e.key) == key ||
                                 (ek != null && key.equals(ek)))) {
                                oldVal = e.val;
                                if (!onlyIfAbsent)
                                    e.val = value;
                                break;
                            }
                            Node<K,V> pred = e;
                            if ((e = e.next) == null) {
                                pred.next = new Node<K,V>(hash, key,
                                                          value, null);
                                break;
                            }
                        }
                    }
                    //向红黑树中添加元素，TreeBin 结点的hash值为TREEBIN（-2）
                    else if (f instanceof TreeBin) {
                        Node<K,V> p;
                        binCount = 2;
                        if ((p = ((TreeBin<K,V>)f).putTreeVal(hash, key,
                                                              value)) != null) {
                            oldVal = p.val;
                            if (!onlyIfAbsent)
                                p.val = value;
                        }
                    }
                }
            }
            //binCount != 0 说明向链表或者红黑树中添加或修改一个节点成功
  			//binCount  == 0 说明 put 操作将一个新节点添加成为某个桶的首节点
            if (binCount != 0) {
                //链表深度超过 8 转换为红黑树
                if (binCount >= TREEIFY_THRESHOLD)
                    treeifyBin(tab, i);
                //oldVal != null 说明此次操作是修改操作
         		//直接返回旧值即可，无需做下面的扩容边界检查
                if (oldVal != null)
                    return oldVal;
                break;
            }
        }
    }
    //CAS 无锁方式式更新baseCount，并判断是否需要扩容
    addCount(1L, binCount);
    //程序走到这一步说明此次 put 操作是一个添加操作，否则早就 return 返回了
    return null;
}
```

put 的主流程看完了，但是至少留下了几个问题，分别是初始化table数组，无锁的方式插入table表的第一个节点，帮助迁移，计算key-value键值对的数量，下面分别来说这几个问题：

**initTable**

这是一个初始化哈希表的操作，它同时只允许一个线程进行初始化操作，源码如下

```java
private final Node<K,V>[] initTable() {
        Node<K,V>[] tab; int sc;
    	// 判断当前table是否为空，也就是是否初始化过
    	// 如果初始化过就退出循环
        while ((tab = table) == null || tab.length == 0) {
            
			// 上面我们说过，只要sizeCtl值在不同的阶段会发生变化，
            // 当进行初始化的时候，值为-1
            //这里如果检测到有线程正在进行初始化，则使当前线程放弃cpu，
            // 从而减少竞争，提高初始化速度
            if ((sc = sizeCtl) < 0)
                Thread.yield(); // lost initialization race; just spin
            //使用cas锁，将sizeCtl的值设置为-1，表示有线程正在进行初始化
            else if (U.compareAndSwapInt(this, SIZECTL, sc, -1)) {
                try {
                    // 在一次检测table是否为空，并对table进行初始化
                    if ((tab = table) == null || tab.length == 0) {
                        int n = (sc > 0) ? sc : DEFAULT_CAPACITY;
                        @SuppressWarnings("unchecked")
                        Node<K,V>[] nt = (Node<K,V>[])new Node<?,?>[n];
                        table = tab = nt;
                        // 计算sizeCtl的值，也就是阈值为n的0.75
                        sc = n - (n >>> 2);
                    }
                } finally {
                    // 设置sizeCtl
                    sizeCtl = sc;
                }
                break;
            }
        }
        return tab;
    }
```

关于 initTable 方法的每一步实现都已经给出注释，该方法的核心思想就是，只允许一个线程对表进行初始化，如果不巧有其他线程进来了，那么会让其他线程交出 CPU 等待下次系统调度。这样，保证了表同时只会被一个线程初始化。

**casTabAt**

这个方法是以无锁的方式插入table对应索引位置的第一个节点，源码如下

````java
    static final <K,V> boolean casTabAt(Node<K,V>[] tab, int i,
                                        Node<K,V> c, Node<K,V> v) {
        return U.compareAndSwapObject(tab, ((long)i << ASHIFT) + ABASE, c, v);
    }
````

主要就一行，以CAS方式插入节点，如果插入失败，则表示对应索引位置节点已经有线程插入，因此需要重新插入此节点，就会进入下一次的循环。这里也就保证了只有一个线程来插入节点的第一个位置，也避免了加锁的性能损耗。从而提高性能。

**helpTransfer**

这里首先需要介绍一下，ForwardingNode 这个节点类型，

```java
static final class ForwardingNode<K,V> extends Node<K,V> {
        final Node<K,V>[] nextTable;
        ForwardingNode(Node<K,V>[] tab) {
            //注意这里
            super(MOVED, null, null, null);
            this.nextTable = tab;
        }
    //省略其 find 方法
}
```

这个节点内部保存了一 nextTable 引用，它指向一张 hash 表。在扩容操作中，我们需要对每个桶中的结点进行分离和转移，如果某个桶结点中所有节点都已经迁移完成了（已经被转移到新表 nextTable 中了），那么会在原 table 表的该位置挂上一个 ForwardingNode 结点，说明此桶已经完成迁移。

ForwardingNode 继承自 Node 结点，并且它唯一的构造函数将构建一个键，值，next 都为 null 的结点，反正它就是个标识，无需那些属性。但是 hash 值却为 MOVED。

所以，我们在 putVal 方法中遍历整个 hash 表的桶结点，如果遇到 hash 值等于 MOVED，说明已经有线程正在扩容 rehash 操作，整体上还未完成，不过我们要插入的桶的位置已经完成了所有节点的迁移。

由于检测到当前哈希表正在扩容，于是让当前线程去协助扩容。协助扩容具体源码如下：

```java
final Node<K,V>[] helpTransfer(Node<K,V>[] tab, Node<K,V> f) {
        Node<K,V>[] nextTab; int sc;
        if (tab != null && (f instanceof ForwardingNode) &&
            (nextTab = ((ForwardingNode<K,V>)f).nextTable) != null) {
             //返回一个 16 位长度的扩容校验标识
            int rs = resizeStamp(tab.length);
            while (nextTab == nextTable && table == tab &&
                   (sc = sizeCtl) < 0) {
                //sizeCtl 如果处于扩容状态的话
                //前 16 位是数据校验标识，后 16 位是当前正在扩容的线程总数
                //这里判断校验标识是否相等，如果校验符不等或者扩容操作已经完成了，
                //直接退出循环，不用协助它们扩容了
                if ((sc >>> RESIZE_STAMP_SHIFT) != rs || sc == rs + 1 ||
                    sc == rs + MAX_RESIZERS || transferIndex <= 0)
                    break;
                //否则调用 transfer 帮助它们进行扩容
                //sc + 1 标识增加了一个线程进行扩容
                if (U.compareAndSwapInt(this, SIZECTL, sc, sc + 1)) {
                    transfer(tab, nextTab);
                    break;
                }
            }
            return nextTab;
        }
        return table;
    }
```

下面我们看这个稍显复杂的 transfer 方法，我们依然分几个部分来细说。这里先说一下大概的过程

首先就是将原来的 tab 数组的元素迁移到新的 nextTab 数组中。此方法支持多线程执行，外围调用此方法的时候，会保证第一个发起数据迁移的线程，nextTab 参数为 null，之后再调用此方法的时候，nextTab 不会为 null。

阅读源码之前，先要理解并发操作的机制。原数组长度为 n，所以我们有 n 个迁移任务，让每个线程每次负责一个小任务是最简单的，每做完一个任务再检测是否有其他没做完的任务，帮助迁移就可以了，而 Doug Lea 使用了一个 stride，简单理解就是**步长**，每个线程每次负责迁移其中的一部分，如每次迁移 16 个小任务。所以，我们就需要一个全局的调度者来安排哪个线程执行哪几个任务，这个就是属性 transferIndex 的作用。

第一个发起数据迁移的线程会将 transferIndex 指向原数组最后的位置，然后**从后往前**的 stride 个任务属于第一个线程，然后将 transferIndex 指向新的位置，再往前的 stride 个任务属于第二个线程，依此类推。当然，这里说的第二个线程不是真的一定指代了第二个线程，也可以是同一个线程，这个读者应该能理解吧。其实就是将一个大的迁移任务分为了一个个任务包。

下面看具体源码：

```java
//第一部分
private final void transfer(Node<K,V>[] tab, Node<K,V>[] nextTab) {
        int n = tab.length, stride;
        //计算单个线程允许处理的最少table桶首节点个数，不能小于 16
        if ((stride = (NCPU > 1) ? (n >>> 3) / NCPU : n) < MIN_TRANSFER_STRIDE)
            stride = MIN_TRANSFER_STRIDE; 
        //刚开始扩容，初始化 nextTab ，并设置transferIndex，注意这俩个都是volatile类型的变量
       // 也就是只要其他线程修改了这个变量，那么就会立即让非修改此变量的线程知道
        if (nextTab == null) {
            try {
                @SuppressWarnings("unchecked")
                Node<K,V>[] nt = (Node<K,V>[])new Node<?,?>[n << 1];
                nextTab = nt;
            } catch (Throwable ex) {
                sizeCtl = Integer.MAX_VALUE;
                return;
            }
            nextTable = nextTab;
            //transferIndex 指向最后一个桶，方便从后向前遍历 
            transferIndex = n;
        }
        int nextn = nextTab.length;
        //定义 ForwardingNode 用于标记迁移完成的桶
        ForwardingNode<K,V> fwd = new ForwardingNode<K,V>(nextTab);
```

这部分代码还是比较简单的，主要完成的是对单个线程能处理的最少桶结点个数的计算和一些属性的初始化操作。

```java
//第二部分，并发扩容控制的核心
boolean advance = true; // 这个变量表示当前线程领取的任务已经完成
boolean finishing = false; // 表示所有的迁移工作已经完成
//i 指向当前桶，也就是当前任务节点的上限，bound 指向当前线程需要处理的桶结点的区间下限
for (int i = 0, bound = 0;;) {
       Node<K,V> f; int fh;
       //这个 while 循环的目的就是通过 --i 遍历当前线程所分配到的桶结点
       //一个桶一个桶的处理
       while (advance) {
           int nextIndex, nextBound;
           // 判断当前线程领取的任务是否完成，如果i>=bound表示当前线程领取的任务还没有完成
           // 则结束当前的循环，进入迁移任务
           if (--i >= bound || finishing)
               advance = false;
           //transferIndex <= 0 说明已经没有需要迁移的桶了
           else if ((nextIndex = transferIndex) <= 0) {
               i = -1;
               advance = false;
           }
           //更新 transferIndex
           //为当前线程分配任务，处理的桶结点区间为（nextBound,nextIndex）
           else if (U.compareAndSwapInt(this, TRANSFERINDEX, 
                                     nextIndex,nextBound = (nextIndex > stride ? 
                                                   nextIndex - stride : 0))) {
               bound = nextBound;
               i = nextIndex - 1;
               advance = false;
           }
       }
       //当前线程所有任务完成
       if (i < 0 || i >= n || i + n >= nextn) {
           int sc;
           // 表示迁移任务完成
           if (finishing) {
               nextTable = null;
               table = nextTab;
               sizeCtl = (n << 1) - (n >>> 1);
               return;
           }
           // 检测所有数据是否已经迁移完成，如果是，则设置finishing为true，表示迁移任务完成
           // 否则代表所有的任务已经有线程领取，但是还没有做完，则进行自旋，等待迁移任务完成
           if (U.compareAndSwapInt(this, SIZECTL, sc = sizeCtl, sc - 1)) {
               if ((sc - 2) != resizeStamp(n) << RESIZE_STAMP_SHIFT)
                   return;
               finishing = advance = true;
               i = n; 
           }
       }
       //待迁移桶为空，那么在此位置 CAS 添加 ForwardingNode 结点标识该桶已经被处理过了
       else if ((f = tabAt(tab, i)) == null)
           advance = casTabAt(tab, i, null, fwd);
       //如果扫描到 ForwardingNode，说明此桶已经被处理过了，跳过即可
       else if ((fh = f.hash) == MOVED)
           advance = true; 
```

每个新参加进来扩容的线程必然先进 while 循环的最后一个判断条件中去领取自己需要迁移的桶的区间。然后 i 指向区间的最后一个位置，表示迁移操作从后往前的做。接下来的几个判断就是实际的迁移结点操作了。等我们大致介绍完成第三部分的源码再回来对各个判断条件下的迁移过程进行详细的叙述。

```java
//第三部分
else {
    //对头结点加锁
    synchronized (f) {
        if (tabAt(tab, i) == f) {
            Node<K,V> ln, hn;
            //链表的迁移操作
            if (fh >= 0) {
                int runBit = fh & n;
                Node<K,V> lastRun = f;
                //整个 for 循环为了找到整个桶中最后连续的 fh & n 不变的结点
                for (Node<K,V> p = f.next; p != null; p = p.next) {
                    int b = p.hash & n;
                    if (b != runBit) {
                        runBit = b;
                        lastRun = p;
                    }
                }
                if (runBit == 0) {
                    ln = lastRun;
                    hn = null;
                }
                else {
                    hn = lastRun;
                    ln = null;
                }
                //如果fh&n不变的链表的runbit都是0，则nextTab[i]内元素ln前逆序，ln及其之后顺序
                //否则，nextTab[i+n]内元素全部相对原table逆序
                //这是通过一个节点一个节点的往nextTab添加
                for (Node<K,V> p = f; p != lastRun; p = p.next) {
                    int ph = p.hash; K pk = p.key; V pv = p.val;
                    if ((ph & n) == 0)
                        ln = new Node<K,V>(ph, pk, pv, ln);
                    else
                        hn = new Node<K,V>(ph, pk, pv, hn);
                }
                //把两条链表整体迁移到nextTab中
                setTabAt(nextTab, i, ln);
                setTabAt(nextTab, i + n, hn);
                //将原桶标识位已经处理
                setTabAt(tab, i, fwd);
                advance = true;
            }
            //红黑树的复制算法，不再赘述
            else if (f instanceof TreeBin) {
                TreeBin<K,V> t = (TreeBin<K,V>)f;
                TreeNode<K,V> lo = null, loTail = null;
                TreeNode<K,V> hi = null, hiTail = null;
                int lc = 0, hc = 0;
                for (Node<K,V> e = t.first; e != null; e = e.next) {
                    int h = e.hash;
                    TreeNode<K,V> p = new TreeNode<K,V>(h, e.key, e.val, null, null);
                    if ((h & n) == 0) {
                        if ((p.prev = loTail) == null)
                            lo = p;
                        else
                            loTail.next = p;
                    loTail = p;
                    ++lc;
                    }
                    else {
                        if ((p.prev = hiTail) == null)
                            hi = p;
                        else
                            hiTail.next = p;
                    hiTail = p;
                    ++hc;
                    }
                }
                ln = (lc <= UNTREEIFY_THRESHOLD) ? untreeify(lo) :(hc != 0) ? 
                    	new TreeBin<K,V>(lo) : t;
                hn = (hc <= UNTREEIFY_THRESHOLD) ? untreeify(hi) :(lc != 0) ? 
                    	new TreeBin<K,V>(hi) : t;
                setTabAt(nextTab, i, ln);
                setTabAt(nextTab, i + n, hn);
                setTabAt(tab, i, fwd);
                advance = true;
           }
```

那么至此，有关迁移的几种情况已经介绍完成了，下面我们整体上把控一下整个扩容和迁移过程。

首先，每个线程进来会先领取自己的任务区间，然后开始 `--i `来遍历自己的任务区间，对每个桶进行处理。如果遇到桶的头结点是空的，那么使用 ForwardingNode 标识该桶已经被处理完成了。如果遇到已经处理完成的桶，直接跳过进行下一个桶的处理。如果是正常的桶，对桶首节点加锁，正常的迁移即可，迁移结束后依然会将原表的该位置标识位已经处理。

当 i < 0，说明本线程处理速度够快的，整张表的最后一部分已经被它处理完了，现在需要看看是否还有其他线程在自己的区间段还在迁移中。这是退出的逻辑判断部分：

```java
 //当前线程所有任务完成
if (i < 0 || i >= n || i + n >= nextn) {
    int sc;
    // 表示迁移任务完成
    if (finishing) {
        nextTable = null;
        table = nextTab;
        sizeCtl = (n << 1) - (n >>> 1);
        return;
    }
    // 检测所有数据是否已经迁移完成，如果是，则设置finishing为true，表示迁移任务完成
    // 否则代表所有的任务已经有线程领取，但是还没有做完，则进行自旋，等待迁移任务完成
    if (U.compareAndSwapInt(this, SIZECTL, sc = sizeCtl, sc - 1)) {
        if ((sc - 2) != resizeStamp(n) << RESIZE_STAMP_SHIFT)
            return;
        finishing = advance = true;
        i = n; 
    }
}
```

finnish 是一个标志，如果为 true 则说明整张表的迁移操作已经全部完成了，我们只需要重置 table 的引用并将 nextTable 赋为空即可。否则，CAS 式的将 sizeCtl 减一，表示当前线程已经完成了任务，退出迁移操作。

如果退出成功，那么需要进一步判断是否还有其他线程仍然在执行任务。

```
if ((sc - 2) != resizeStamp(n) << RESIZE_STAMP_SHIFT)
   return;
```

我们说过 resizeStamp(n) 返回的是对 n 的一个数据校验标识，占 16 位。而 RESIZE_STAMP_SHIFT 的值为 16，那么位运算后，整个表达式必然在右边空出 16 个零。也正如我们所说的，sizeCtl 的高 16 位为数据校验标识，低 16 为表示正在进行扩容的线程数量。

(resizeStamp(n) << RESIZE_STAMP_SHIFT) + 2 表示当前只有一个线程正在工作，相对应的，如果 (sc - 2) == resizeStamp(n) << RESIZE_STAMP_SHIFT，说明当前线程就是最后一个还在扩容的线程，那么会将 finishing 标识为 true，并在下一次循环中退出迁移方法。

这一块的难点在于对 sizeCtl 的各个值的理解，关于它的深入理解，这里推荐一篇文章。

[着重理解位操作](http://wuzhaoyang.me/2016/09/05/java-collection-map-2.html)

看到这里，真的为 Doug Lea 精妙的设计而折服，针对于多线程访问问题，不但没有拒绝式得将他们阻塞在门外，反而邀请他们来帮忙一起工作。

好了，我们一路往回走，回到我们最初分析的 putVal 方法。接着前文的分析，当我们根据 hash 值，找到对应的桶结点，如果发现该结点为 ForwardingNode 结点，表明当前的哈希表正在扩容和 rehash，于是将本线程送进去帮忙扩容。否则如果是普通的桶结点，于是锁住该桶，分链表和红黑树的插入一个节点，具体插入过程类似 HashMap，此处不再赘述。

当我们成功的添加完成一个结点，最后是需要判断添加操作后是否会导致哈希表达到它的阈值，并针对不同情况决定是否需要进行扩容，还有 CAS 式更新哈希表实际存储的键值对数量。这些操作都封装在 addCount 这个方法中，当然 putVal 方法的最后必然会调用该方法进行处理。下面我们看看该方法的具体实现，该方法主要做两个事情。一是更新 baseCount，二是判断是否需要扩容。

```java
//第一部分，更新 baseCount
private final void addCount(long x, int check) {
    CounterCell[] as; long b, s;
    //如果更新失败才会进入的 if 的主体代码中
    //s = b + x  其中 x 等于 1
    if ((as = counterCells) != null ||
        !U.compareAndSwapLong(this, BASECOUNT, b = baseCount, s = b + x)) {
        CounterCell a; long v; int m;
        boolean uncontended = true;
        //高并发下 CAS 失败会执行 fullAddCount 方法
        // 具体的操作类似于LongAdder的方式，这里就不具体分析。
        if (as == null || (m = as.length - 1) < 0 || 
            (a = as[ThreadLocalRandom.getProbe() & m]) == null 
            ||!(uncontended =U.compareAndSwapLong(a, CELLVALUE, v = a.value, v + x))) {
            fullAddCount(x, uncontended);
            return;
        }
        if (check <= 1)
            return;
        s = sumCount();
    }
```

这一部分主要完成的是对 baseCount 的 CAS 更新。

```java
//第二部分，判断是否需要扩容
if (check >= 0) {
     Node<K,V>[] tab, nt; int n, sc;
    // 判断当前数据长度是否大于临界值，如果大于，则进行扩容
     while (s >= (long)(sc = sizeCtl) && (tab = table) != null 
            &&(n = tab.length) < MAXIMUM_CAPACITY) {
          int rs = resizeStamp(n);
         // 判断是否已经在扩容
          if (sc < 0) {
              // 如果已经开始扩容，则对设置nt值为nextTable
             if ((sc >>> RESIZE_STAMP_SHIFT) != rs || sc == rs + 1
                 ||sc == rs + MAX_RESIZERS || (nt = nextTable) == null 
                 ||transferIndex <= 0)
              		 break;
             if (U.compareAndSwapInt(this, SIZECTL, sc, sc + 1))
                  transfer(tab, nt);
           // 开始进行扩容，，将sizeCtl设置为一个负值
          }else if (U.compareAndSwapInt(this, SIZECTL, sc,
                                        (rs << RESIZE_STAMP_SHIFT) + 2))
              //扩容开始，nexttable为null
               transfer(tab, null);
               s = sumCount();
        }
}
```

这部分代码大体上还是很清晰的，先将长度进行累加，然后判断长度是否已经尝过阈值，如果超过，则进行扩容，并判断是否已经有线程在扩容，如果是，则帮助扩容，如果没有，则开始扩容。

另外有一个需要注意的点是，在ConcurrentHashMap中将链表转换成红黑树，和HashMap有点不一样，具体转换源码如下：

```java
  private final void treeifyBin(Node<K, V>[] tab, int index) {
        Node<K, V> b;
        int n, sc;
        if (tab != null) {
            // 默认转换为红黑树的table长度为64
            // 所以如果数组长度小于64的时候，进行数组扩容
            if ((n = tab.length) < MIN_TREEIFY_CAPACITY)
                tryPresize(n << 1);
            // 获取头结点
            else if ((b = tabAt(tab, index)) != null && b.hash >= 0) {
                // 锁住头结点
                synchronized (b) {
                    // 再次验证，是否头结点已经被修改了
                    if (tabAt(tab, index) == b) {
                        TreeNode<K, V> hd = null, tl = null;
                        // 遍历链表建立红黑树
                        for (Node<K, V> e = b; e != null; e = e.next) {
                            TreeNode<K, V> p =
                                    new TreeNode<K, V>(e.hash, e.key, e.val,
                                            null, null);
                            if ((p.prev = tl) == null)
                                hd = p;
                            else
                                tl.next = p;
                            tl = p;
                        }
                        // 将红黑树设置到数组的相应位置，这里的头结点就是一个标记，并且不存数据
                        setTabAt(tab, index, new TreeBin<K, V>(hd));
                    }
                }
            }
        }
    }
```

这个方法上面已经大致描述了整个过程，主要**tryPresize**还没有分析，源码如下

```java
 // 首先要说明的是，方法参数 size 传进来的时候就已经翻了倍了
    private final void tryPresize(int size) {
        // c：size 的 1.5 倍，再加 1，再往上取最近的 2 的 n 次方。
        int c = (size >= (MAXIMUM_CAPACITY >>> 1)) ? MAXIMUM_CAPACITY :
                tableSizeFor(size + (size >>> 1) + 1);
        int sc;

        while ((sc = sizeCtl) >= 0) {
            Node<K,V>[] tab = table; int n;
             // 这个 if 分支和之前说的初始化数组的代码基本上是一样的，在这里，我们可以不用管这块代码
            if (tab == null || (n = tab.length) == 0) {
                n = (sc > c) ? sc : c;
                if (U.compareAndSwapInt(this, SIZECTL, sc, -1)) {
                    try {
                        if (table == tab) {
                            @SuppressWarnings("unchecked")
                            Node<K,V>[] nt = (Node<K,V>[])new Node<?,?>[n];
                            table = nt;
                            sc = n - (n >>> 2);
                        }
                    } finally {
                        sizeCtl = sc;
                    }
                }
            }
            // 如果传进来的值不大于sc，也就是已经设置好的一个临界值，则不进行resize
            else if (c <= sc || n >= MAXIMUM_CAPACITY)
                break;
            else if (tab == table) {
                int rs = resizeStamp(n);
                if (sc < 0) {
                    Node<K,V>[] nt;
                    if ((sc >>> RESIZE_STAMP_SHIFT) != rs || sc == rs + 1 ||
                            sc == rs + MAX_RESIZERS || (nt = nextTable) == null ||
                            transferIndex <= 0)
                        break;
                     // CAS 将sizeCTL加1，然后执行transfer方法，此时nextTab不为null
                    if (U.compareAndSwapInt(this, SIZECTL, sc, sc + 1))
                        transfer(tab, nt);
                }
                // 1. 将 sizeCtl 设置为 (rs << RESIZE_STAMP_SHIFT) + 2)
                //    我是没看懂这个值真正的意义是什么？不过可以计算出来的是，结果是一个比较大的负数
                //  调用 transfer 方法，此时 nextTab 参数为 null
                else if (U.compareAndSwapInt(this, SIZECTL, sc,
                        (rs << RESIZE_STAMP_SHIFT) + 2))
                    transfer(tab, null);
            }
        }
    }
```

主要的流程就是先检测table是否已经初始化，如果没有，则初始化，接着进入下一次循环，如果传进来的size长度大于table数组的长度，则对table扩容，碧昂讲述这句进行迁移，这一部分和helpTransfer差不多，就不具体说，可以看前面的。

至此，对于 put 方法的源码分析已经完全结束了，很复杂但也很让人钦佩。

## 3. remove方法法实现并发删除

此方法的实现，和put的实现大致相同，具体源码如下：

```java
final V replaceNode(Object key, V value, Object cv) {
    // 计算hash值
    int hash = spread(key.hashCode());
    // 一直循环，知道删除成功
    for (Node<K,V>[] tab = table;;) {
        Node<K,V> f; int n, i, fh;
        // 如果没有此节点，则直接结束
        if (tab == null || (n = tab.length) == 0 ||
            (f = tabAt(tab, i = (n - 1) & hash)) == null)
            break;
        // 如果正在进行迁移，则帮助迁移
        else if ((fh = f.hash) == MOVED)
            tab = helpTransfer(tab, f);
        else {
            V oldVal = null;
            boolean validated = false;
            // 锁住当前hash对应的索引节点
            synchronized (f) {
                // 重复判断，保证第一个节点的对应的引用没有发生改变
                if (tabAt(tab, i) == f) {
                    // 如果是链表
                    if (fh >= 0) {
                        validated = true;
                        // 循环进行查找对应的节点，并将节点从链表中删除
                        for (Node<K,V> e = f, pred = null;;) {
                            K ek;
                            if (e.hash == hash &&
                                ((ek = e.key) == key ||
                                 (ek != null && key.equals(ek)))) {
                                V ev = e.val;
                                if (cv == null || cv == ev ||
                                    (ev != null && cv.equals(ev))) {
                                    oldVal = ev;
                                    if (value != null)
                                        e.val = value;
                                    else if (pred != null)
                                        pred.next = e.next;
                                    else
                                        setTabAt(tab, i, e.next);
                                }
                                break;
                            }
                            pred = e;
                            if ((e = e.next) == null)
                                break;
                        }
                    }
                    // 如果是红黑树，
                    else if (f instanceof TreeBin) {
                        validated = true;
                        TreeBin<K,V> t = (TreeBin<K,V>)f;
                        TreeNode<K,V> r, p;
                        if ((r = t.root) != null &&
                            (p = r.findTreeNode(hash, key, null)) != null) {
                            V pv = p.val;
                            if (cv == null || cv == pv ||
                                (pv != null && cv.equals(pv))) {
                                oldVal = pv;
                                if (value != null)
                                    p.val = value;
                                else if (t.removeTreeNode(p))
                                    setTabAt(tab, i, untreeify(t.first));
                            }
                        }
                    }
                }
            }
            // 判断是否删除成功，如果是，则将数据的长度减1
            if (validated) {
                if (oldVal != null) {
                    if (value == null)
                        addCount(-1L, -1);
                    return oldVal;
                }
                break;
            }
        }
    }
    return null;
}
```

在我们分析完 put 方法的源码之后，相信 remove 方法对你而言就比较轻松了，无非就是先定位再删除的复合。首先遍历整张表的桶结点，如果表还未初始化或者无法根据参数的 hash 值定位到桶结点，那么将返回 null。如果定位到的桶结点类型是 ForwardingNode 结点，调用 helpTransfer 协助扩容。否则就老老实实的给桶加锁，删除一个节点。最后会调用 addCount 方法 CAS 更新 baseCount 的值。

扩容的过程：

- 确定步长，多线程复制过程中防止出现混乱。每个线程分配步长长度的hash桶长度。最低不少于16。
- 初始化nexttab。保证单线程执行，nexttab只存在于resize阶段，可以看作是临时表。
- 构造Forword节点，以标志扩容完成的Hash桶。
- 执行死循环
  - 分配线程处理hash桶的bound
  - 从n－1到bound，倒序遍历hash桶
  - 如果桶节点为空，CAS为Forword节点，表明处理完成
  - 如果桶节点为Forword，则跳过
  - 锁定桶节点，执行复制操作。在复制到nexttab的过程中，未破坏原tab的链表顺序和结构，所以不影响原tab的检索。
  - 复制完成，设置桶节点为Forword
  - 所有线程完成任务，则扩容结束，nexttab赋值给tab，nexttab置为空，sizeCtl置为原tab长度的1.5倍（见注释）

如何保证nextTab的初始化由单线程执行？
所有调用`transfer`的方法（例如`helperTransfer`、`addCount`)几乎都预先判断了`nextTab!=null`,而nextTab只会在`transfer`方法中初始化，保证了第一个进来的线程初始化之后其他线程才能进入。

## 4. get方法的实现

```java
//不用担心get的过程中发生resize，get可能遇到两种情况
//1.桶未resize（无论是没达到阈值还是resize已经开始但是还未处理该桶），遍历链表
//2.在桶的链表遍历的过程中resize，上面的resize分析可以看出并未破坏原tab的桶的节点关系，遍历仍可以继续
public V get(Object key) {
    Node<K,V>[] tab; Node<K,V> e, p; int n, eh; K ek;
    int h = spread(key.hashCode());
    if ((tab = table) != null && (n = tab.length) > 0 &&
        (e = tabAt(tab, (n - 1) & h)) != null) {
        if ((eh = e.hash) == h) {
            if ((ek = e.key) == key || (ek != null && key.equals(ek)))
                return e.val;
        }
        else if (eh < 0)
            return (p = e.find(h, key)) != null ? p.val : null;
        while ((e = e.next) != null) {
            if (e.hash == h &&
                ((ek = e.key) == key || (ek != null && key.equals(ek))))
                return e.val;
        }
    }
    return null;
}
```

说明：有了上面的基础，`get`方法看起来就很简单了。

1. 在没有遇到forword节点时，遍历原tab。上面也说了，即使正在扩容也不影响没有处理或者正在处理的桶链表遍历，因为它没有破坏原tab的链表关系，这个可以看上面的复制过程，主要是将key-value数据进行复制，并不是进行节点的指针改动，因此可以说是用空间来换时间。
2. 遇到forword节点，遍历nextTab（通过调用forword节点的`find`方法

##  5. 其他的一些方法的简单介绍

**1size**
size 方法的作用是为我们返回哈希表中实际存在的键值对的总数。

```
public int size() {
    long n = sumCount();
    return ((n < 0L) ? 0 :(n > (long)Integer.MAX_VALUE) ? Integer.MAX_VALUE :(int)n);
}
final long sumCount() {
    CounterCell[] as = counterCells; CounterCell a;
    long sum = baseCount;
    if (as != null) {
        for (int i = 0; i < as.length; ++i) {
            if ((a = as[i]) != null)
                sum += a.value;
        }
    }
    return sum;
}
```

可能你会有所疑问，ConcurrentHashMap 中的 baseCount 属性不就是记录的所有键值对的总数吗？直接返回它不就行了吗？

之所以没有这么做，是因为我们的 addCount 方法用于 CAS 更新 baseCount，但很有可能在高并发的情况下，更新失败，那么这些节点虽然已经被添加到哈希表中了，但是数量却没有被统计。

还好，addCount 方法在更新 baseCount 失败的时候，会调用 fullAddCount 将这些失败的结点包装成一个 CounterCell 对象，保存在 CounterCell 数组中。那么整张表实际的 size 其实是 baseCount 加上 CounterCell 数组中元素的个数，具体的过程和LongAdder差不多。

**2. clear**
clear 方法将删除整张哈希表中所有的键值对，删除操作也是一个桶一个桶的进行删除。

```java
public void clear() {
    long delta = 0L; // negative number of deletions
    int i = 0;
    Node<K,V>[] tab = table;
    while (tab != null && i < tab.length) {
        int fh;
        Node<K,V> f = tabAt(tab, i);
        if (f == null)
            ++i;
        else if ((fh = f.hash) == MOVED) {
            tab = helpTransfer(tab, f);
            i = 0; // restart
        }
        else {
            synchronized (f) {
                if (tabAt(tab, i) == f) {
                    Node<K,V> p = (fh >= 0 ? f :(f instanceof TreeBin) ?((TreeBin<K,V>)f).first : null);
                        //循环到链表或者红黑树的尾部
                        while (p != null) {
                            --delta;
                            p = p.next;
                        }
                        //首先删除链、树的末尾元素，避免产生大量垃圾  
                        //利用CAS无锁置null  
                        setTabAt(tab, i++, null);
                    }
                }
            }
        }
        if (delta != 0L)
            addCount(delta, -1);
    }
```

## 6. 使用注意点

1. **什么时候使用ConcurrentHashMap**

   CHM适用于读者数量超过写者时，当写者数量大于等于读者时，CHM的性能是低于Hashtable和synchronized Map的。这是因为当锁住了整个Map时，读操作要等待对同一部分执行写操作的线程结束。CHM适用于做cache,在程序启动时初始化，之后可以被多个请求线程访问。正如Javadoc说明的那样，CHM是HashTable一个很好的替代，但要记住，CHM的比HashTable的同步性稍弱。

2. 迭代器的使用

   Iterator对象的使用，不一定是和其它更新线程同步，获得的对象可能是更新前的对象，ConcurrentHashMap允许一边更新、一边遍历，也就是说在Iterator对象遍历的时候，ConcurrentHashMap也可以进行remove,put操作，且遍历的数据会随着remove,put操作产出变化，所以希望遍历到当前全部数据的话，要么以ConcurrentHashMap变量为锁进行同步(synchronized该变量)，要么使用CopiedIterator包装iterator，使其拷贝当前集合的全部数据，但是这样生成的iterator不可以进行remove操作。

3. key-value不允许为空

   这个只要是线程安全的HashMap都会这样要求，因为获取到



## 参考

1. [为并发而生的 ConcurrentHashMap（Java 8）](https://www.cnblogs.com/yangming1996/p/8031199.html)
2. [如何在java中使用ConcurrentHashMap](http://www.importnew.com/21388.html)
3. [[ConcurrentHashMap使用要点](https://www.cnblogs.com/zhuawang/p/4779649.html)](https://www.cnblogs.com/zhuawang/p/4779649.html)
4. [java8集合框架(三)－Map的实现类（ConcurrentHashMap）](http://wuzhaoyang.me/2016/09/05/java-collection-map-2.html)
5. [Java7/8 中的 HashMap 和 ConcurrentHashMap 全解析](https://javadoop.com/post/hashmap#Java7%20ConcurrentHashMap)