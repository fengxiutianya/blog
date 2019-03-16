---
title: Iterator 和 Iterable 区别
tags:
  - java
categories:
  - java
author: zhangke
abbrlink: 80c76146
date: 2017-12-23 19:31:00
---
# Iterator 和 Iterable 区别

### Iterator（迭代器）

作为一种设计模式，迭代器可以用于遍历一个对象，而开发人员不用去了解这个对象的底层结构。

这里就不仔细说迭代器这种设计模式，因为我们主要的目的是探索 java 中 Iterator 和 Iterable 之间的区别

<!-- more -->

### 用法

首先来说一下他们各自是怎么使用，不会用谈什么都是瞎搞。

#### Iterator 用法

首先来说一下 Iterator 这个接口，他定义了迭代器基本的功能。

#### 源码如下

```
package java.util;

public interface Iterator<E> {
    boolean hasNext();   //返回是否有下一个元素
    E next();            //返回下一个元素
    void remove();		 //移除当前元素
}


```

#### 如何使用这个接口

```
public class main {

    public static void main(String[] args) {
        MyIterator mi = new MyIterator();
        while (mi.hasNext()){
            System.out.printf("%s\t",mi.next());
        }
    }
}

class MyIterator implements Iterator<String>{
    private String[] words = ("And that is how "
            + "we know the Earth to be banana-shaped.").split(" ");
    private int count = 0;
    public MyIterator() {
    }

    @Override
    public boolean hasNext() {
        return count < words.length;
    }

    @Override
    public String next() {
        return words[count++];
    }
}
```

代码很简单，所以就不过多的解释了，但是有一点需要注意的是，下面这样使用上面定义的 MyIterator 类是错误的，你可以试一下。

```
for (String s:new MyIterator){
            System.out.printf("%s\t",s);
 }
```

### Iterable 用法

#### 源码

```
package java.lang;

import java.util.Iterator;

public interface Iterable<T> {

    Iterator<T> iterator();
}
```

#### 如何使用

```
public class main {

    public static void main(String[] args) {

      MyIterable myIterable= new MyIterable();
        Iterator<String> mIterator = myIterable.iterator();
        for (String s:myIterable){
            System.out.printf("%s\t",s);
        }
    }
}

class MyIterable implements Iterable<String>{
    private String[] words = ("And that is how "
            + "we know the Earth to be banana-shaped.").split(" ");

    @Override
    public Iterator<String> iterator() {
        return new Iterator<String>() {
            private int i = 0;
            @Override
            public boolean hasNext() {
                return i < words.length;
            }

            @Override
            public String next() {
                return words[i++];
            }
        };
    }
}
```

与上面 Iterator 不同的是，这个类还可以下面这样使用

```
		MyIterable mi = new MyIterable().iterator();
        while (mi.hasNext()){
            System.out.printf("%s\t",mi.next());
        } 
```

### 区别

基本用法已经说完，相信你也能看出其中的一些区别

1. Iterator 是迭代器类(这个类是指定义了迭代器基本需要的方法)，而 Iterable 是接口。 这个从他们的包名就可以看出来。

```Java
java.lang.Iterable
java.util.Iterator
```

1. Iterator 不嫩用于 foreach 循环语句，Iterable 可以

2. 为什么一定要实现 Iterable 接口，为什么不直接实现 Iterator 接口呢？

   看一下 JDK 中的集合类，比如 List 一族或者 Set 一族，都是实现了 Iterable 接口，但并不直接实现 Iterator 接口。

   这并不是没有道理的。

    因为 Iterator 接口的核心方法 next()或者 hasNext() 是依赖于迭代器的当前迭代位置的。

   如果 Collection 直接实现 Iterator 接口，势必导致集合对象中包含当前迭代位置的数据(指针)。

    当集合在不同方法间被传递时，由于当前迭代位置不可预置，那么 next()方法的结果会变成不可预知。 除非再为 Iterator 接口添加一个 reset()方法，用来重置当前迭代位置。 但即时这样，Collection 也只能同时存在一个当前迭代位置。

   而 Iterable 则不然，每次调用都会返回一个从头开始计数的迭代器。

   多个迭代器是互不干扰的

