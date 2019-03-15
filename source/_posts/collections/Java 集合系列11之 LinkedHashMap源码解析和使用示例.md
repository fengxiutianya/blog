abbrlink: 13
title: Java 集合系列11之 LinkedHashMap源码解析和使用示例
tags:
  - 集合
categories:
  - java
date: 2019-03-04 20:58:00
---
# 概要

>这一章主要针对LinkedHashMap进行学习
>
>1. LinkedHashMap 介绍
>2. LinkedHashMap 源码解析
>3. LinkedHashMap遍历方式
>4. LinkedHashMap 使用示例

<!-- more -->

### 1. LinkedHashMap 介绍

>LinkedHashMap 是一个散列表，存储的内容是键值对(key-value)映射。
>
>LinkedHashMap 继承HashMap，实现了Map,Serializable,Clonable接口。
>
>LinkedHashMap的继承关系
>
>```java
>java.lang.Object
> ↳ 	java.util.AbstractMap<K,V>
>		 ↳  java.util.HashMap<K,V>
>			   ↳ java.util.LinkedHashMap<K,V>
>public class LinkedHashMap<K,V>
>		extends HashMap<K,V>
>			implements Map<K,V>
>```
>
>
>
>LinkedHashMap不是线程安全的。但是LinkedHashMap的映射是有序的。key，value值都可以为空。
>
>LinkedHashMap 会可以保存键值对插入的顺序。
>
>LinkedHashMap 的实例有两个参数影响其性能：“初始容量” 和 “加载因子”。HashMap 的实例有两个参数影响其性能：“**初始容量**” 和 “**加载因子**”。容量 是哈希表中桶的数量，初始容量 只是哈希表在创建时的容量。加载因子 是哈希表在其容量自动增加之前可以达到多满的一种尺度。当哈希表中的条目数超出了加载因子与当前容量的乘积时，则要对该哈希表进行 rehash 操作（即重建内部数据结构），从而哈希表将具有大约两倍的桶数。
>通常，**默认加载因子是 0.75**, 这是在时间和空间成本上寻求一种折衷。加载因子过高虽然减少了空间开销，但同时也增加了查询成本（在大多数 HashMap 类的操作中，包括 get 和 put 操作，都反映了这一点）。在设置初始容量时应该考虑到映射中所需的条目数及其加载因子，以便最大限度地减少 rehash 操作次数。如果初始容量大于最大条目数除以加载因子，则不会发生 rehash 操作。
>
>LinkedHashMap的API
>
>```java
>//默认构造函数
>LinkedHashMap()
>
>//指定初始容量
>LinkedHashMap(int initialCapacity)
>
>// 指定初始容量和加载因子
>LinkedHashMap(int initialCapacity, float loadFactor)
>
>// 指定初始容量和加载因子，另外设置键值对的access顺序是否会影响排序，如果为true，则access时
>// 将此元素移动到链表的末尾
>LinkedHashMap(int initialCapacity, float loadFactor, boolean accessOrder)
>
>// 包含子Map的构造函数
>LinkedHashMap(Map<? extends K,? extends V> m)
>  
>  
>// 函数
>public void clear(); //清空集合
>public boolean containsValue(Object value) //是否包含指定的值
>public Set<Map.Entry<K,V>>	entrySet() //返回key-value的集合
>public V get(Object key) //返回指定的key对应的value，没有返回null
>public V getOrDefault(Object key, V defaultValue) //返回指定key下的value或者默认值
>public Set<K> keySet()   //返回集合中key的Set集合
>public Collection<V>	values() //返回集合中的value集合
>
>public Collection<V> values()  //返回集合的值的序列  
>  
>//java 8
>       //在集合所有的key-value对象上执行给定的操作
>public void	forEach(BiConsumer<? super K,? super V> action)
>  		// 使用给定的操作取代集合中所哟的元素，
>public void	replaceAll(BiFunction<? super K,? super V,? extends V> function)
>```
>
>
>
>

### 2. LinkedHashMap 源码解析

