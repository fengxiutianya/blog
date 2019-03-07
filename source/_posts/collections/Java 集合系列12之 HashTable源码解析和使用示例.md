---
abbrlink: 9
---
# Java集合系列 之 HashTable详细介绍和使用示例

### 概要

>这一章我们对HashTable进行学习。主要内容如下
>
>1. HashTable介绍
>2. HashTable源码解析
>3. HashTable遍历方式
>4. HashTable示例

### 1. HashTable介绍

>HashTable是一个散列表，和HashMap类似。他存储的内容是键值对(key-value)映射。
>
>HashTable继承于Dictionary，实现了Map、Cloneable、java.io.Serializable接口。
>
>HashTable的函数都是同步的，这意味着他是线程安全的。
>
>它的key，value都不可以为null。此外HashTable的映射不是有序的。
>
>Hashtable 的实例有两个参数影响其性能：**初始容量** 和 **加载因子**。容量 是哈希表中桶 的数量，初始容量 就是哈希表创建时的容量。注意，哈希表的状态为 open：在发生“哈希冲突”的情况下，单个桶会存储多个条目，这些条目必须按顺序搜索。加载因子 是对哈希表在其容量自动增加之前可以达到多满的一个尺度。初始容量和加载因子这两个参数只是对该实现的提示。关于何时以及是否调用 rehash 方法的具体细节则依赖于该实现。
>通常，**默认加载因子是 0.75**, 这是在时间和空间成本上寻求一种折衷。加载因子过高虽然减少了空间开销，但同时也增加了查找某个条目的时间（在大多数 Hashtable 操作中，包括 get 和 put 操作，都反映了这一点）。
>
>HashTable的继承关系
>
>```
>java.lang.Object
>   ↳     java.util.Dictionary<K, V>
>         ↳     java.util.Hashtable<K, V>
>
>public class Hashtable<K,V> extends Dictionary<K,V>
>    implements Map<K,V>, Cloneable, java.io.Serializable { }
>```
>
>HashTable的构造函数
>
>```java
>// 默认构造函数。
>public Hashtable() 
>
>// 指定“容量大小”的构造函数
>public Hashtable(int initialCapacity) 
>
>// 指定“容量大小”和“加载因子”的构造函数
>public Hashtable(int initialCapacity, float loadFactor) 
>
>// 包含“子Map”的构造函数
>public Hashtable(Map<? extends K, ? extends V> t)
>```
>
>HashTable的API
>
>```
>synchronized void                clear()
>synchronized Object              clone()
>             boolean             contains(Object value)
>synchronized boolean             containsKey(Object key)
>synchronized boolean             containsValue(Object value)
>synchronized Enumeration<V>      elements()
>synchronized Set<Entry<K, V>>    entrySet()
>synchronized boolean             equals(Object object)
>synchronized V                   get(Object key)
>synchronized int                 hashCode()
>synchronized boolean             isEmpty()
>synchronized Set<K>              keySet()
>synchronized Enumeration<K>      keys()
>synchronized V                   put(K key, V value)
>synchronized void                putAll(Map<? extends K, ? extends V> map)
>synchronized V                   remove(Object key)
>synchronized int                 size()
>synchronized String              toString()
>synchronized Collection<V>       values()
>```
>
>

### HashTable源码解析

>```
>
>```
>
>通过对源码的解析，可以得出以下的结论
>
>1. HashTable的内部实现是通过拉链法来实现的。首先定义了一个存储指定Hash值的Entry[]数组，如果Hash值冲突了，也就是这个位置已经存储了一个值，则数组中存储的元素就是链表的头结点，然后将新插入的节点链接到这个链表上。
>2. HashTable是线程安全的，通过synchronized实现，所以保证线程安全的代价很大。
>3. HashTable的迭代器有俩种：Iterator2和Enumeration。内部源码显示俩种迭代器的大致实现是通过Enumerator类来实现。因此这俩种迭代器只是叫法和用法不同，但是性能应该是差不多的。
>
>
>
>

### HashTable的遍历方式

