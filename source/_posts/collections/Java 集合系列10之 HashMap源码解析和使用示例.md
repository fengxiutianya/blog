---
abbrlink: 8
---
# Java 集合系列10 之HashMap详细介绍和使用示例

### 概要

1. HashMap介绍
2. HashMap源码解析
3. HashMap遍历方式
4. HashMap使用示例

### 1. HashMap介绍

>HashMap简介
>
>类图如下：
>
>![upload successful](/images/pasted-162.png)
>
>HashMap是一个散列表，他存储的内容是键值对(key-value)，其中key允许为null。这也是他与HashTable的一个重要区别。
>
>HashMap继承于AbstractMap，实现了Map，Cloneable，java.io.Serualizable接口
>
>HashMap的实现不是同步的，这意味着他不是线程安全的，在oracle给出的官方文档中，如果要并发使用，推介使用下面这种方式，
>
>```
>Map m = Collections.synchronizedMap(new HashMap(...));
>```
>
>HashMap 的实例有两个参数影响其性能：“**初始容量**” 和 “**加载因子**”。容量是哈希表中数组的长度，**初始容量** 只是哈希表在创建时的容量。**加载因子** 是哈希表在其容量自动增加之前可以达到多满的一种尺度。当哈希表中的条目数超出了加载因子与当前容量的乘积时，则要对该哈希表进行 rehash 操作（即重建内部数据结构），从而哈希表将具有大约两倍的数组长度。
>通常，**默认加载因子是 0.75**, 这是在时间和空间成本上寻求一种折衷。加载因子过高虽然减少了空间开销，但同时也增加了查询成本（在大多数 HashMap 类的操作中，包括 get 和 put 操作，都反映了这一点）。在设置初始容量时应该考虑到映射中所需的条目数及其加载因子，以便最大限度地减少 rehash 操作次数。如果初始容量大于最大条目数除以加载因子，则不会发生 rehash 操作。

### 2. HashMap 源码解析



### 3. HashMap遍历方式

