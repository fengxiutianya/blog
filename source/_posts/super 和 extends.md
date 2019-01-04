abbrlink: 17
title: 泛型中 < ? extends T > 和 < ? extends T > 的区别
tags:
  - java
  - 泛型
categories:
  - java
author: zhangke
date: 2018-01-11 13:55:00
---
# 泛型中 < ? extends T > 和 < ? extends T > 的区别

这俩个主要用于对参数的保护，如果你看过Java api 源码的话，你经常看到方法参数类似上面的写法。

### 概要

>1. 类型擦除
>2. 逆变与协变
>3. ？ 的用法 
>4. extends 的用法
>5. super的用法
>6. PECS原则

### 类型擦除

>```java
>import java.util.*;
>public class main{
>  public static void main(String[] args){
>    Class c1 = new ArrayList< String>().getClass();
>    Class c2 = new ArrayList< Integer>().getClass();
>    System.out.println(c1 == c2);
>  }
>}
>```
>
>上面程序运行的结果是true。出现这个结果的原因正是类型擦除。
>
>在Java语言中，泛型是通过类型擦除来实现的，这意味着当你在使用泛型时，任何具体的类型都将被擦除，你唯一知道的就是你正在使用的是一个对象。因此上面List< String> 和List< Integer>在运行时事实上是同样的类型。（泛型类型只有在静态类型检查期间才出现，静态类型检查：基于程序的源代码来验证类型安全的过程；动态类型检查：在程序运行期间验证类型安全的过程；）
>
>#### 擦除带来的问题
>
>```java
>class HasF{
>  public void f(){
>    System.out.println("f");
>  }
>}
>class Manipulator< T>{
>  private T obj;
>  public Manipulator(T x){
>    obj = x;
>  }
>  public void manipulate(){
>    obj.f();
>  }
>}
>public class main{
>  
>  public static  void main(String[] args){
>    HasF hasf = new HasF();
>    Manipulator< HasF> m = new Manipulator< HasF>(hasf);
>    m.manipulate()  // error
>  }
>}
>```
>
>上面这段代码会报错，正是由于类型擦除导致的。因为类型擦除，所以泛型内部无法知道类型的信息，当你调用object没有的方法时，就会报错。
>
>### 补充一点：边界
>
>>因为擦除在方法体中移除了类型信息，所以运行时，你就需要辨别边界，边界是指：对象进入和离开方法的地点，这里是指泛型的方法体。
>>
>>```java
>>public class ArrayMaker< T> {
>>  private Class< T> kind;
>>  public ArrayMaker(Class<T> kind) {
>>    this.kind = kind;
>>  }
>>  @SuppressWarnings("unchecked")
>>  T[] create(int size) {
>>    return (T[])Array.newInstance(kind, size);
>>  }
>>  public static void main(String[] args) {
>>    ArrayMaker< String> stringMaker =
>>      new ArrayMaker< String>(String.class);
>>    String[] stringArray = stringMaker.create(9);
>>    System.out.println(Arrays.toString(stringArray));
>>  }
>>} /* Output:
>>[null, null, null, null, null, null, null, null, null]
>>*///:~
>>```
>>
>>上面这段代码就是因为在泛型的方法体中初始化，所以就把所有的类型当成了Object类型，因此输出的结果都是null。如果是String对象的话，输出的是**“  ”**
>>
>>仔细查看下面俩段代码：
>>
>>```java
>>// 不存在泛型
>>public class SimpleHolder {
>>  private Object obj;
>>  public void set(Object obj) { this.obj = obj; }
>>  public Object get() { return obj; }
>>  public static void main(String[] args) {
>>    SimpleHolder holder = new SimpleHolder();
>>    holder.set("Item");
>>    String s = (String)holder.get();
>>  }
>>} ///:~
>>```
>>
>>```java
>>/// 存在泛型
>>public class GenericHolder<T> {
>>  private T obj;
>>  public void set(T obj) { this.obj = obj; }
>>  public T get() { return obj; }
>>  public static void main(String[] args) {
>>    GenericHolder< String > holder =
>>      new GenericHolder< String >();
>>    holder.set("Item");
>>    String s = holder.get();
>>  }
>>} 
>>```
>>
>>但是如果你仔细查看俩段代码的字节码，你会发现是相同的。并且你会发现泛型所有的动作都是发生在边界处，会对传进来的值进行额外的编译检查，并插入对传递出去的值的类型。所以，可以得出一个结论，边界就是发生动作的地方。

### 逆变与协变