### 扩展

你在看 ArrayList 源码的时候，你会发现这样一段代码

```Java
   private class Itr implements Iterator<E> {
       int cursor;       // 返回下一个元素的索引

     	int lastRet = -1; // 返回最后一个元素的索引，如果空，返回-1

       int expectedModCount = modCount; //用于检测当前集合是否执行了添加删除操作，其中modCount，是当前集合中元素的个数

       public boolean hasNext() {
           return cursor != size;
       }

       @SuppressWarnings("unchecked")
       public E next() {
           checkForComodification(); //检测集合元素是否执行添加删除操作
           int i = cursor;
           if (i >= size)
               throw new NoSuchElementException();
           Object[] elementData = ArrayList.this.elementData;
           if (i >= elementData.length)
               throw new ConcurrentModificationException();
           cursor = i + 1;
           return (E) elementData[lastRet = i];
       }

       public void remove() {
           if (lastRet < 0)
               throw new IllegalStateException();
           checkForComodification();

           try {
               ArrayList.this.remove(lastRet);
               cursor = lastRet;
               lastRet = -1;
               expectedModCount = modCount;
           } catch (IndexOutOfBoundsException ex) {
               throw new ConcurrentModificationException();
           }
       }

       @Override
       @SuppressWarnings("unchecked")
       public void forEachRemaining(Consumer<? super E> consumer) {
           Objects.requireNonNull(consumer);
           final int size = ArrayList.this.size;
           int i = cursor;
           if (i >= size) {
               return;
           }
           final Object[] elementData = ArrayList.this.elementData;
           if (i >= elementData.length) {
               throw new ConcurrentModificationException();
           }
           while (i != size && modCount == expectedModCount) {
               consumer.accept((E) elementData[i++]);
           }
           // update once at end of iteration to reduce heap write traffic
           cursor = i;
           lastRet = i - 1;
           checkForComodification();
       }
		//如果发生添加删除操作，则抛出错误。
       final void checkForComodification() {
           if (modCount != expectedModCount)
               throw new ConcurrentModificationException();
       }
   }
```

 对于上述的代码不难看懂，有点疑惑的是 int expectedModCount = modCount;这句代码

其实这是集合迭代中的一种**快速失败**机制，这种机制提供迭代过程中集合的安全性。阅读源码​ 就可以知道 ArrayList 中存在 modCount 对象，增删操作都会使 modCount++，通过两者的对比​ 迭代器可以快速的知道迭代过程中是否存在 list.add()类似的操作，存在的话快速失败!

## Fail-Fast(快速失败)机制

仔细观察上述的各个方法，我们在源码中就会发现一个特别的属性 modCount，API 解释如下：

 The number of times this list has been structurally modified. Structural modifications are those​ that change the size of the list, or otherwise perturb it in such a fashion that iterations in progress​ may yield incorrect results.

记录修改此列表的次数：包括改变列表的结构，改变列表的大小，打乱列表的顺序等使正在进行 迭代产生 错误的结果。

Tips:仅仅设置元素的值并不是结构的修改

我们知道的是 ArrayList 是线程不安全的，如果在使用迭代器的过程中有其他的线程修改了 List 就会抛出 ConcurrentModificationException 这就是 Fail-Fast 机制。那么快速失败究竟是个什么意思呢？在 ArrayList 类创建迭代器之后，除非通过迭代器自身 remove 或 add 对列表结构进行修改，否则在其他线程中以任何形式对列表进行修改，迭代器马上会抛出异常，快速失败。

### 迭代器的好处

## 迭代器的好处

 通过上述我们明白了迭代是到底是个什么，迭代器的使用也十分的简单。现在简要的总结下使用迭代器的好处吧。

 **1、迭代器可以提供统一的迭代方式。**

**​ 2、 迭代器也可以在对客户端透明的情况下，提供各种不同的迭代方式。**

 **3、迭代器提供一种快速失败机制，防止多线程下迭代的不安全操作。**

 不过对于第三点尚需注意的是：就像上述事例代码一样，我们不能保证迭代过程中出现**快速失败**的都是因为同步造成的，因此为了保证迭代操作的正确性而去依赖此类异常是错误的！