> **遍历HashMap的键值对**
>
> 第一步：**根据entrySet()获取HashMap的“键值对”的Set集合。**
>
> 第二步：**通过Iterator迭代器遍历“第一步”得到的集合。**
>
> ```java
> // 假设map是HashMap对象
> // map中的key是String类型，value是Integer类型
> Integer integ = null;
> Iterator iter = map.entrySet().iterator();
> while(iter.hasNext()) {
>     Map.Entry entry = (Map.Entry)iter.next();
>     // 获取key
>     key = (String)entry.getKey();
>         // 获取value
>     integ = (Integer)entry.getValue();
> }
> ```
>
> **遍历HashMap的键**
>
> 第一步：**根据keySet()获取HashMap的“键”的Set集合。**
> 第二步：**通过Iterator迭代器遍历“第一步”得到的集合。**
>
> ```
> // 假设map是HashMap对象
> // map中的key是String类型，value是Integer类型
> String key = null;
> Integer integ = null;
> Iterator iter = map.keySet().iterator();
> while (iter.hasNext()) {
>         // 获取key
>     key = (String)iter.next();
>         // 根据key，获取value
>     integ = (Integer)map.get(key);
> }
> ```
>
> **遍历HashMap的值**
>
> 第一步：**根据value()获取HashMap的“值”的集合。**
> 第二步：**通过Iterator迭代器遍历“第一步”得到的集合**
>
> ```
> // 假设map是HashMap对象
> // map中的key是String类型，value是Integer类型
> Integer value = null;
> Collection c = map.values();
> Iterator iter= c.iterator();
> while (iter.hasNext()) {
>     value = (Integer)iter.next();
> }
> ```
>
> 代码如下
>
> ```
> import java.util.Collection;
> import java.util.HashMap;
> import java.util.Iterator;
> import java.util.Map;
> import java.util.function.Consumer;
>
> @FunctionalInterface
> interface testTime {
>     void apply(Map map);
> }
>
> /**************************************
>  *      Author : zhangke
>  *      Date   : 2018/3/13 10:36
>  *      Desc   : 用于测试HashMap 遍历的快慢
>  *
>  *      三种遍历方式
>  *      1. 通过entrySet()遍历key、value,参考实现函数
>  *          iteratorHashMapByEntrySet
>  *      2. 通过keySet()去遍历key，value，参考实现函数：
>  *          IteratorHashMapByKeySet
>  *      3. 通过values()去遍历value，参考实现函数：
>  *          iteratorHashMapByValues
>  ***************************************/
> public class HashMapIteratorTest {
>     public static void main(String[] args) {
>         int val = 0;
>
>         HashMap<String, Integer> map = new HashMap();
>
>         for (int i = 0; i < 1000000; i++) {
>             // 随机获取一个[0,100)之间的数字
>
>             // 添加到HashMap中
>             map.put(Integer.toString(i), i);
>             //System.out.println(" key:" + key + " value:" + value);
>         }
>         test((hashmap) -> {
>             iteratorHashMapByEntrySet(hashmap);
>         }, map);
>         test((hashmap) -> {
>             iteratorHashMapJustValues(hashmap);
>         }, map);
>         test((hashmap) -> {
>             IteratorHashMapByKeySet(hashmap);
>         }, map);
>     }
>
>     private static void test(Consumer<HashMap<String, Integer>> consumerm, HashMap map) {
>         long start = System.currentTimeMillis();
>         consumerm.accept(map);
>         long end = System.currentTimeMillis();
>         System.out.println(end - start);
>     }
>
>     /**
>      * 通过entry set遍历HashMap
>      */
>     private static void iteratorHashMapByEntrySet(HashMap<String, Integer> map) {
>         if (map == null)
>             return;
>         System.out.println("iterator HashMap By EntrySet");
>         String key = null;
>         Integer integ = null;
>         Iterator iterator = map.entrySet().iterator();
>         while (iterator.hasNext()) {
>             Map.Entry<String, Integer> entry = (Map.Entry) iterator.next();
>             key = entry.getKey();
>             integ = entry.getValue();
>             // System.out.println(key + "--- " + integ.intValue());
>         }
>
>     }
>
>     /**
>      * 通过keySet来遍历HashMap
>      */
>     private static void IteratorHashMapByKeySet(HashMap<String, Integer> map) {
>         if (map == null)
>             return;
>         System.out.println("iterator HashMap By keyset");
>         String key = null;
>         Integer integ = null;
>         Iterator<String> iter = map.keySet().iterator();
>         while (iter.hasNext()) {
>             key = iter.next();
>             integ = map.get(key);
>             // System.out.println(key + "--- " + integ.intValue());
>         }
>     }
>
>     /**
>      * 遍历HashMap的values
>      */
>     private static void iteratorHashMapJustValues(HashMap map) {
>         if (map == null)
>             return;
>         System.out.println("iterator by values");
>         Collection c = map.values();
>         Iterator iter = c.iterator();
>         while (iter.hasNext()) {
>             iter.next();
>             //  System.out.println(iter.next());
>         }
>     }
> }
> ```
>
> 其实你运行上面的代码，会发现三种遍历方式的速度是相同的。因为三种方式得到的Iterator的实现方式是一样的。在HashMap源码里面首先定义了HashIterator抽象类，这里面实现了Iterator的所有方法，接着为了得到Key，value，Entry，只需在Iterator.next()后面加上key或者value就可以。所以三种遍历方式的速度大小相同

###  4. HashMap使用示例

>```java
>import java.util.Map;
>import java.util.Random;
>import java.util.Iterator;
>import java.util.HashMap;
>import java.util.HashSet;
>import java.util.Map.Entry;
>import java.util.Collection;
>
>public class HashMapTest {
>
>    public static void main(String[] args) {
>        testHashMapAPIs();
>    }
>    
>    private static void testHashMapAPIs() {
>        // 初始化随机种子
>        Random r = new Random();
>        // 新建HashMap
>        HashMap map = new HashMap();
>        // 添加操作
>        map.put("one", r.nextInt(10));
>        map.put("two", r.nextInt(10));
>        map.put("three", r.nextInt(10));
>
>        // 打印出map
>        System.out.println("map:"+map );
>
>        // 通过Iterator遍历key-value
>        Iterator iter = map.entrySet().iterator();
>        while(iter.hasNext()) {
>            Map.Entry entry = (Map.Entry)iter.next();
>            System.out.println("next : "+ entry.getKey() +" - "+entry.getValue());
>        }
>
>        // HashMap的键值对个数        
>        System.out.println("size:"+map.size());
>
>        // containsKey(Object key) :是否包含键key
>        System.out.println("contains key two : "+map.containsKey("two"));
>        System.out.println("contains key five : "+map.containsKey("five"));
>
>        // containsValue(Object value) :是否包含值value
>        System.out.println("contains value 0 : "+
>                 map.containsValue(new Integer(0)));
>
>        // remove(Object key) ： 删除键key对应的键值对
>        map.remove("three");
>
>        System.out.println("map:"+map );
>
>        // clear() ： 清空HashMap
>        map.clear();
>
>        // isEmpty() : HashMap是否为空
>        System.out.println((map.isEmpty()?"map is empty":"map is not empty") );
>    }
>}
>```
>
>











 