>协变与逆变这来个术语是用来描述类型转换（type transformations）后的继承关系。定义如下：A,B表示类型**≤ **表示继承关系.(比如：A ≤B表示A是B派生出来的子类  )
>
>- 逆变（contravariant），当A≤B时，B可以转化成A。
>- 协变（covariant），A≤B时，A可以转换成B。
>- 不变（invariant），如果上述俩种均不能使用。
>
>先来看一个简单的例子：
>
>考虑List< A >是否是协变，逆变，不变？协变意味着List< String >是List< Object>的子类，逆变意味着List
>
>< Object>是List< String>的子类，不变意味着上面俩种都不是。在java中List< String>和List< Object>是不变的类型。下面的代码在java中是编译不过去的，验证了集合在java中是不变的。
>
>```java
>ArrayList<String> strings = new ArrayList<Object>();
>ArrayList<Object> objects = new ArrayList<String>();
>```
>
>
>
>在来看另外一个例子，数组 A[]，判断数组是逆变，协变，不变三个的哪一种？很容易可以证明，在java中数组是协变的
>
>```java
>Object[] objs = new String[3]
>```
>
>下面这个例子是来研究方法,直接通过一个例子来说明
>
>```java
>Number[] method(ArrayList<Number> list) {
>  ...
>}
>//下面三个没有一个能编译过
>Integer[] result = method(new ArrayList<Integer>());
>Number[] result = method(new ArrayList<Integer>());
>Object[] result = method(new ArrayList<Object>());
>//下面俩个能编译过
>Number[] result = method(new ArrayList<Number>());
>Object[] result = method(new ArrayList<Number>());
>
>```
>
>调用方法`result = method(n)`；传入形参的类型应为method形参的子类型，即`typeof(n)≤typeof(method's parameter)`；result应为method返回值的基类型，即`typeof(methods's return)≤typeof(result)`：
>
>在Java 1.4中，子类覆盖（override）父类方法时，形参与返回值的类型必须与父类保持一致：
>
>```java
>class Super {
>    Number method(Number n) { ... }
>}
>
>class Sub extends Super {
>    @Override 
>    Number method(Number n) { ... }
>}
>```
>
>从Java 1.5开始，子类覆盖父类方法时允许协变返回更为具体的类型：
>
>```java
>class Super {
>    Number method(Number n) { ... }
>}
>
>class Sub extends Super {
>    @Override 
>    Integer method(Number n) { ... }
>}
>```

### ？ 的用法 

>下面是使用案例
>
>```Java
>public class UnboundedWildcardsl {
>    static List list1;
>    static List<?> list2;
>    static List<? extends Object> list3;
>//    @SuppressWarnings("unchecked")
>    static void assign1(List list){
>        list1 = list;
>        list2 = list;
>
>        list3 = list;     //未检查的转换
>    }
>    static void assign2(List<?> list){
>        list1 = list;
>        list2 = list;
>        list3 = list;
>    }
>    static void assign3(List<? extends Object> list){
>        list1 = list;
>        list2 = list;
>        list3 = list;
>    }
>
>    public static void main(String[] args) {
>        assign1(new ArrayList());
>        assign2(new ArrayList());
>        assign3(new ArrayList());
>
>        assign1(new ArrayList<>());
>        assign2(new ArrayList<>());
>        assign3(new ArrayList<>());
>
>        List<?> wildList = new ArrayList();
>        wildList = new ArrayList<String>();
>        assign1(wildList);
>        assign2(wildList);
>        assign3(wildList);
>    }
>}
>```
>
> 在很多情况下你会看到和这个情况类似，编译器很少关心使用的是原生类型还是< ?>，这些情况< ?> 被认为是一种装饰，不过还是有价值的，即我想用java泛型来编写代码。我在这里并不是要使用原生的类型，但是这种情况下，泛型参数可以支持有任何类型。

### extends 的用法

