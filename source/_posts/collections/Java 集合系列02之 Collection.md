abbrlink: 1
title: java集合系列 02 Collection
date: 2019-03-04 08:19:27
---
# java集合系列 02 Collection

## 概要

首先，对Collection进行说明。下面是Collection的继承关系的主要类图，（这里只列举了抽象类和接口，来说明Collection的整体结构）

![collection 整体架构](/images/pasted-155.png)

Collection是一个接口，它主要的俩个分支是：**List** 和**Set**。

**List**和**Set**都是接口，他们继承于Collection。

List是有序队列，这里所说的有序队列是指，按照什么顺序添加，可以以相同的顺序取出来，List中可以有相同的元素。

Set可以和数学概念中的集合类比，Set中不允许有重复的元素。

由上面的类图可以看出，首先抽象出了一个AbstractCollection抽象类，实现了Collection接口中的大部分方法，方便后面代码的编写。接着AbstractList 和 AbstractSet继承了AbstractCollection。其中AbstraList实现了List中特有的一写方法，AbstractSet实现了对于Set来说通用的一些方法。这样做可以方便子类的编写。这很好的体现了面向对象的思想。

另外要说明的一点是，Collection继承了Iterator接口，所以每一个实现了Collection接口的类中，都可以使用迭代器遍历。List系列的集合实现了一个特有的ListIterator接口，在这个接口中增加了一些添加，删除等方法。

通过上面的介绍可以发现，Collection体系中的集合并不是特别的复杂，所以只要细心的理一下，还是很容易理解和使用的。java 8新增加了default方法，还有流（Stream），因为我们关注的是集合的使用，因此在这里就省略这部分内容。后面我会专门写一系列的博客来讲解java8中的流。

<!--more -->

## 主要内容

1. Collection 简介

2. List 简介

3. Set 简介

4. AbstractCollection 源码分析

5. AbstractList    源码分析 

6. AbstractSet    源码分析

