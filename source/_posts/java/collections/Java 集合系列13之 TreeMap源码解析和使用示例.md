---
title: Java 集合系列13 TreeMap源码解析和使用示例
tags:
  - 集合
categories:
  - java
  - collections
abbrlink: 7b22f4ce
date: 2019-03-04 22:58:00
---

### 概要

>1. TreeMap介绍
>2. TreeMap源码解析
>3. TreeMap遍历方式
>4. TreeMap示例

<!-- more -->

### 1. TreeMap介绍

>TreeMap 是一个**有序的key-value集合**，它是通过红黑树实现的。
>TreeMap **继承于AbstractMap**，所以它是一个Map，即一个key-value集合。
>TreeMap 实现了NavigableMap接口，意味着它**支持一系列的导航方法。**比如返回有序的key集合。
>TreeMap 实现了Cloneable接口，意味着**它能被克隆**。
>TreeMap 实现了java.io.Serializable接口，意味着**它支持序列化**。
>
>TreeMap基于**红黑树（Red-Black tree）实现**。该映射根据**其键的自然顺序进行排序**，或者根据**创建映射时提供的 Comparator 进行排序**，具体取决于使用的构造方法。
>
>TreeMap的基本操作 containsKey、get、put 和 remove 的时间复杂度是 log(n) 。
>另外，TreeMap是**非同步**的。 它的iterator 方法返回的**迭代器是fail-fast**的。
>
>```java
>
>// 构造函数
>TreeMap()  //默认构造函数
>TreeMap(Comparator<? super K> compartor)//指定比比较器来构造TreeMap
>TreeMap(Map<? extends K,? extends V> m) //使用指定的Map初始化TreeMap，插入到当前Map
>TreeMap(SortedMap<K,? extends V> m)  //指定类型的SortedMap来构造
>//API
>
>//SortedMap 接口定义的函数
>       //返回key使用的排序接口，或者使用自然顺序
>Comparator<? super K> comparator() 
>Set<Map.Entry<K,V>>   entrySet() //包含在此Map种的一个Entry的Set集
>K firstKey()   //返回key值最小的map，
>SortedMap<K,V> headMap(K toKey) // 返回key值小于tokey的子集
>Set<K>	keySet()  //返回map中key的Set集合
>K	lastKey()  //返回此集合中最大的key值
>SortedMap<K,V>	subMap(K fromKey, K toKey) //[fromKey,toKey)
>SortedMap<K,V>	tailMap(K fromKey) //返回 >= fromKey 子集
>Collection<V>	values()  //返回当前集合value的Collection集合
>
>//NavigableMap 接口定义的函数
> 
>Map.Entry<K, V> ceilingEntry(K key);//返回的Entry满足key2>=key，选取key2中最小Entry返回
>K ceilingKey(K key); //返回的key满足：key2 >= key，选取key2中最小的key返回
>Map.Entry<K, V> floorEntry(K key);//返回的Entry满足key>=key2然后选取key2中最大Entry返回
>K floorKey(K key);//返回的key满足key>=key2然后选取key2中最大的key返回
>
>Map.Entry<K, V> firstEntry(); // 返回最小的key-value键值对
>Map.Entry<K, V> lastEntry(); // 返回最大的key-value键值对
>Map.Entry<K, V> pollFirstEntry();   //删除并返回最小的key-value键值对
>Map.Entry<K, V> pollLastEntry(); //删除并返回最大的key-value键值对
>
>Map.Entry<K, V> lowerEntry(K key)//返回的Entry满足,key>key2,返回比指定key小的键中最大的Entry
>K lowerKey(K key); //返回的key满足下面的条件,key>key2,返回比指定key小的键中最大的键
>Map.Entry<K, V> higherEntry(K key) //返回的Entry满足key2>key,然后选取key2中最小的Entry返回
>K higherKey(K key) //返回的key满足key2>key,然后选取key2中最小的key返回
>  
>NavigableSet<K> descendingKeySet();  //返回当前Map的逆序排序的key的Set集合
>NavigableMap<K, V> descendingMap();  //返回当前Map的逆序排序的Entry的Map集合
>NavigableSet<K> navigableKeySet();  //返回一个可导航的Key的Set集合
>//返回从fromKey到toKey之间的可导航的子集和。
>//其中fromInclusive和toInclusive是确定fromkey和toKey是否返回
>NavigableMap<K, V> subMap(K fromKey, boolean fromInclusive, K toKey, boolean toInclusive);
>SortedMap<K, V> subMap(K fromKey, K toKey); //相当于subMap(fromKey, true, toKey, false)
>
>//返回小于或等于（如果inclusive是true）tokey的子集和
>NavigableMap<K, V> headMap(K toKey, boolean inclusive);
>// 相当于 headMap(toKey, false)
>SortedMap<K, V> headMap(K toKey);
>
>//返回小于或等于（如果inclusive是true）tokey的子集和
>NavigableMap<K, V> tailMap(K fromKey, boolean inclusive);
>//相当于tailMap(fromKey, true)
>SortedMap<K, V> tailMap(K fromKey);
>
>
>void clear()  //清空当前Map
>Object clone() //克隆当前对象
>boolean	containsKey(Object key)  //是否包含指定的key
>boolean	containsValue(Object value) //是否包含指定的value
>Set<Map.Entry<K,V>>	entrySet()  //返回当前Map的键值对
>Set<K>	keySet()                //返回的当前key值的Set集合
>V put(K key, V value)  //插入指定的key-value键值对
>void putAll(Map<? extends K,? extends V> map)   //插入指定的Map键值对
>V	get(Object key)  //得到指定key对应的value值
>V remove(Object key) //删除指定的k，并返回value
>V replace(K key,V value)  //key匹配时，
>V replace(K key,V value,V oldValue) //key和value同时匹配
>int size() //返回集合大小
>
>
>  
>void forEach(BiConsumer<? super K,? super V> action)
>void	replaceAll(BiFunction<? super K,? super V,? extends V> function)
>```
>
>