>一下是我基于1.8 来做的源码分析。
>
>```java
>package java.util;
>
>import java.util.function.Consumer;
>import java.util.function.BiConsumer;
>import java.util.function.BiFunction;
>import java.io.IOException;
>
>/**
> * LinkedHashMap 是一个有序的HashMap，是可以在双端进行操作
> * 但不是一个线程安全的集合。
> * 
> * LinkedHashMap的存储实现和HashMap一样。
> * LinkedHashMap 排序是按照下面方式实现的，存储是已经说了，这样存储是为了
> * 更快的查找。
> * 1. LinkedHashMap.Entry 增加了俩个属性before，after
> * 2. 在添加元素的时候，需要调用newNode 或者 newTreeNode 函数，
> * 3. 在函数里面，会将每一个节点进行关联，这样就保证了顺序。
> * 通俗的说，就是用HashMap的方式存储，但是在每个节点之间又保留了一条顺序链表线。
> * 
> * 当使用迭代器进行迭代时，就是用这条链表来进行迭代
> * 
> */
>public class LinkedHashMap<K, V> extends HashMap<K, V> implements Map<K, V> {
>
>    /**
>     * 是HashMap.Node 的子类，是为了进行正常的存储LinkedHashMap的节点
>     * 不过这个有点和Map.Entry混淆，但是因为以前版本的代码中使用了这个名字
>     * 所以为了使用java的软件进行不必要的修改，所以就不进行修改
>     * 
>     * HashMap.Node subclass for normal LinkedHashMap entries.
>     */
>    static class Entry<K, V> extends HashMap.Node<K, V> {
>        Entry<K, V> before, after;
>
>        Entry(int hash, K key, V value, Node<K, V> next) {
>            super(hash, key, value, next);
>        }
>    }
>
>    private static final long serialVersionUID = 3801124242820219131L;
>
>    /**
>     * 双向链表的头部节点
>     */
>    transient LinkedHashMap.Entry<K, V> head;
>
>    /**
>     * 双向链表的尾部节点
>     */
>    transient LinkedHashMap.Entry<K, V> tail;
>
>    /**
>     * 
>     * 链表的迭代顺序，是按照插入顺序还是按照接入的先后顺序
>     * 其中接入顺序：a先插入，后面修改a，则a就应该将位置排在最后。
>     * <tt>true</tt> for access-order,
>     * <tt>false</tt> for insertion-order.
>     *
>     * @serial
>     */
>    final boolean accessOrder;
>
>    // internal utilities
>
>    // 插入节点到尾部
>    private void linkNodeLast(LinkedHashMap.Entry<K, V> p) {
>        LinkedHashMap.Entry<K, V> last = tail;
>        tail = p;
>        if (last == null)
>            head = p;
>        else {
>            p.before = last;
>            last.after = p;
>        }
>    }
>
>    // 用dst节点取代src节点
>    private void transferLinks(LinkedHashMap.Entry<K, V> src, LinkedHashMap.Entry<K, V> dst) {
>        LinkedHashMap.Entry<K, V> b = dst.before = src.before;
>        LinkedHashMap.Entry<K, V> a = dst.after = src.after;
>        if (b == null)
>            head = dst;
>        else
>            b.after = dst;
>        if (a == null)
>            tail = dst;
>        else
>            a.before = dst;
>    }
>
>    // overrides of HashMap hook methods
>
>    void reinitialize() {
>        super.reinitialize();
>        head = tail = null;
>    }
>
>    //创建一个新节点，并将节点连接的末尾
>    Node<K, V> newNode(int hash, K key, V value, Node<K, V> e) {
>        LinkedHashMap.Entry<K, V> p = new LinkedHashMap.Entry<K, V>(hash, key, value, e);
>        linkNodeLast(p);
>        return p;
>    }
>
>    //取代节点
>    Node<K, V> replacementNode(Node<K, V> p, Node<K, V> next) {
>        LinkedHashMap.Entry<K, V> q = (LinkedHashMap.Entry<K, V>) p;
>        LinkedHashMap.Entry<K, V> t = new LinkedHashMap.Entry<K, V>(q.hash, q.key, q.value, next);
>        transferLinks(q, t);
>        return t;
>    }
>
>    //创建一个新的TreeNode
>    TreeNode<K, V> newTreeNode(int hash, K key, V value, Node<K, V> next) {
>        TreeNode<K, V> p = new TreeNode<K, V>(hash, key, value, next);
>        linkNodeLast(p);
>        return p;
>    }
>
>    //取代节点
>    TreeNode<K, V> replacementTreeNode(Node<K, V> p, Node<K, V> next) {
>        LinkedHashMap.Entry<K, V> q = (LinkedHashMap.Entry<K, V>) p;
>        TreeNode<K, V> t = new TreeNode<K, V>(q.hash, q.key, q.value, next);
>        transferLinks(q, t);
>        return t;
>    }
>
>    //删除节点e
>    void afterNodeRemoval(Node<K, V> e) { // unlink
>        LinkedHashMap.Entry<K, V> p = (LinkedHashMap.Entry<K, V>) e, b = p.before, a = p.after;
>        p.before = p.after = null;
>        if (b == null)
>            head = a;
>        else
>            b.after = a;
>        if (a == null)
>            tail = b;
>        else
>            a.before = b;
>    }
>
>    //在插入节点后，将节点一道最后
>    void afterNodeInsertion(boolean evict) { // possibly remove eldest
>        LinkedHashMap.Entry<K, V> first;
>        if (evict && (first = head) != null && removeEldestEntry(first)) {
>            K key = first.key;
>            removeNode(hash(key), key, null, false, true);
>        }
>    }
>
>    //将节点e移到最后
>    void afterNodeAccess(Node<K, V> e) { // move node to last
>        LinkedHashMap.Entry<K, V> last;
>        if (accessOrder && (last = tail) != e) {
>            LinkedHashMap.Entry<K, V> p = (LinkedHashMap.Entry<K, V>) e, b = p.before, a = p.after;
>            p.after = null;
>            if (b == null)
>                head = a;
>            else
>                b.after = a;
>            if (a != null)
>                a.before = b;
>            else
>                last = b;
>            if (last == null)
>                head = p;
>            else {
>                p.before = last;
>                last.after = p;
>            }
>            tail = p;
>            ++modCount;
>        }
>    }
>
>    //
>    void internalWriteEntries(java.io.ObjectOutputStream s) throws IOException {
>        for (LinkedHashMap.Entry<K, V> e = head; e != null; e = e.after) {
>            s.writeObject(e.key);
>            s.writeObject(e.value);
>        }
>    }
>
>    public LinkedHashMap(int initialCapacity, float loadFactor) {
>        super(initialCapacity, loadFactor);
>        accessOrder = false;
>    }
>
>    public LinkedHashMap(int initialCapacity) {
>        super(initialCapacity);
>        accessOrder = false;
>    }
>
>    public LinkedHashMap() {
>        super();
>        accessOrder = false;
>    }
>
>    public LinkedHashMap(Map<? extends K, ? extends V> m) {
>        super();
>        accessOrder = false;
>        putMapEntries(m, false);
>    }
>
>    public LinkedHashMap(int initialCapacity, float loadFactor, boolean accessOrder) {
>        super(initialCapacity, loadFactor);
>        this.accessOrder = accessOrder;
>    }
>
>    /**
>     * 判断是否包含指定的值
>     */
>    public boolean containsValue(Object value) {
>        for (LinkedHashMap.Entry<K, V> e = head; e != null; e = e.after) {
>            V v = e.value;
>            if (v == value || (value != null && value.equals(v)))
>                return true;
>        }
>        return false;
>    }
>
>    /**
>     *返回特点key匹配的值，如果找不到返回null
>     */
>    public V get(Object key) {
>        Node<K, V> e;
>        if ((e = getNode(hash(key), key)) == null)
>            return null;
>        if (accessOrder)
>            afterNodeAccess(e);
>        return e.value;
>    }
>
>    /**
>     * 如果找不到key对应的键值对则返回defaultValue
>     */
>    public V getOrDefault(Object key, V defaultValue) {
>        Node<K, V> e;
>        if ((e = getNode(hash(key), key)) == null)
>            return defaultValue;
>        if (accessOrder)
>            afterNodeAccess(e);
>        return e.value;
>    }
>
>    /**
>     * 清空，但是节点没有被立即回收
>     */
>    public void clear() {
>        super.clear();
>        head = tail = null;
>    }
>
>    /**
>     * 用于判断是否删除链表中插入最早的元素，
>     * 此函数可以帮助LinkedHashMap来实现缓存队列
>     */
>    protected boolean removeEldestEntry(Map.Entry<K, V> eldest) {
>        return false;
>    }
>
>    public Set<K> keySet() {
>        Set<K> ks = keySet;
>        if (ks == null) {
>            ks = new LinkedKeySet();
>            keySet = ks;
>        }
>        return ks;
>    }
>
>    final class LinkedKeySet extends AbstractSet<K> {
>        public final int size() {
>            return size;
>        }
>
>        public final void clear() {
>            LinkedHashMap.this.clear();
>        }
>
>        public final Iterator<K> iterator() {
>            return new LinkedKeyIterator();
>        }
>
>        public final boolean contains(Object o) {
>            return containsKey(o);
>        }
>
>        public final boolean remove(Object key) {
>            return removeNode(hash(key), key, null, false, true) != null;
>        }
>
>        public final Spliterator<K> spliterator() {
>            return Spliterators.spliterator(this, Spliterator.SIZED | Spliterator.ORDERED | Spliterator.DISTINCT);
>        }
>
>        public final void forEach(Consumer<? super K> action) {
>            if (action == null)
>                throw new NullPointerException();
>            int mc = modCount;
>            for (LinkedHashMap.Entry<K, V> e = head; e != null; e = e.after)
>                action.accept(e.key);
>            if (modCount != mc)
>                throw new ConcurrentModificationException();
>        }
>    }
>
>    public Collection<V> values() {
>        Collection<V> vs = values;
>        if (vs == null) {
>            vs = new LinkedValues();
>            values = vs;
>        }
>        return vs;
>    }
>
>    final class LinkedValues extends AbstractCollection<V> {
>        public final int size() {
>            return size;
>        }
>
>        public final void clear() {
>            LinkedHashMap.this.clear();
>        }
>
>        public final Iterator<V> iterator() {
>            return new LinkedValueIterator();
>        }
>
>        public final boolean contains(Object o) {
>            return containsValue(o);
>        }
>
>        public final Spliterator<V> spliterator() {
>            return Spliterators.spliterator(this, Spliterator.SIZED | Spliterator.ORDERED);
>        }
>
>        public final void forEach(Consumer<? super V> action) {
>            if (action == null)
>                throw new NullPointerException();
>            int mc = modCount;
>            for (LinkedHashMap.Entry<K, V> e = head; e != null; e = e.after)
>                action.accept(e.value);
>            if (modCount != mc)
>                throw new ConcurrentModificationException();
>        }
>    }
>
>    public Set<Map.Entry<K, V>> entrySet() {
>        Set<Map.Entry<K, V>> es;
>        return (es = entrySet) == null ? (entrySet = new LinkedEntrySet()) : es;
>    }
>
>    final class LinkedEntrySet extends AbstractSet<Map.Entry<K, V>> {
>        public final int size() {
>            return size;
>        }
>
>        public final void clear() {
>            LinkedHashMap.this.clear();
>        }
>
>        public final Iterator<Map.Entry<K, V>> iterator() {
>            return new LinkedEntryIterator();
>        }
>
>        public final boolean contains(Object o) {
>            if (!(o instanceof Map.Entry))
>                return false;
>            Map.Entry<?, ?> e = (Map.Entry<?, ?>) o;
>            Object key = e.getKey();
>            Node<K, V> candidate = getNode(hash(key), key);
>            return candidate != null && candidate.equals(e);
>        }
>
>        public final boolean remove(Object o) {
>            if (o instanceof Map.Entry) {
>                Map.Entry<?, ?> e = (Map.Entry<?, ?>) o;
>                Object key = e.getKey();
>                Object value = e.getValue();
>                return removeNode(hash(key), key, value, true, true) != null;
>            }
>            return false;
>        }
>
>        public final Spliterator<Map.Entry<K, V>> spliterator() {
>            return Spliterators.spliterator(this, Spliterator.SIZED | Spliterator.ORDERED | Spliterator.DISTINCT);
>        }
>
>        public final void forEach(Consumer<? super Map.Entry<K, V>> action) {
>            if (action == null)
>                throw new NullPointerException();
>            int mc = modCount;
>            for (LinkedHashMap.Entry<K, V> e = head; e != null; e = e.after)
>                action.accept(e);
>            if (modCount != mc)
>                throw new ConcurrentModificationException();
>        }
>    }
>
>    // Map overrides
>
>    public void forEach(BiConsumer<? super K, ? super V> action) {
>        if (action == null)
>            throw new NullPointerException();
>        int mc = modCount;
>        for (LinkedHashMap.Entry<K, V> e = head; e != null; e = e.after)
>            action.accept(e.key, e.value);
>        if (modCount != mc)
>            throw new ConcurrentModificationException();
>    }
>
>    public void replaceAll(BiFunction<? super K, ? super V, ? extends V> function) {
>        if (function == null)
>            throw new NullPointerException();
>        int mc = modCount;
>        for (LinkedHashMap.Entry<K, V> e = head; e != null; e = e.after)
>            e.value = function.apply(e.key, e.value);
>        if (modCount != mc)
>            throw new ConcurrentModificationException();
>    }
>
>    // Iterators
>
>    abstract class LinkedHashIterator {
>        LinkedHashMap.Entry<K, V> next;
>        LinkedHashMap.Entry<K, V> current;
>        int expectedModCount;
>
>        LinkedHashIterator() {
>            next = head;
>            expectedModCount = modCount;
>            current = null;
>        }
>
>        public final boolean hasNext() {
>            return next != null;
>        }
>
>        final LinkedHashMap.Entry<K, V> nextNode() {
>            LinkedHashMap.Entry<K, V> e = next;
>            if (modCount != expectedModCount)
>                throw new ConcurrentModificationException();
>            if (e == null)
>                throw new NoSuchElementException();
>            current = e;
>            next = e.after;
>            return e;
>        }
>
>        public final void remove() {
>            Node<K, V> p = current;
>            if (p == null)
>                throw new IllegalStateException();
>            if (modCount != expectedModCount)
>                throw new ConcurrentModificationException();
>            current = null;
>            K key = p.key;
>            removeNode(hash(key), key, null, false, false);
>            expectedModCount = modCount;
>        }
>    }
>
>    final class LinkedKeyIterator extends LinkedHashIterator implements Iterator<K> {
>        public final K next() {
>            return nextNode().getKey();
>        }
>    }
>
>    final class LinkedValueIterator extends LinkedHashIterator implements Iterator<V> {
>        public final V next() {
>            return nextNode().value;
>        }
>    }
>
>    final class LinkedEntryIterator extends LinkedHashIterator implements Iterator<Map.Entry<K, V>> {
>        public final Map.Entry<K, V> next() {
>            return nextNode();
>        }
>    }
>
>}
>
>```
>
>说明：其实这段代码不是太难懂，前面已经介绍了HashMap，这段代码基本上和HashMap差不多。但是增加了保证节点顺序的实现，大体上如下
>
>LinkedHashMap的存储实现和HashMap一样，这样存储是为了 更快的查找。
>
>LinkedHashMap 排序是按照下面方式实现的，
>
>1.  LinkedHashMap.Entry 增加了俩个属性before，after
>2. 在添加元素的时候，需要调用newNode 或者 newTreeNode 函数，
>3. 在函数里面，会将每一个节点进行关联，这样就保证了顺序。
>
> 通俗的说，就是用HashMap的方式存储，但是在每个节点之间又保留了一条顺序链表线。
>
>