7. ListIterator

   注：Iterator 请看我的另一篇博客[Iterator 和 iterable 区别](http://blog.csdn.net/u014569188/article/details/78881952)

### 1. Collection 简介

Collection 定义如下

```java
public interface Collection<E> extends Iterable<E>{}
```

本身是一个接口，高度抽象出来集合，它包含了集合的基本操作：添加、删除、清空、遍历、是否为空、获取大小、是否保护某元素等等。

在Java API规定，所有实现Collection接口的子类（直接子类和间接子类）都必须实现俩种构造参数：不带参数的构造参数（为了创建出一个空的集合类）和带参数的构造参数（用参数创建出一个新的集合类，也就是可以转换集合类）。

```java
//Collection 接口
public abstract boolean add(E e)  //添加元素
public abstract boolean add(Collection<? extend E> c) //添加集合
public abstract void clear()   //清空集合
public abstract boolean contains(Object o) //判断集合是否包含此元素
public abstract boolean containsAll(Collection<?> c)
  								//判断集合中是否包含参数集合中所有的元素
public abstract boolean  equals(Object object)  //比较俩个是否相同
public abstract int     hashCode()   //返回hash值
public abstract boolean         isEmpty()    //是否为空
public abstract Iterator<E>     iterator()   //返回迭代器
public abstract boolean remove(Object object)  //删除某个元素
public abstract boolean removeAll(Collection<?> collection)  //删除参数中的元素		
public abstract boolean retainAll(Collection?> collection)  //保留参数集合中元素
public abstract int             size()  //返回集合的大小
public abstract <T> T[]         toArray(T[] array) //返回T类型的数组
public abstract Object[]        toArray()  //返回包含集合所有元素的集，是Object类型
```

### 2. List 简介

List 定义如下：

```
public interface List<E> extends Collection<E> {}
```

List 是一个继承了Collection的接口，是集合的一种，是一个有序集合。List中的每一个集合都有一个索引，第一个元素的索引是0，往后的元素一次加1，List中允许有重复的元素

关于API方面。既然List是继承于Collection接口，它自然就包含了Collection中的全部函数接口；由于List是有序队列，它也额外的有自己的API接口。主要有“添加、删除、获取、修改指定位置的元素”、“获取List中的子队列”等。

```java
// 相比与Collection，List新增的API：
abstract void                add(int location, E object) //在指定的位置增加元素
  								//在指定的位置开始增加元素
abstract boolean             addAll(int location, Collection<? extends E> c)
abstract E                   get(int location) //得到指定位置的元素
abstract int                 indexOf(Object object)  //返回第一个出现出现元素的索引
abstract int                 lastIndexOf(Object object) //返回最后一个出现出现元素的索引
abstract ListIterator<E>     listIterator(int location)  //从location位置开始返回
abstract ListIterator<E>     listIterator()//返回listIterator对象
abstract E                   remove(int location)
abstract E                   set(int location, E object) //替换某个位置的元素
abstract List<E>             subList(int start, int end) //返回当前List的子集
```

### 3. Set 简介

Set的定义如下：

```java
public interface Set<E> extends Collection<E> {}
```

Set是一个继承与Collection的接口，也是集合中的一种。Set是不允许有重复元素的集合

在API上，和Collection完全一样

### 4. AbstractCollection

AbstractCollection 定义如下：

```Java
public abstract class AbstractCollection<E> implements Collection<E> {}
```

AbstractCollection 是一个抽象类，他实现了Collection中除Iterator()和size()之外的函数

AbstractCollection的主要作用：它实现了Collection接口中的大部分函数。从而方便其它类实现Collection，比如ArrayList、LinkedList等，它们这些类想要实现Collection接口，通过继承AbstractCollection就已经实现了大部分的接口了。

另外在集合中，很多的操作都是依赖于迭代器。而不同类型的集合迭代器的实现方式可能不同，因此实现迭代器一般都会放在子类中实现。

```Java
//对AbstractCollection的源码分析
package java.util;
public abstract class AbstractCollection<E> implements Collection<E> {

    protected AbstractCollection() {
      
    }

    // 查询操作

    //有collection的子类有不同的种类
    //因此不同种类的迭代器可能不相同，这里就没有实现
    public abstract Iterator<E> iterator();

    //返回当前集合的大小
    public abstract int size();

    //判断当前集合是否为空，
    //只要size等于0说明没有元素
    public boolean isEmpty() {
        return size() == 0;
    }

    //由于每个集合都有迭代器，
    //因此可以通过迭代器进行遍历，
    //然后判断指定元素是否存在
    public boolean contains(Object o) {
        Iterator<E> it = iterator();
        if (o == null) {
            while (it.hasNext())
                if (it.next() == null)
                    return true;
        } else {
            while (it.hasNext())
                if (o.equals(it.next()))
                    return true;
        }
        return false;
    }

    //返回object类型的数组，
    public Object[] toArray() {
        // 先得到一个预期的集合大小，为了防止在遍历是有其他线程修改了集合
        Object[] r = new Object[size()];
        Iterator<E> it = iterator();
        for (int i = 0; i < r.length; i++) {
            if (!it.hasNext()) // 少于预期的集合大小，返回一个和新的集合大小相同数组
                return Arrays.copyOf(r, i);
            r[i] = it.next();
        }
        //如果预期的大小小于集合的size，则利用finishToArray返回这个集合最终转换的数组
        return it.hasNext() ? finishToArray(r, it) : r;
    }

    //返回指定指定类型的数组，不是object类型的
    @SuppressWarnings("unchecked")
    public <T> T[] toArray(T[] a) {
        // 先得到一个预期的集合大小，为了防止在遍历是有其他线程修改了集合
        int size = size();
        //通过反射创建指定类型的数组
        T[] r = a.length >= size ? a : (T[]) java.lang.reflect.Array.newInstance(a.getClass().getComponentType(), size);
        Iterator<E> it = iterator();

        for (int i = 0; i < r.length; i++) {
            if (!it.hasNext()) { // 少于预期的大小
                if (a == r) {
                    r[i] = null; // null-terminate
                } else if (a.length < i) {
                    return Arrays.copyOf(r, i);
                } else {
                    System.arraycopy(r, 0, a, 0, i);
                    if (a.length > i) {
                        a[i] = null;
                    }
                }
                return a;
            }
            r[i] = (T) it.next();
        }
        // 超过预期的集合大小
        return it.hasNext() ? finishToArray(r, it) : r;
    }

    //数组的最大长度，有虚拟机内部会在array头部存储一些信息，
    //因此最大长度没有达到Integer的最大值
    private static final int MAX_ARRAY_SIZE = Integer.MAX_VALUE - 8;

    //当在进行toArray操作时，集合大小发生改变，
    //则会使用下面的操作，重新分配数组的大小，并进行拷贝
    @SuppressWarnings("unchecked")
    private static <T> T[] finishToArray(T[] r, Iterator<?> it) {
        int i = r.length;
        while (it.hasNext()) {
            int cap = r.length;
            if (i == cap) {
                int newCap = cap + (cap >> 1) + 1;
                // overflow-conscious code
                if (newCap - MAX_ARRAY_SIZE > 0)
                    newCap = hugeCapacity(cap + 1);
                r = Arrays.copyOf(r, newCap);
            }
            r[i++] = (T) it.next();
        }
        // 如果数组的实际长度和当前数组的长度不相等，则缩短当前数组的长度
        return (i == r.length) ? r : Arrays.copyOf(r, i);
    }

    private static int hugeCapacity(int minCapacity) {
        if (minCapacity < 0) // overflow
            throw new OutOfMemoryError("Required array size too large");
        return (minCapacity > MAX_ARRAY_SIZE) ? Integer.MAX_VALUE : MAX_ARRAY_SIZE;
    }

    // 修改集合操作

    // 添加操作
    public boolean add(E e) {
        throw new UnsupportedOperationException();
    }

    //通过迭代器移除和当前对象所匹配的元素
    //只会移除1个
    public boolean remove(Object o) {
        Iterator<E> it = iterator();
        if (o == null) {
            while (it.hasNext()) {
                if (it.next() == null) {
                    it.remove();
                    return true;
                }
            }
        } else {
            while (it.hasNext()) {
                if (o.equals(it.next())) {
                    it.remove();
                    return true;
                }
            }
        }
        return false;
    }

    // 批量操作

    // 判断给定的集合是否在当前collection中都存在
    public boolean containsAll(Collection<?> c) {
        for (Object e : c)
            if (!contains(e))
                return false;
        return true;
    }

    //添加集合
    public boolean addAll(Collection<? extends E> c) {
        boolean modified = false;
        for (E e : c)
            if (add(e))
                modified = true;
        return modified;
    }

    //删除当前集合中和参数给定集合匹配的元素
    public boolean removeAll(Collection<?> c) {
        Objects.requireNonNull(c);
        boolean modified = false;
        Iterator<?> it = iterator();
        while (it.hasNext()) {
            if (c.contains(it.next())) {
                it.remove();
                modified = true;
            }
        }
        return modified;
    }

    //保留当前集合中和参数给定集合匹配的元素
    public boolean retainAll(Collection<?> c) {
        Objects.requireNonNull(c);
        boolean modified = false;
        Iterator<E> it = iterator();
        while (it.hasNext()) {
            if (!c.contains(it.next())) {
                it.remove();
                modified = true;
            }
        }
        return modified;
    }

    //清空元素，利用迭代器里面的remove
    //如果没有实现这个方法
    //则抛出不支持该操作异常
    public void clear() {
        Iterator<E> it = iterator();
        while (it.hasNext()) {
            it.next();
            it.remove();
        }
    }

    //  返回当前collection元素组成的string
    public String toString() {
        Iterator<E> it = iterator();
        if (!it.hasNext())
            return "[]";

        StringBuilder sb = new StringBuilder();
        sb.append('[');
        for (;;) {
            E e = it.next();
            sb.append(e == this ? "(this Collection)" : e);
            if (!it.hasNext())
                return sb.append(']').toString();
            sb.append(',').append(' ');
        }
    }
}
```

### 5. AbstractList

AbstractList的定义如下：

```Java
public abstract class AbstractList<E> extends AbstractCollection<E> implements List<E> {}
```

AbstractList是一个继承于AbstractCollection，并且实现List接口的抽象类。

AbstractList的主要作用：它实现了List接口中的大部分函数。从而方便其它集合类继承List。

另外，和AbstractCollection相比，AbstractList抽象类中，实现了iterator()接口。

有以下的方法没有实现

```
1. public abstract E get(int var1)
2. public E set(int var1, E var2)
3. public void add(int var1, E var2)
4. public E remove(int var1)
```



```Java
package java.util;
public abstract class AbstractList<E> 
			extends AbstractCollection<E> implements List<E> {

    //当前list的修改操作次数，用于fail-fast决策
    protected transient int modCount = 0;

    protected AbstractList() {
    }

    //在末尾增加元素
    public boolean add(E var1) {
        this.add(this.size(), var1);
        return true;
    }

    //得到指定位置的元素 
    //需要子类实现
    public abstract E get(int var1);

    //替换指定位置的元素
    //如果未实现则抛出不支持操作异常
    public E set(int var1, E var2) {
        throw new UnsupportedOperationException();
    }

    //在指定位置增加元素
    //如果未实现则抛出不支持操作
    public void add(int var1, E var2) {
        throw new UnsupportedOperationException();
    }

    //移除指定位置元素
    //如果未实现，则抛出不支持操作
    public E remove(int var1) {
        throw new UnsupportedOperationException();
    }

    //搜索操作

    //利用listIterator来搜索指定元素
    //包含null类型的元素 
    //搜索不到返回 -1
    //如果有，返回第一个匹配元素的索引
    public int indexOf(Object var1) {
        ListIterator var2 = this.listIterator();
        if (var1 == null) {
            while (var2.hasNext()) {
                if (var2.next() == null) {
                    return var2.previousIndex();
                }
            }
        } else {
            while (var2.hasNext()) {
                if (var1.equals(var2.next())) {
                    return var2.previousIndex();
                }
            }
        }

        return -1;
    }

    //利用listIterator来搜索指定元素
    //包含null类型的元素 
    //搜索不到返回 -1
    //如果有，返回最后一个匹配元素的索引
    public int lastIndexOf(Object var1) {
        ListIterator var2 = this.listIterator(this.size());
        if (var1 == null) {
            while (var2.hasPrevious()) {
                if (var2.previous() == null) {
                    return var2.nextIndex();
                }
            }
        } else {
            while (var2.hasPrevious()) {
                if (var1.equals(var2.previous())) {
                    return var2.nextIndex();
                }
            }
        }

        return -1;
    }

    //清空元素
    public void clear() {
        this.removeRange(0, this.size());
    }

    //在指定位置之后添加集合
    public boolean addAll(int var1, Collection<? extends E> var2) {
        this.rangeCheckForAdd(var1);
        boolean var3 = false;

        for (Iterator var4 = var2.iterator(); var4.hasNext(); var3 = true) {
            Object var5 = var4.next();
            this.add(var1++, var5);
        }

        return var3;
    }

    //得到迭代器
    public Iterator<E> iterator() {
        return new AbstractList.Itr();
    }

    //得到list特有的ListIterator迭代器
    public ListIterator<E> listIterator() {
        return this.listIterator(0);
    }

    //从指定元素位置开始
    //创建一个新的迭代器
    public ListIterator<E> listIterator(int var1) {
        this.rangeCheckForAdd(var1);
        return new AbstractList.ListItr(var1);
    }

    public List<E> subList(int var1, int var2) {
        return (List) (this instanceof RandomAccess ? 
        		new RandomAccessSubList(this, var1, var2) : 
        							new SubList(this, var1, var2));
    }

    public boolean equals(Object var1) {
        if (var1 == this) {
            return true;
        } else if (!(var1 instanceof List)) {
            return false;
        } else {
            ListIterator var2 = this.listIterator();
            ListIterator var3 = ((List) var1).listIterator();

            while (true) {
                if (var2.hasNext() && var3.hasNext()) {
                    Object var4 = var2.next();
                    Object var5 = var3.next();
                    if (var4 == null) {
                        if (var5 == null) {
                            continue;
                        }
                    } else if (var4.equals(var5)) {
                        continue;
                    }

                    return false;
                }

                return !var2.hasNext() && !var3.hasNext();
            }
        }
    }

    public int hashCode() {
        int var1 = 1;

        Object var3;
        for (Iterator var2 = this.iterator(); var2.hasNext(); 
        			var1 = 31 * var1 + (var3 == null ? 0 : var3.hashCode())) {
            var3 = var2.next();
        }
        return var1;
    }

    protected void removeRange(int var1, int var2) {
        ListIterator var3 = this.listIterator(var1);
        int var4 = 0;

        for (int var5 = var2 - var1; var4 < var5; ++var4) {
            var3.next();
            var3.remove();
        }
    }

    //检测添加的位置范围是否合适
    private void rangeCheckForAdd(int var1) {
        if (var1 < 0 || var1 > this.size()) {
            throw new IndexOutOfBoundsException(this.outOfBoundsMsg(var1));
        }
    }
	//设置超出集合界限的模板消息
    private String outOfBoundsMsg(int var1) {
        return "Index: " + var1 + ", Size: " + this.size();
    }

    //借助于Iterator实现双向链表,
    private class ListItr extends AbstractList<E>.Itr implements ListIterator<E> {
        ListItr(int var2) {
            super(null);
            this.cursor = var2;
        }

        public boolean hasPrevious() {
            return this.cursor != 0;
        }

        public E previous() {
            this.checkForComodification();

            try {
                int var1 = this.cursor - 1;
                Object var2 = AbstractList.this.get(var1);
                this.lastRet = this.cursor = var1;
                return var2;
            } catch (IndexOutOfBoundsException var3) {
                this.checkForComodification();
                throw new NoSuchElementException();
            }
        }

        public int nextIndex() {
            return this.cursor;
        }

        public int previousIndex() {
            return this.cursor - 1;
        }

        public void set(E var1) {
            if (this.lastRet < 0) {
                throw new IllegalStateException();
            } else {
                this.checkForComodification();

                try {
                    AbstractList.this.set(this.lastRet, var1);
                    this.expectedModCount = AbstractList.this.modCount;
                } catch (IndexOutOfBoundsException var3) {
                    throw new ConcurrentModificationException();
                }
            }
        }

        public void add(E var1) {
            this.checkForComodification();

            try {
                int var2 = this.cursor;
                AbstractList.this.add(var2, var1);
                this.lastRet = -1;
                this.cursor = var2 + 1;
                this.expectedModCount = AbstractList.this.modCount;
            } catch (IndexOutOfBoundsException var3) {
                throw new ConcurrentModificationException();
            }
        }
    }

    // 实现list通用的迭代器，
    // 主要借助的是外部类的两个方法，remove(int) 和 get(int)
    private class Itr implements Iterator<E> {
        int cursor; //当前迭代器指向的位置
        int lastRet; //指向next操作的前一个元素
        int expectedModCount; //外部集合类修改集合的次数，用于fail-fast

        private Itr() {
            this.cursor = 0; //开始的位置
            this.lastRet = -1; //没有开始进行迭代操作
            
            //外部集合类修改集合的次数，用于fail-fast
            this.expectedModCount = AbstractList.this.modCount;						   }

        //利用当前指向的游标和外部类list的大小来判断是否还有下一个元素
        public boolean hasNext() {
            return this.cursor != AbstractList.this.size();
        }

        //返回元素
        public E next() {
            //首先利用fail-fast来检测list是否改变，
            this.checkForComodification();
            
            try {
                int var1 = this.cursor;
                //借助外部集合类得到指定位置的元素
                Object var2 = AbstractList.this.get(var1);
                this.lastRet = var1;
                this.cursor = var1 + 1;
                return var2;
            } catch (IndexOutOfBoundsException var3) { //捕获超出边界异常
				
				//判断是否是当前list被并发修改，如果是，则抛出此异常
                this.checkForComodification(); 
                throw new NoSuchElementException(); //正常抛出异常
            }
        }

        //实现Iterator 接口 的remove方法
        public void remove() {
            if (this.lastRet < 0) {
                throw new IllegalStateException();
            } else {
                this.checkForComodification();

                try {
                    //借助外部类的remove方法进行删除
                    AbstractList.this.remove(this.lastRet);
                    if (this.lastRet < this.cursor) { //当期那游标减1
                        --this.cursor;
                    }
                    this.lastRet = -1;
						//重新设置list的大小
                    this.expectedModCount = AbstractList.this.modCount; 
                } catch (IndexOutOfBoundsException var2) {
                    throw new ConcurrentModificationException();
                }
            }
        }

        // 判断list是否已经修改，
        // 如果修改则抛出并发修改错误
        final void checkForComodification() {
            if (AbstractList.this.modCount != this.expectedModCount) {
                throw new ConcurrentModificationException();
            }
        }
    }
}

```

### **6 AbstractSet**

AbstractSet的定义如下： 

```
public abstract class AbstractSet<E> 
		extends AbstractCollection<E> 
			implements Set<E> {}
```

AbstractSet是一个继承于AbstractCollection，并且实现Set接口的抽象类。由于Set接口和Collection接口中的API完全一样，Set也就没有自己单独的API。

和AbstractCollection一样，它实现了List中除iterator()和size()之外的函数。

AbstractSet的主要作用：它实现了Set接口中的大部分函数。从而方便其它类实现Set接口。



###  7 ListIterator

>ListIterator的定义如下：
>
>```
>public interface ListIterator<E> extends Iterator<E> {}
>```
>
>ListIterator是一个继承于Iterator的接口，它是队列迭代器。专门用于便利List，能提供向前/向后遍历。相比于Iterator，它新增了添加、是否存在上一个元素、获取上一个元素等等API接口。
>
>```java
>// ListIterator的API
>// 继承于Iterator的接口
>abstract boolean hasNext()
>abstract E next()
>abstract void remove()
>// 新增API接口
>abstract void add(E object)
>abstract boolean hasPrevious()
>abstract int nextIndex()
>abstract E previous()
>abstract int previousIndex()
>abstract void set(E object)
>```
>
>