>extends表示的是上界通配符，下面展示的是如何使用:以 List<? extends Number> 为例来展示使用
>
>```Java
>//Number extends Number 
>List<? extends Number>  foo3 = new ArrayList<? extends Number>();
>
>//Integer extends Number
>List<? extends Number> foo3 = new ArrayList<? extends Integer>();
>
>//Double extends Number
>List<? extends Number> foo3 = new ArrayList<? extends Double>();
>
>//下面的是错误使用
>foo3.add(12);
>
>```
>
>1. 读取操作通过以上给定的赋值语句，你一定能从foo3列表中读取到的元素的类型是什么呢？你可以读取到Number，因为以上的列表要么包含Number元素，要么包含Number的子类元素。
>
>   你不能保证读取到Integer，因为foo3可能指向的是List< Double>。
>
>   你不能保证读取到Double，因为foo3可能指向的是List< Integer>。
>
>2. 写入操作过以上给定的赋值语句，你能把一个什么类型的元素合法地插入到foo3中呢？
>
>   你不能插入一个Integer元素，因为foo3可能指向List< Double>。
>
>   你不能插入一个Double元素，因为foo3可能指向List< Integer>。
>
>   你不能插入一个Number元素，因为foo3可能指向List< Integer>。
>
>   你不能往List< ? extends T>中插入任何类型的对象，因为你不能保证列表实际指向的类型是什么，你并不能保证列表中实际存储什么类型的对象。唯一可以保证的是，你可以从中读取到T或者T的子类。这也验证了java集合是不变的，由于无法判断类型，所以你也无法进行插入。

### super 的用法

>super下界通配符，下面以List\<？ super Integer>来展示super的用法
>
>```java
>//integer is a superClass of Integer 
>List<? super Integer>  foo3 = new ArrayList<Integer>()
> 
>//Number is a superClass of Integer
>List<? super Integer> foo3 = new ArrayList<Number>();
>
>//Object is superClass of Integer
>List<? super Integer> foo3 = new ArrayList<Object>();
>
>//下面代码是错误的
>list.get(index);  //不能获取
>```
>
>1. foo3可能指向List< Number>或者List< Object>。
>
>   你不能保证读取到Number，因为foo3可能指向List< Object>。
>
>   唯一可以保证的是，你可以读取到Object或者Object子类的对象（你并不知道具体的子类是什么）。
>
>2. 写入操作通过以上给定的赋值语句，你能把一个什么类型的元素合法地插入到foo3中呢？你可以插入Integer对象，因为上述声明的列表都支持Integer。
>
>   你可以插入Integer的子类的对象，因为Integer的子类同时也是Integer，原因同上。
>
>   你不能插入Double对象，因为foo3可能指向ArrayList< Integer>。
>
>   你不能插入Number对象，因为foo3可能指向ArrayList< Integer>。
>
>   你不能插入Object对象，因为foo3可能指向ArrayList< Integer>。

#### PECS(Pruducer extends,Consumer super)

>请记住PECS原则：生产者（Producer）使用extends，消费者（Consumer）使用super。
>
>- 生产者使用extends
>
>如果你需要一个列表提供T类型的元素（即你想从列表中读取T类型的元素），你需要把这个列表声明成\<? extends T>，比如List\<? extends Integer>，因此你不能往该列表中添加任何元素。
>
>- 消费者使用super
>
>如果需要一个列表使用T类型的元素（即你想把T类型的元素加入到列表中），你需要把这个列表声明成\<? super T>，比如List\<? super Integer>，因此你不能保证从中读取到的元素的类型。
>
>- 即是生产者，也是消费者
>
>如果一个列表即要生产，又要消费，你不能使用泛型通配符声明列表，比如List\<Integer>。
>
>请参考java.util.Collections里的copy方法(JDK1.7)：copy使用到了PECS原则，实现了对参数的保护。
>
>```Java
>/**
>     * Copies all of the elements from one list into another.  After the
>     * operation, the index of each copied element in the destination list
>     * will be identical to its index in the source list.  The destination
>     * list must be at least as long as the source list.  If it is longer, the
>     * remaining elements in the destination list are unaffected. <p>
>     *
>     * This method runs in linear time.
>     *
>     * @param  <T> the class of the objects in the lists
>     * @param  dest The destination list.
>     * @param  src The source list.
>     * @throws IndexOutOfBoundsException if the destination list is too small
>     *         to contain the entire source List.
>     * @throws UnsupportedOperationException if the destination list's
>     *         list-iterator does not support the <tt>set</tt> operation.
>     */
>    public static < T> void copy(List< ? super T> dest, List<? extends T> src) {
>        int srcSize = src.size();
>        if (srcSize > dest.size())
>            throw new IndexOutOfBoundsException("Source does not fit in dest");
>
>        if (srcSize < COPY_THRESHOLD ||
>            (src instanceof RandomAccess && dest instanceof RandomAccess)) {
>            for (int i=0; i<srcSize; i++)
>                dest.set(i, src.get(i));
>        } else {
>            ListIterator< ? super T> di=dest.listIterator();
>            ListIterator< ? extends T> si=src.listIterator();
>            for (int i=0; i<srcSize; i++) {
>                di.next();
>                di.set(si.next());
>            }
>        }
>    }
>```
>
>