>** 遍历Hashtable的键值对**
>
>第一步：**根据entrySet()获取Hashtable的“键值对”的Set集合。**
>第二步：**通过Iterator迭代器遍历“第一步”得到的集合。**
>
>```
>// 假设table是Hashtable对象
>// table中的key是String类型，value是Integer类型
>Integer integ = null;
>Iterator iter = table.entrySet().iterator();
>while(iter.hasNext()) {
>    Map.Entry entry = (Map.Entry)iter.next();
>    // 获取key
>    key = (String)entry.getKey();
>        // 获取value
>    integ = (Integer)entry.getValue();
>}
>```
>
>**通过Iterator遍历Hashtable的键**
>
>第一步：**根据keySet()获取Hashtable的“键”的Set集合。**
>第二步：**通过Iterator迭代器遍历“第一步”得到的集合。**
>
>```
>// 假设table是Hashtable对象
>// table中的key是String类型，value是Integer类型
>String key = null;
>Integer integ = null;
>Iterator iter = table.keySet().iterator();
>while (iter.hasNext()) {
>        // 获取key
>    key = (String)iter.next();
>        // 根据key，获取value
>    integ = (Integer)table.get(key);
>} 
>```
>
>**通过Iterator遍历Hashtable的值**
>
>第一步：**根据value()获取Hashtable的“值”的集合。**
>第二步：**通过Iterator迭代器遍历“第一步”得到的集合。**
>
>```
>// 假设table是Hashtable对象
>// table中的key是String类型，value是Integer类型
>Integer value = null;
>Collection c = table.values();
>Iterator iter= c.iterator();
>while (iter.hasNext()) {
>    value = (Integer)iter.next();
>}
>```
>
>** 通过Enumeration遍历Hashtable的键**
>
>第一步：**根据keys()获取Hashtable的集合。**
>第二步：**通过Enumeration遍历“第一步”得到的集合。**
>
>```
>Enumeration enu = table.keys();
>while(enu.hasMoreElements()) {
>    System.out.println(enu.nextElement());
>}   
>```
>
>** 通过Enumeration遍历Hashtable的值**
>
>第一步：**根据elements()获取Hashtable的集合。**
>第二步：**通过Enumeration遍历“第一步”得到的集合。**
>
>```
>Enumeration enu = table.elements();
>while(enu.hasMoreElements()) {
>    System.out.println(enu.nextElement());
>}
>```
>
> 遍历测试程序如下
>
>```
>import java.util.*;
>import java.util.function.Consumer;
>
>/**************************************
> *      Author : zhangke
> *      Date   : 2018/3/19 17:10
> *      Desc   : HashTable 的遍历测试
> ***************************************/
>public class HashTableIterator {
>
>
>    public static void main(String[] args) {
>
>        String key = null;
>
>        Random r = new Random();
>        Hashtable table = new Hashtable();
>
>        for (int i = 0; i < 100002; i++) {
>            // 随机获取一个[0,100)之间的数字
>
>
>            key = String.valueOf(i);
>
>            // 添加到Hashtable中
>            table.put(key, i);
>
>        }
>        testTime((t) -> {
>            System.out.println("EnumerationElements");
>            iteratorHashtableByEnumerationElements(t);
>        }, table);
>        testTime((t) -> {
>            System.out.println("EnumerationonValue");
>            iteratorHashtableByEnumerationValue(t);
>        }, table);
>
>        testTime((t) -> {
>            System.out.println("ByEntrySet");
>            iteratorHashtableByEntrySet(t);
>        }, table);
>
>        testTime((t) -> {
>            System.out.println("Byvalues");
>            iteratorhashTableByValues(t);
>        }, table);
>        testTime((t) -> {
>            System.out.println("ByKeySet");
>            iteratorHashTableByKeySet(t);
>        }, table);
>
>    }
>
>   
>   public static void testTime(Consumer<Hashtable> c, Hashtable l) {
>        long start = System.currentTimeMillis();
>        c.accept(l);
>        long end = System.currentTimeMillis();
>        System.out.println(end - start);
>    }
>
>    /**
>     * 遍历HashTable的键值对
>     * 通过entrySet获取Hashtable的键值对的Set集合
>     * 通过Iterator迭代器遍历第一步得到的集合
>     */
>    public static void iteratorHashtableByEntrySet(Hashtable<String, Integer> table) {
>
>        Iterator iterator = table.entrySet().iterator();
>        while (iterator.hasNext()) {
>            Map.Entry entry = (Map.Entry) iterator.next();
>            entry.getKey();
>            entry.getValue();
>        }
>    }
>
>    /**
>     * 遍历HashTable的键
>     * 通过keySet获取HashTable的键的set集合
>     * 通过Iterator迭代器遍历第一步得到的集合
>     */
>    public static void iteratorHashTableByKeySet(Hashtable<String, Integer> table) {
>        String key = null;
>        Iterator iterator = table.keySet().iterator();
>        while (iterator.hasNext()) {
>            key = (String) iterator.next();
>            table.get(key);
>        }
>    }
>
>    /**
>     * 遍历HashTable的值的集合
>     * 根据value获取HashTable的值的集合
>     * 通过Iterator迭代器遍历第一步得到的集合
>     */
>    public static void iteratorhashTableByValues(Hashtable<String, Integer> table) {
>        Collection c = table.values();
>        Iterator iterator = c.iterator();
>        while (iterator.hasNext()) {
>            iterator.next();
>        }
>    }
>
>    /**
>     * 通过Enumeration遍历Hashtable的键
>     * 根据keys获取Hashtable的键的集合
>     * 通过第一步得到的Enumeration来进行遍历
>     */
>    public static void iteratorHashtableByEnumerationValue(Hashtable<String, Integer> table) {
>        Enumeration enumeration = table.keys();
>        while (enumeration.hasMoreElements()) {
>            enumeration.nextElement();
>        }
>    }
>
>
>    /**
>     * 通过Enumeration遍历HashTable的值
>     * 根据elements获取HashTable的集合
>     * 通过第一步获取Enumeration来进行
>     */
>    public static void iteratorHashtableByEnumerationElements(Hashtable<String, Integer> table) {
>        Enumeration enumeration = table.elements();
>        while (enumeration.hasMoreElements()) {
>            enumeration.nextElement();
>        }
>    }
>}
>
>```
>
>