### 2. TreeMap源码解析

>```
>
>```
>
>TreeMap是根据红黑树来实现。其他的函数都是根据红黑树的基础来实现，因此如果想深入了解里面的函数，最好还是看看红黑树是什么。

### 3. TreeMap遍历方式

>### 1. 按照正序遍历
>
>>**1. 遍历TreeMap的键值对**
>>
>>第一步：根据entrySet()获取TreeMap的“键值对”的Set集合。
>>第二步：通过Iterator迭代器遍历“第一步”得到的集合。
>>
>>```
>>// 假设map是TreeMap对象
>>// map中的key是String类型，value是Integer类型
>>Integer integ = null;
>>Iterator iter = map.entrySet().iterator();
>>while(iter.hasNext()) {
>>    Map.Entry entry = (Map.Entry)iter.next();
>>    // 获取key
>>    key = (String)entry.getKey();
>>        // 获取value
>>    integ = (Integer)entry.getValue();
>>}
>>```
>>
>>**2. 遍历TreeMap的键**
>>
>>第一步：根据keySet()获取TreeMap的“键”的Set集合。
>>
>>第二步：通过Iterator迭代器遍历“第一步”得到的集合。
>>
>>```
>>// 假设map是TreeMap对象
>>// map中的key是String类型，value是Integer类型
>>String key = null;
>>Integer integ = null;
>>Iterator iter = map.keySet().iterator();
>>while (iter.hasNext()) {
>>        // 获取key
>>    key = (String)iter.next();
>>        // 根据key，获取value
>>    integ = (Integer)map.get(key);
>>}
>>```
>>
>>**3. 遍历TreeMap的值**
>>
>>第一步：根据value()获取TreeMap的“值”的集合。
>>第二步：通过Iterator迭代器遍历“第一步”得到的集合。
>>
>>```
>>// 假设map是TreeMap对象
>>// map中的key是String类型，value是Integer类型
>>Integer value = null;
>>Collection c = map.values();
>>Iterator iter= c.iterator();
>>while (iter.hasNext()) {
>>    value = (Integer)iter.next();
>>}
>>```
>>
>>
>
>### 2. 按照逆序返回
>
>>**1. 按照逆序返回键值**
>>
>>第一步：根据descendingKeySet获取TreeMap的“值”的逆序集合。
>>第二步：通过Iterator迭代器遍历“第一步”得到的集合。
>>
>>```
>> Set<String> set = treeMap.descendingKeySet();
>>        Iterator<String> iterator = set.iterator();
>>        while (iterator.hasNext())
>>            iterator.next();
>>```
>>
>>**2. 按照逆序返回键值对**
>>
>>第一步：根据descendingMap获取TreeMap的NavigableMap。
>>
>>第二部：通过entrySet得到逆序的键值对集合。
>>
>>第二步：通过Iterator迭代器遍历“第一步”得到的集合。
>>
>>```
>> NavigableMap<String, Integer> nav = treeMap.descendingMap();
>>        Iterator<Map.Entry<String, Integer>> iterator = nav.entrySet().iterator();
>>        while (iterator.hasNext())
>>            iterator.next();
>>```
>>
>>
>
>````
>package Collections.cnblog.collection.map;
>
>import java.util.*;
>import java.util.function.Consumer;
>
>/**************************************
> *      Author : zhangke
> *      Date   : 2018/3/29 21:06
> *      Desc   : TreeMap 遍历
> ***************************************/
>public class TreeMapIteratortest {
>
>    public static void main(String[] args) {
>        TreeMap<String, Integer> treeMap = new TreeMap<>();
>        for (int i = 0; i < 10000; i++) {
>            treeMap.put(String.valueOf(i), i);
>        }
>        testTime((t) -> {
>            System.out.println("ByEntrySet");
>            iteratorByDescEntrySet(t);
>        }, treeMap);
>
>        testTime((t) -> {
>            System.out.println("ByKeySet");
>            iteratorByKeySet(t);
>        }, treeMap);
>
>        testTime((t) -> {
>            System.out.println("value");
>            iteratorByValue(t);
>        }, treeMap);
>        testTime((t) -> {
>            System.out.println("ByDescKeySet");
>            iteratorByDescKey(t);
>        }, treeMap);
>        testTime((t) -> {
>            System.out.println("ByDescEntrySet");
>            iteratorByDescEntrySet(t);
>        }, treeMap);
>
>
>    }
>
>    public static void testTime(Consumer<TreeMap<String, Integer>> c,
>                                TreeMap<String, Integer> l) {
>        long start = System.currentTimeMillis();
>        c.accept(l);
>        long end = System.currentTimeMillis();
>        System.out.println(end - start);
>    }
>
>    public static void iteratorByEntrySet(TreeMap<String, Integer> treeMap) {
>        Set<Map.Entry<String, Integer>> set = treeMap.entrySet();
>        Iterator<Map.Entry<String, Integer>> iterator = set.iterator();
>        while (iterator.hasNext())
>            iterator.next();
>
>    }
>
>    public static void iteratorByKeySet(TreeMap<String, Integer> treeMap) {
>
>        Set<String> set = treeMap.keySet();
>        Iterator<String> iterator = set.iterator();
>        while (iterator.hasNext())
>            iterator.next();
>    }
>
>    public static void iteratorByValue(TreeMap<String, Integer> treeMap) {
>        Collection<Integer> collection = treeMap.values();
>        Iterator<Integer> iterator = collection.iterator();
>        while (iterator.hasNext())
>            iterator.next();
>
>    }
>
>    public static void iteratorByDescKey(TreeMap<String, Integer> treeMap) {
>
>        Set<String> set = treeMap.descendingKeySet();
>        Iterator<String> iterator = set.iterator();
>        while (iterator.hasNext())
>            iterator.next();
>    }
>
>    public static void iteratorByDescEntrySet(TreeMap<String, Integer> treeMap) {
>        NavigableMap<String, Integer> nav = treeMap.descendingMap();
>        Iterator<Map.Entry<String, Integer>> iterator = nav.entrySet().iterator();
>        while (iterator.hasNext())
>            iterator.next();
>
>    }
>}
>````
>
>