### 2. LinkedHashMap 遍历方式

>遍历就是会按照用户指定的顺序来进行输入，如果使用默认构造函数创建的LinkedHashMap，则输出就是按照插入的顺序，如果设置的是access，那么就会按照access顺序输出。这时上面介绍的所有节点保留的一条顺序链表线这时就可以保证顺序来输出。
>
>**遍历LinkedHashMap的键值对**
>
>第一步：**根据entrySet()获取HashMap的“键值对”的Set集合。**
>
>第二步：**通过Iterator迭代器遍历“第一步”得到的集合。**
>
>```java
>// 假设map是HashMap对象
>// map中的key是String类型，value是Integer类型
>Integer integ = null;
>Iterator iter = map.entrySet().iterator();
>while(iter.hasNext()) {
>    Map.Entry entry = (Map.Entry)iter.next();
>    // 获取key
>    key = (String)entry.getKey();
>        // 获取value
>    integ = (Integer)entry.getValue();
>}
>```
>
>**遍历LinkedHashMap的键**
>
>第一步：**根据keySet()获取LinkedHashMap的“键”的Set集合。**
>第二步：**通过Iterator迭代器遍历“第一步”得到的集合。**
>
>```
>// 假设map是HashMap对象
>// map中的key是String类型，value是Integer类型
>String key = null;
>Integer integ = null;
>Iterator iter = map.keySet().iterator();
>while (iter.hasNext()) {
>        // 获取key
>    key = (String)iter.next();
>        // 根据key，获取value
>    integ = (Integer)map.get(key);
>}
>```
>
>**遍历LinkedHashMap的值**
>
>第一步：**根据value()获取HashMap的“值”的集合。**
>第二步：**通过Iterator迭代器遍历“第一步”得到的集合**
>
>```
>// 假设map是LinkedHashMap对象
>// map中的key是String类型，value是Integer类型
>Integer value = null;
>Collection c = map.values();
>Iterator iter= c.iterator();
>while (iter.hasNext()) {
>    value = (Integer)iter.next();
>}
>```
>
>代码如下
>
>```Java
>import java.util.*;
>import java.util.function.Consumer;
>
>/**************************************
> *      Author : zhangke
> *      Date   : 2018/3/20 16:46
> *      Desc   : LinkedHashMap 遍历
> *
> *                  entrySet
> *                  keySet
> *                  values
> ***************************************/
>public class LinkedHashMapIterator {
>
>    public static void main(String[] args) {
>
>        LinkedHashMap linkedHashMap = new LinkedHashMap();
>        for (int i = 0; i < 10000; i++) {
>            linkedHashMap.put(String.valueOf(i), i);
>        }
>
>
>        testTime((t) -> {
>            System.out.println("ByKeySet");
>            LinkeHashMapByKeySet(t);
>        }, linkedHashMap);
>
>        testTime((t) -> {
>            System.out.println("ByEntrySet");
>            LinkeHashMapByEntrySet(t);
>        }, linkedHashMap);
>        
>        testTime((t) -> {
>            System.out.println("ByValues");
>            LinkeHashMapByValues(t);
>        }, linkedHashMap);
>
>    }
>
>    public static void testTime(Consumer<LinkedHashMap> c, LinkedHashMap l) {
>        long start = System.currentTimeMillis();
>        c.accept(l);
>        long end = System.currentTimeMillis();
>        System.out.println(end - start);
>    }
>
>    public static void LinkeHashMapByValues(LinkedHashMap<String, Integer> map) {
>        Collection<Integer> list = map.values();
>        Iterator<Integer> iterator = list.iterator();
>        while (iterator.hasNext())
>            iterator.next();
>    }
>
>    public static void LinkeHashMapByKeySet(LinkedHashMap<String, Integer> map) {
>        Set<String> list = map.keySet();
>        Iterator<String> iterator = list.iterator();
>        while (iterator.hasNext())
>            iterator.next();
>    }
>
>    public static void LinkeHashMapByEntrySet(LinkedHashMap<String, Integer> map) {
>        Set<Map.Entry<String, Integer>> list = map.entrySet();
>        Iterator<Map.Entry<String, Integer>> iterator = list.iterator();
>        while (iterator.hasNext())
>            iterator.next();
>    }
>}
>
>```
>
>