### 4. HashTable 示例

>```
>import java.util.Hashtable;
>import java.util.Iterator;
>import java.util.Map;
>import java.util.Random;
>
>/**************************************
> *      Author : zhangke
> *      Date   : 2018/3/20 14:42
> *      Desc   : 
> ***************************************/
>public class HashTableTest {
>
>    public static void main(String[] args) {
>        testHashtableAPIs();
>    }
>
>    private static void testHashtableAPIs() {
>        // 初始化随机种子
>        Random r = new Random();
>        // 新建Hashtable
>        Hashtable table = new Hashtable();
>
>        // 添加操作
>        table.put("one", r.nextInt(10));
>        table.put("two", r.nextInt(10));
>        table.put("three", r.nextInt(10));
>      
>        // 打印出table
>        System.out.println("table:" + table);
>
>        // 通过Iterator遍历key-value
>        Iterator iter = table.entrySet().iterator();
>        while (iter.hasNext()) {
>            Map.Entry entry = (Map.Entry) iter.next();
>            System.out.println("next : " + entry.getKey() + " - " + entry.getValue());
>        }
>
>        // Hashtable的键值对个数
>        System.out.println("size:" + table.size());
>
>        // containsKey(Object key) :是否包含键key
>        System.out.println("contains key two : " + table.containsKey("two"));
>        System.out.println("contains key five : " + table.containsKey("five"));
>
>        // containsValue(Object value) :是否包含值value
>        System.out.println("contains value 0 : " + table.containsValue(new Integer(0)));
>
>        // remove(Object key) ： 删除键key对应的键值对
>        table.remove("three");
>
>        System.out.println("table:" + table);
>
>        // clear() ： 清空Hashtable
>        table.clear();
>
>        // isEmpty() : Hashtable是否为空
>        System.out.println((table.isEmpty() ? "table is empty" : "table is not empty"));
>    }
>}
>
>```
>
>