### 4. TreeMap示例

>```java
>package Collections.cnblog.collection.map;
>
>import java.util.Iterator;
>import java.util.Map;
>import java.util.Random;
>import java.util.TreeMap;
>
>/**************************************
> *      Author : zhangke
> *      Date   : 2018/3/29 21:28
> *      Desc   : TreeMap常用API测试
> ***************************************/
>public class TreeMapTest {
>
>    public static void main(String[] args) {
>        testTreeMapAPI();
>        testNavigableMapAPIs();
>    }
>
>
>    /**
>     * Map常用API
>     */
>    public static void testTreeMapAPI() {
>
>        //初始化随机种子
>        Random r = new Random();
>
>        //新建TreeMap
>        TreeMap<String, Integer> treeMap = new TreeMap();
>
>        //添加操作
>        treeMap.put("one", r.nextInt(100));
>        treeMap.put("two", r.nextInt(100));
>        treeMap.put("three", r.nextInt(100));
>        treeMap.put(null, null);
>        System.out.println("API 测试");
>
>        // 打印出TreeMap
>        System.out.println(treeMap);
>
>        //通过Iterator遍历TreeMAp
>        Iterator iterator = treeMap.entrySet().iterator();
>        while (iterator.hasNext()) {
>            Map.Entry<String, Integer> entry = (Map.Entry) iterator.next();
>            System.out.println(entry.getKey() + " " + entry.getValue());
>
>        }
>
>
>        //TreeMAp的键值对个数
>        System.out.println("size:" + treeMap.size());
>
>        //containsKey(Object Key):是否包含key
>        System.out.println("contains key two:" + treeMap.containsKey("two"));
>        System.out.println("contains key five:" + treeMap.containsKey("five"));
>
>        //containsvalue(Object value）:是否包含值value
>        System.out.println("contains value 0:" + treeMap.containsValue(1));
>
>
>        //remove(Object Key)
>        treeMap.remove("three");
>
>        //清空TreeMap
>        treeMap.clear();
>        System.out.println("isEmpty:" + treeMap.isEmpty());
>
>    }
>
>    /**
>     * 测试导航函数
>     */
>    public static void testNavigableMapAPIs() {
>        // 新建TreeMap
>        TreeMap<String, Integer> treeMap = new TreeMap();
>        // 添加“键值对”
>        treeMap.put("a", 101);
>        treeMap.put("b", 102);
>        treeMap.put("c", 103);
>        treeMap.put("d", 104);
>        treeMap.put("e", 105);
>
>
>        //descendingKeySet :按照key值的逆序输出所有的键值
>        System.out.println("descendingKeySet：" + treeMap.descendingKeySet());
>
>        //descendingMap :按照key值逆序输出所有的键值对
>        System.out.println("descendingMap ： " + treeMap.descendingMap());
>
>        //获取key值最小的键值对
>        System.out.println("firstEntry ：" + treeMap.firstEntry());
>        System.out.println("firstKey" + treeMap.firstKey());
>
>        //返回最大的键值对
>        System.out.println("lastKey" + treeMap.lastKey());
>        System.out.println("lastEntry" + treeMap.lastEntry());
>
>        //返回比指定key值小于或等于的最大的key值
>        System.out.println("floorKey ：" + treeMap.floorKey("b"));
>        System.out.println("floorEntry ：" + treeMap.floorEntry("b"));
>
>        //ceilingEntry(K key) 返回比key值大或等于的key值中最小的键值对
>        System.out.println("ceilingEntry:" + treeMap.ceilingEntry("b"));
>
>        //ceilingKey(K key) 返回比key值大或等于的key值中最小的键值
>        System.out.println("ceilingKey:" + treeMap.ceilingKey("b"));
>
>
>        //返回严格大于指定key值的最小key值
>        System.out.println("higherEntry : " + treeMap.higherEntry("b"));
>        System.out.println("higherKey : " + treeMap.higherKey("b"));
>
>        //返回严格小于指定key值的键值对中最大的key值
>        System.out.println("lowerKey : " + treeMap.lowerKey("b"));
>        System.out.println("lowerEntry : " + treeMap.lowerEntry("b"));
>
>        //返回一个可导航的KeySet集合
>        System.out.println(treeMap.navigableKeySet());
>
>
>        // 测试 headMap(K toKey)  返回严格小于key值的集合,下面俩个结果一样
>        System.out.println("HeapMap");
>        System.out.println("HeadMap" + treeMap.headMap("c"));
>        System.out.println(treeMap.headMap("c", true));
>
>
>        //返回小于等于key值的集合
>        System.out.println(treeMap.headMap("c", false));
>
>        // 返回大于指定key值的集合
>        System.out.println("tailMap");
>        System.out.println(treeMap.tailMap("c"));
>        System.out.println(treeMap.tailMap("c", true));
>        // 返回大于或等于指定key值的集合
>
>        System.out.println(treeMap.tailMap("c", false));
>
>
>        //删除最小的Entry
>        System.out.println("pollFirstEntry :" + treeMap.pollFirstEntry());
>        //删除最大的Entry
>        System.out.println("pollLastEntry :" + treeMap.pollLastEntry());
>        System.out.println(treeMap);
>
>    }
>
>}
>```
>
>