---
title: Iterator和Iterable 区别
tags:
  - java
categories:
  - java
  - 基础
author: zhangke
abbrlink: 80c76146
date: 2017-12-23 19:31:00
---
## Iterator（迭代器）
作为一种设计模式，迭代器可以用于遍历一个对象，对外提供统一的遍历接口，而使得开发人员不用去了解这个对象的底层结构。
这里就不仔细说迭代器这种设计模式，因为我们主要的目的是探索java中Iterator和 Iterable的基本使用，并说明俩则的区别
<!-- more -->
## 用法
首先来说一下他们各自是怎么使用，不会用谈什么都是瞎搞。
### Iterator 用法
首先来说一下 Iterator 这个接口，他定义了迭代器基本的功能。
#### 源码如下
```java
package java.util;

public interface Iterator<E> {
    boolean hasNext();   //返回是否有下一个元素
    E next();            //返回下一个元素
    void remove();       //移除当前元素
}
```
#### 如何使用这个接口

``` java
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

### Iterable 用法

#### 源码

``` java
package java.lang;

import java.util.Iterator;

public interface Iterable<T> {

    Iterator<T> iterator(); // 返回Iterator对象
}
```
#### 如何使用

``` java
public class main {

    public static void main(String[] args) {

      MyIterable myIterable= new MyIterable();
        Iterator<String> mIterator = myIterable.iterator();
         while (mi.hasNext()){
            System.out.printf("%s\t",mi.next());
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

与上面 Iterator 不同的是，这个类还可以像下面这样使用

``` java
		MyIterable mi = new MyIterable().iterator();
       for (String s:myIterable){
            System.out.printf("%s\t",s);
        }
```
这是java提供的语法糖，foreach使用。语法糖是编程语言提供的一些便于程序员书写代码的语法，是编译器提供给程序员的糖衣，编译时会对这些语法特殊处理。语法糖虽然不会带来实质性的改进，但是在提高代码可读性，提高语法严谨性，减少编码错误机会上确实做出了很大贡献。

Java要求集合必须实现Iterable接口，才能使用for-each语法糖遍历该集合的实例。
JDK对该接口的描述是：
``` txt
Implementing this interface allows an object to be the target of * the "for-each loop" statement.
```
实际上，这也没什么高级的，foreach语法糖只是简化了我们遍历的代码，而这一步简化是有编译器帮我们做的，当编译器编译foreach语句的时候，其实还是转换成我们通常使用的方式。
类如上面的会转换成下面这个格式：
``` java
for (I #i = Expression.iterator(); #i.hasNext(); ) {
    {VariableModifier} TargetType Identifier =
        (TargetType) #i.next();
    Statement
}
```
当然，除了集合，for-each还可以遍历数组，翻译如下：
``` java
T[] #a = Expression;
L1: L2: ... Lm:
for (int #i = 0; #i < #a.length; #i++) {
    {VariableModifier} TargetType Identifier = #a[#i];
    Statement
}
```
## 区别

基本用法已经说完，相信你也能看出其中的一些区别

1. Iterator是迭代器类(这个类是指定义了迭代器基本需要的方法)，而Iterable是接口,用于返回Iterator。因此俩个就不是在说同一件事，只是名字很相似

    ``` java
    java.lang.Iterable
    java.util.Iterator
    ```

2.  Iterator不能用于foreach 循环语句，Iterable可以

3.  为什么一定要实现Iterable接口，为什么不直接实现Iterator接口呢？
    看一下 JDK 中的集合类，比如List一族或者Set一族，都是实现了Iterable接口，但并不直接实现Iterator 接口。这并不是没有道理的。因为Iterator接口的核心方法next()或者hasNext()是依赖于迭代器的当前迭代位置的。如果Collection直接实现Iterator接口，势必导致集合对象中包含当前迭代位置的数据(指针)。当集合在不同方法间被传递时，由于当前迭代位置不可预知，那么next()方法的结果会变成不可预知。除非再为Iterator接口添加一个reset()方法，用来重置当前迭代位置。但即时这样，Collection也只能同时存在一个当前迭代位置。
    而Iterable则不然，每次调用都会返回一个对象，这时可以设置一个从头开始计数的迭代器。多个迭代器之间不会造成是互不干扰。

## 扩展
你在看ArrayList源码的时候，你会发现这样一段代码
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
对于上述的代码不难看懂，有点疑惑的是`int expectedModCount = modCount;`这句代码其实这是集合迭代中的一种**快速失败**机制，这种机制提供迭代过程中集合的安全性。阅读源码​ 就可以知道 ArrayList 中存在modCount对象，增删操作都会使`modCount++`，通过两者的对比​ 迭代器可以快速的知道迭代过程中是否存在是否有其他线程正在修改这个集合，比如`list.add()`类似的操作，存在的话快速失败!

### Fail-Fast(快速失败)机制
仔细观察上述的各个方法，我们在源码中就会发现一个特别的属性modCount，API解释如下：
```
The number of times this list has been structurally modified. Structural modifications 
are those​ that change the size of the list, or otherwise perturb it in such a fashion
that iterations in progress​ may yield incorrect results.
```
记录修改此列表的次数：包括改变列表的结构，改变列表的大小，打乱列表的顺序等使正在进行迭代产生 错误的结果。

**Tips:**仅仅设置元素的值并不是结构的修改

我们知道的是ArrayList是线程不安全的，如果在使用迭代器的过程中有其他的线程修改了List就会抛出 ConcurrentModificationException异常这就是Fail-Fast机制。那么快速失败究竟是个什么意思呢？在 ArrayList类创建迭代器之后，除非通过迭代器自身remove或add对列表结构进行修改，否则在其他线程中以任何形式对列表进行修改，迭代器马上会抛出异常，快速失败。

## 迭代器的有点
通过上述我们明白了迭代是到底是个什么，迭代器的使用也十分的简单。现在简要的总结下使用迭代器的有点。

1. 迭代器可以提供统一的迭代方式。
2. 迭代器也可以在对客户端透明的情况下，提供各种不同的迭代方式。
3. 迭代器提供一种快速失败机制，防止多线程下迭代的不安全操作。

不过对于第三点尚需注意的是：就像上述事例代码一样，我们不能保证迭代过程中出现**快速失败**的都是因为同步造成的，因此为了保证迭代操作的正确性而去依赖此类异常是不正确的。这只是提示你当前有其他线程正在修改集合，因此你需要使用线程安全的方式来修改你的代码。


 ## 参考
 1. [Java基础-迭代器Iterator与语法糖for-each](https://www.jianshu.com/p/186bf11ffe51)