### 4. LinkedHashMap 使用示例

>```Java
>package Collections.cnblog.collection.map;
>
>import java.util.Iterator;
>import java.util.LinkedHashMap;
>import java.util.Map;
>
>/**************************************
> *      Author : zhangke
> *      Date   : 2018/3/26 17:10
> *      Desc   : 
> ***************************************/
>public class LinkedHashMapTest {
>
>    public static void main(String[] args) {
>        test();
>    }
>
>    public static void test() {
>        LinkedHashMap<Integer, Integer> map = new LinkedHashMap();
>
>        // 插入元素
>        map.put(1, 1);
>        map.put(2, 2);
>        map.put(3, 3);
>        map.put(4, 4);
>        // 打印出map
>        System.out.println("map:" + map);
>
>        // 通过Iterator遍历key-value
>        Iterator iter = map.entrySet().iterator();
>        while (iter.hasNext()) {
>            Map.Entry entry = (Map.Entry) iter.next();
>            System.out.println("next : " + entry.getKey() + " - " + entry.getValue());
>        }
>
>        // LinkedHashMap
>        System.out.println("size:" + map.size());
>
>        // containsKey(Object key) :是否包含键key
>        System.out.println("contains key two : " + map.containsKey(2));
>        System.out.println("contains key five : " + map.containsKey(6));
>
>        // containsValue(Object value) :是否包含值value
>        System.out.println("contains value 0 : " + map.containsValue(new Integer(0)));
>
>        // remove(Object key) ： 删除键key对应的键值对
>        map.remove(3);
>
>        System.out.println("map:" + map);
>
>        // clear() ： 清空LinkedHashMap
>        map.clear();
>
>        // isEmpty() : Hashtable是否为空
>        System.out.println((map.isEmpty() ? "map is empty" : "map is not empty"));
>    }
>}
>```
>
>

