---
abbrlink: 7
---
## 概要

本篇博客我们将继续学习集合框架。这一篇我们接着学习List的另一种实现类`LinkedList`。

主要内容

1. LinkedList介绍
2. Queue 介绍
3. Deque介绍
4. LinkedList数据结构
5. LinkedList源码分析
6. LinkedList遍历方式
7. LinkedList使用示例

## 1. LinkedList介绍

>LinkedList的类图如下
>
>![upload successful](../../../../../../../)
>
>LinkedList是一个继承于AbstractSequentialList双向链表。他可以被当做堆栈、队列和双端队列来使用。
>
>LinkedList实现了List接口，能对他进行队列操作。这个是因为。在LinkedList的默认实现时就是按照队列实现的。具体的看后面
>
>LinkedList是实现Deque接口，能对他进行双端队列操作。
>
>LinkedList 实现了Cloneable接口，即覆盖了函数clone()，能克隆。
>LinkedList 实现java.io.Serializable接口，这意味着LinkedList支持序列化，能通过序列化去传输。
>LinkedList 是非同步的。
>
>LinkedList本质是双向链表
>
>LinkedList包含三个比较重要的成员：**first、last和size**
>
>* first指向双向链表的表头。
>
>* last指向双向链表的尾部。
>
>* size是双向链表中节点的个数。

## 2. queue介绍

>这也可能是在java.util下面的集合框架中为数不多能用到queue接口的地点。实际上LinkedList本身没有实现queue，而是实现了Deque，而Deque继承了queue接口。
>
>Queue接口定义如下
>
>```Java
>public interface Queue<E> extends Collection<E> {
>}
>```
>
>Queue继承了Collection接口，因此Collection接口有的方法，queue都有，不过有下面一些是Queue自己特有的，都是为绕着队列来实现的。
>
>queue定义的API如下：
>
>```java
>  public abstract boolean add(E e) 在队列末尾插入元素
>  public abstract E element()  得到队列头部节点元素
>  public abstract boolean offer(E e) 插入节点到集合尾部
>  public abstract E peek()     返回集合头部节点
>  public abstract E poll()     返回并删除集合头部节点
>  public abstract E remove()   返回并删除集合头部节点
>  
>```
>
>上面六个方法，总结如下
>
>| 操作不成功时      | 抛出异常的方法   | 返回特定值得方法 |
>| ----------- | --------- | -------- |
>| **Insert**  | add(e)    | offer(e) |
>| **Remove**  | remove()  | poll()   |
>| **Examine** | element() | peek()   |

## 3. Deque介绍

>Deque是double ended queue的简写，就是双端队列的意思。可以在队列俩端进行操作。
>
>接口的定义如下
>
>```java
>public interface Deque<E> extends Queue<E> {
>  
>}
>```
>
>Deque接口自己独有的方法如下。
>
>```java 
>public abstract void addFirst(E e);  // 在队列的头部插入元素节点
>public abstract void addLast(E e)    // 在队列的尾部插入元素
>public abstract boolean offerFitrst(E e)// 在队列头部插入元素
>public abstract boolean offerLast(E e); //在队列的尾部插入元素
>public abstract E removeFirst();        //删除头部节点并返回元素
>public abstract E removeLast();        //删尾部节点并返回元素
>public abstract E pollFirst();       //删除并返回头部节点元素
>public abstract E pollLast();        //删除并返回尾部节点元素
>public abstract E getFirst();        //得到头部节点元素但不删除
>public abstract E getLast();         //得到尾部节点元素但不删除
>public abstract E peekFirst();        //得到头部节点元素但不删除
>public abstract E peekLast();         //得到尾部节点元素但不删除
>public abstract boolean removeFirstOccurrence(Object o); //检索第一个相等元素并返回
>public abstract boolean removeLastOccurrence(Object o); //检索最后一个相等元素并返回
>
>
>//stack 方法
>public abstract void push(E e)     //插入节点到此队列代表的栈头
>public abstract  E pop();          //删除并返回头部节点
>
>//集合方法
>boolean remove(Object o);
>boolean contains(Object o);
>public int size();
>Iterator<E> iterator();
>Iterator<E> descendingIterator();
>```
>
>对以上方法进行总结
>
>| 操作类型        | **First Element (Head)** |                 | Last Element (Tail) |                 |
>| ----------- | ------------------------ | --------------- | ------------------- | --------------- |
>| 是否抛出异常      | *Throws exception*       | *Special value* | *Throws exception*  | *Special value* |
>| **Insert**  | addFirst(e)              | offerFirst(e)   | addLast(e)          | offerLast(e)    |
>| **Remove**  | removeFirst()            | pollFirst()     | removeLast()        | pollLast()      |
>| **Examine** | getFirst()               | peekFirst()     | getLast()           | peekLast()      |
>
>但是我在阅读源代码的时候，没有发addFrist抛出异常的代码，希望大家能指出一下
>
>queue和Deque之间的对比
>
>| **Queue Method** | **Equivalent Deque Method** |
>| ---------------- | --------------------------- |
>| add(e)           | addLast(e)                  |
>| offer(e)         | offerLast(e)                |
>| remove()         | removeFirst()               |
>| poll()           | pollFirst()                 |
>| element()        | getFirst()                  |
>| peek()           | peekFirst()                 |
>
>对比stack和Deque方法
>
>| **Stack Method** | **Equivalent Deque Method** |
>| ---------------- | --------------------------- |
>| push(e)          | addFirst(e)                 |
>| pop()            | removeFirst()               |
>| peek()           | peekFirst()                 |
>
>通过以上对比，应该对queue和Dqueue有一个大体上的了解，写上面的内容只是为了熟悉一下方法，方便自己以后使用。也对整体有个了解。

## 4. LinkedList源码分析

还和前面一样，主要分析add，remove，get，Iterator和ListIterator。

首先介绍一下，比较重要的参数

```java
 //链表的长度
    transient int size = 0;

    /**
     * 指向链表的第一个节点
     *      初始化时定义如下:
     *            (first == null && last == null) ||
     *            (first.prev == null && first.item != null)
     */
    transient Node<E> first;

    /**
     * 指向链表的最后一个节点
     *          初始化时定义如下：
     *            (first == null && 
     *            (last.next == null && last.item != null)
     */
    transient Node<E> last;

 private static class Node<E> {
     	// 数据
        E item;
     	// 后继指针	
        Node<E> next;
     	// 前继指针
        Node<E> prev;

        Node(Node<E> prev, E element, Node<E> next) {
            this.item = element;
            this.next = next;
            this.prev = prev;
        }
    }
```

具体操作源码如下，将java8中新添加的流操作省略掉。实现还是比较简单，都是对链表的操作。

>```java
>package java.util;
>
>import java.util.function.Consumer;
>
>public class LinkedList<E> extends AbstractSequentialList<E>
>        implements List<E>, Deque<E>, Cloneable, java.io.Serializable {
>
>   
>
>    public LinkedList() {
>    }
>
>    //初始化链表，包含指定集合元素
>    public LinkedList(Collection<? extends E> c) {
>        this();
>        addAll(c);
>    }
>
>    //把元素插入到链表的头部
>    private void linkFirst(E e) {
>        final Node<E> f = first;
>        final Node<E> newNode = new Node<>(null, e, f);
>        first = newNode;
>        if (f == null)
>            last = newNode;
>        else
>            f.prev = newNode;
>        size++;
>        modCount++;
>    }
>
>    //把元素插入到链表的尾部
>    void linkLast(E e) {
>        final Node<E> l = last;
>        final Node<E> newNode = new Node<>(l, e, null);
>        last = newNode;
>        if (l == null)
>            first = newNode;
>        else
>            l.next = newNode;
>        size++;
>        modCount++;
>    }
>
>    //在一个非空节点之前插入元素
>    void linkBefore(E e, Node<E> succ) {
>
>        final Node<E> pred = succ.prev;
>        final Node<E> newNode = new Node<>(pred, e, succ);
>        succ.prev = newNode;
>        if (pred == null)
>            first = newNode;
>        else
>            pred.next = newNode;
>        size++;
>        modCount++;
>    }
>
>    //删除List的第一个非空节点
>    private E unlinkFirst(Node<E> f) {
>        final E element = f.item;
>        final Node<E> next = f.next;
>        f.item = null;
>        f.next = null; // help GC
>        first = next;
>        if (next == null)
>            last = null;
>        else
>            next.prev = null;
>        size--;
>        modCount++;
>        return element;
>    }
>
>    //删除List的最后一个非空节点
>    private E unlinkLast(Node<E> l) {
>
>        final E element = l.item;
>        final Node<E> prev = l.prev;
>        l.item = null;
>        l.prev = null; // help GC
>        last = prev;
>        if (prev == null)
>            first = null;
>        else
>            prev.next = null;
>        size--;
>        modCount++;
>        return element;
>    }
>
>    //删除一个非空节点
>    E unlink(Node<E> x) {
>
>        final E element = x.item;
>        final Node<E> next = x.next;
>        final Node<E> prev = x.prev;
>
>        if (prev == null) {
>            first = next;
>        } else {
>            prev.next = next;
>            x.prev = null;
>        }
>
>        if (next == null) {
>            last = prev;
>        } else {
>            next.prev = prev;
>            x.next = null;
>        }
>
>        x.item = null;
>        size--;
>        modCount++;
>        return element;
>    }
>
>    //得到第一个元素
>    public E getFirst() {
>        final Node<E> f = first;
>        if (f == null)
>            throw new NoSuchElementException();
>        return f.item;
>    }
>
>    //返回最后一个元素
>    public E getLast() {
>        final Node<E> l = last;
>        if (l == null)
>            throw new NoSuchElementException();
>        return l.item;
>    }
>
>    //删除并返回第一个元素
>    public E removeFirst() {
>        final Node<E> f = first;
>        if (f == null)
>            throw new NoSuchElementException();
>        return unlinkFirst(f);
>    }
>
>    //删除并返回最后一个元素
>    public E removeLast() {
>        final Node<E> l = last;
>        if (l == null)
>            throw new NoSuchElementException();
>        return unlinkLast(l);
>    }
>
>    //插入元素到第一个位置
>    public void addFirst(E e) {
>        linkFirst(e);
>    }
>
>    //添加元素到最后一个位置
>    public void addLast(E e) {
>        linkLast(e);
>    }
>
>    //判断集合中是否包含指定的元素
>    public boolean contains(Object o) {
>        return indexOf(o) != -1;
>    }
>
>    //返回刺激和的大小
>    public int size() {
>        return size;
>    }
>
>    //添加元素到集合末尾
>    public boolean add(E e) {
>        linkLast(e);
>        return true;
>    }
>
>    //移除和指定元素相等的集合元素，如果包含多个，也是只删除一个
>    public boolean remove(Object o) {
>        if (o == null) {
>            for (Node<E> x = first; x != null; x = x.next) {
>                if (x.item == null) {
>                    unlink(x);
>                    return true;
>                }
>            }
>        } else {
>            for (Node<E> x = first; x != null; x = x.next) {
>                if (o.equals(x.item)) {
>                    unlink(x);
>                    return true;
>                }
>            }
>        }
>        return false;
>    }
>
>    //添加集合c到此集合的末尾
>    public boolean addAll(Collection<? extends E> c) {
>        return addAll(size, c);
>    }
>
>    //从指定位置开始插入集合c到此集合末尾
>    public boolean addAll(int index, Collection<? extends E> c) {
>        checkPositionIndex(index); //检查插入位置是否合适
>
>        Object[] a = c.toArray(); //得到此集合对应的数组
>        int numNew = a.length;
>        if (numNew == 0) //判断集合是否为空
>            return false;
>
>        Node<E> pred, succ;
>        if (index == size) {
>            succ = null;
>            pred = last;
>        } else {
>            succ = node(index);
>            pred = succ.prev;
>        }
>
>        //将插入的集合c连接成链表
>        for (Object o : a) {
>            @SuppressWarnings("unchecked")
>            E e = (E) o;
>            Node<E> newNode = new Node<>(pred, e, null);
>            if (pred == null)
>                first = newNode;
>            else
>                pred.next = newNode;
>            pred = newNode;
>        }
>        //将插进来的集合链接到此集合上
>        if (succ == null) {
>            last = pred;
>        } else {
>            pred.next = succ;
>            succ.prev = pred;
>        }
>
>        size += numNew;
>        modCount++;
>        return true;
>    }
>
>    //删除所有的元素
>    public void clear() {
>        for (Node<E> x = first; x != null;) {
>            Node<E> next = x.next;
>            x.item = null;
>            x.next = null;
>            x.prev = null;
>            x = next;
>        }
>        first = last = null;
>        size = 0;
>        modCount++;
>    }
>
>    // 在指定位置进行操作
>
>    //返回指定位置的元素
>    public E get(int index) {
>        checkElementIndex(index);
>        return node(index).item;
>    }
>
>    //在指定的位置替换元素，并返回旧值
>    public E set(int index, E element) {
>        checkElementIndex(index);
>        Node<E> x = node(index);
>        E oldVal = x.item;
>        x.item = element;
>        return oldVal;
>    }
>
>    //在指定的位置插入元素
>    public void add(int index, E element) {
>        checkPositionIndex(index);
>
>        if (index == size)
>            linkLast(element);
>        else
>            linkBefore(element, node(index));
>    }
>
>    //删除指定位置的元素
>    public E remove(int index) {
>        checkElementIndex(index);
>        return unlink(node(index));
>    }
>
>    //判断当前位置是否存在元素
>    private boolean isElementIndex(int index) {
>        return index >= 0 && index < size;
>    }
>
>    //告诉迭代器或者插入操作，当前位置是否可以进行操作
>    private boolean isPositionIndex(int index) {
>        return index >= 0 && index <= size;
>    }
>
>    //创建抛出超出索引异常的模板信息
>    private String outOfBoundsMsg(int index) {
>        return "Index: " + index + ", Size: " + size;
>    }
>
>    //检查索引是否存在元素
>    private void checkElementIndex(int index) {
>        if (!isElementIndex(index))
>            throw new IndexOutOfBoundsException(outOfBoundsMsg(index));
>    }
>
>    //检查当前位置是否可以操作
>    private void checkPositionIndex(int index) {
>        if (!isPositionIndex(index))
>            throw new IndexOutOfBoundsException(outOfBoundsMsg(index));
>    }
>
>    //返回非空指定索引位置的节点
>    Node<E> node(int index) {
>
>        if (index < (size >> 1)) {
>            Node<E> x = first;
>            for (int i = 0; i < index; i++)
>                x = x.next;
>            return x;
>        } else {
>            Node<E> x = last;
>            for (int i = size - 1; i > index; i--)
>                x = x.prev;
>            return x;
>        }
>    }
>
>    //查询操作
>
>    //返回和查找元素匹配的第一个存在的元素的索引
>    public int indexOf(Object o) {
>        int index = 0;
>        if (o == null) {
>            for (Node<E> x = first; x != null; x = x.next) {
>                if (x.item == null)
>                    return index;
>                index++;
>            }
>        } else {
>            for (Node<E> x = first; x != null; x = x.next) {
>                if (o.equals(x.item))
>                    return index;
>                index++;
>            }
>        }
>        return -1;
>    }
>
>    //返回和查找元素匹配的最后一个存在的元素的索引
>    public int lastIndexOf(Object o) {
>        int index = size;
>        if (o == null) {
>            for (Node<E> x = last; x != null; x = x.prev) {
>                index--;
>                if (x.item == null)
>                    return index;
>            }
>        } else {
>            for (Node<E> x = last; x != null; x = x.prev) {
>                index--;
>                if (o.equals(x.item))
>                    return index;
>            }
>        }
>        return -1;
>    }
>
>    // 队列操作
>
>    //返回头结点，但不删除
>    public E peek() {
>        final Node<E> f = first;
>        return (f == null) ? null : f.item;
>    }
>
>    //返回头结点，但不删除
>    public E element() {
>        return getFirst();
>    }
>
>    //返回头结点并移除
>    public E poll() {
>        final Node<E> f = first;
>        return (f == null) ? null : unlinkFirst(f);
>    }
>
>    //删除头结点并返回
>    public E remove() {
>        return removeFirst();
>    }
>
>    //添加指定元素在集合末尾
>    public boolean offer(E e) {
>        return add(e);
>    }
>
>    // 双端队列操作
>
>    //在集合头部插入元素
>    public boolean offerFirst(E e) {
>        addFirst(e);
>        return true;
>    }
>
>    //在集合尾部插入元素
>    public boolean offerLast(E e) {
>        addLast(e);
>        return true;
>    }
>
>    //得到集合第一个元素
>    public E peekFirst() {
>        final Node<E> f = first;
>        return (f == null) ? null : f.item;
>    }
>
>    //得到集合最后一个元素但不删除
>    public E peekLast() {
>        final Node<E> l = last;
>        return (l == null) ? null : l.item;
>    }
>
>    //得到并移除第一个元素
>    public E pollFirst() {
>        final Node<E> f = first;
>        return (f == null) ? null : unlinkFirst(f);
>    }
>
>    //得到并移除最后一个元素
>    public E pollLast() {
>        final Node<E> l = last;
>        return (l == null) ? null : unlinkLast(l);
>    }
>
>    //在集合头部插入元素
>    public void push(E e) {
>        addFirst(e);
>    }
>
>    //得到并删除第一个元素 ，如果为空抛出异常
>    public E pop() {
>        return removeFirst();
>    }
>
>    //删除第一个和o对象相等的元素
>    public boolean removeFirstOccurrence(Object o) {
>        return remove(o);
>    }
>
>    //删除最后一个和o对象相等的元素
>    public boolean removeLastOccurrence(Object o) {
>        if (o == null) {
>            for (Node<E> x = last; x != null; x = x.prev) {
>                if (x.item == null) {
>                    unlink(x);
>                    return true;
>                }
>            }
>        } else {
>            for (Node<E> x = last; x != null; x = x.prev) {
>                if (o.equals(x.item)) {
>                    unlink(x);
>                    return true;
>                }
>            }
>        }
>        return false;
>    }
>
>    //返回冲指定位置开始的listIterator 抛出异常
>    public ListIterator<E> listIterator(int index) {
>        checkPositionIndex(index);
>        return new ListItr(index);
>    }
>
>    // 实现ListIterator接口
>    private class ListItr implements ListIterator<E> {
>        private Node<E> lastReturned; //上一次返回的索引
>        private Node<E> next; //后继指针
>        private int nextIndex; //指向的索引
>        private int expectedModCount = modCount; //当前遍历时，List的大小
>
>        //根据指定的索引位置 创建ListIterator对象
>        //即next指向当前索引的对象
>        ListItr(int index) {
>
>            next = (index == size) ? null : node(index);
>            nextIndex = index;
>        }
>
>        //判断当前索引是否小于List的长度
>        public boolean hasNext() {
>            return nextIndex < size;
>        }
>
>        //返回当前元素
>        public E next() {
>            checkForComodification();
>            if (!hasNext())
>                throw new NoSuchElementException();
>
>            lastReturned = next;
>            next = next.next;
>            nextIndex++;
>            return lastReturned.item;
>        }
>
>        //判断当前节点是否有还有前继节点
>        public boolean hasPrevious() {
>            return nextIndex > 0;
>        }
>
>        //返回当前节点的前继节点
>        public E previous() {
>            checkForComodification();
>            if (!hasPrevious())
>                throw new NoSuchElementException();
>
>            lastReturned = next = (next == null) ? last : next.prev;
>            nextIndex--;
>            return lastReturned.item;
>        }
>
>        //返回后继节点的索引
>        public int nextIndex() {
>            return nextIndex;
>        }
>
>        //返回前继节点的索引
>        public int previousIndex() {
>            return nextIndex - 1;
>        }
>
>        //移除当前元素
>        public void remove() {
>            checkForComodification();
>            if (lastReturned == null)
>                throw new IllegalStateException();
>
>            Node<E> lastNext = lastReturned.next;
>            unlink(lastReturned);
>            if (next == lastReturned)
>                next = lastNext;
>            else
>                nextIndex--;
>            lastReturned = null;
>            expectedModCount++; //++的原因是：在List中每一次改变集合的操作，都会是modCount加一，这些操作包括修改，删除，添加
>        }
>
>        //替换当前元素
>        public void set(E e) {
>            if (lastReturned == null)
>                throw new IllegalStateException();
>            checkForComodification();
>            lastReturned.item = e;
>        }
>
>        //在末尾添加元素
>        public void add(E e) {
>            checkForComodification();
>            lastReturned = null;
>            if (next == null)
>                linkLast(e);
>            else
>                linkBefore(e, next);
>            nextIndex++;
>            expectedModCount++;
>        }
>
>        public void forEachRemaining(Consumer<? super E> action) {
>            Objects.requireNonNull(action);
>            while (modCount == expectedModCount && nextIndex < size) {
>                action.accept(next.item);
>                lastReturned = next;
>                next = next.next;
>                nextIndex++;
>            }
>            checkForComodification();
>        }
>
>        final void checkForComodification() {
>            if (modCount != expectedModCount)
>                throw new ConcurrentModificationException();
>        }
>    }
>
>    private static class Node<E> {
>        E item;
>        Node<E> next;
>        Node<E> prev;
>
>        Node(Node<E> prev, E element, Node<E> next) {
>            this.item = element;
>            this.next = next;
>            this.prev = prev;
>        }
>    }
>
>    //逆序返回ListIterator
>    public Iterator<E> descendingIterator() {
>        return new DescendingIterator();
>    }
>
>    //实现逆序返回Iterator
>    private class DescendingIterator implements Iterator<E> {
>        private final ListItr itr = new ListItr(size());
>
>        public boolean hasNext() {
>            return itr.hasPrevious();
>        }
>
>        public E next() {
>            return itr.previous();
>        }
>
>        public void remove() {
>            itr.remove();
>        }
>    }
>
>    @SuppressWarnings("unchecked")
>    private LinkedList<E> superClone() {
>        try {
>            return (LinkedList<E>) super.clone();
>        } catch (CloneNotSupportedException e) {
>            throw new InternalError(e);
>        }
>    }
>
>    //返回一个浅拷贝LinkedList对象
>    public Object clone() {
>        LinkedList<E> clone = superClone();
>
>        // Put clone into "virgin" state
>        clone.first = clone.last = null;
>        clone.size = 0;
>        clone.modCount = 0;
>
>        // Initialize clone with our elements
>        for (Node<E> x = first; x != null; x = x.next)
>            clone.add(x.item);
>
>        return clone;
>    }
>```
>
>总结：
>
>1. LinkedList实际上是通过双向链表实现。它包含了一个内部类Node，用于封装节点信息。
>2. 由于使用的链表，所以不会存在容量不足的问题。
>3. LinkedList的克隆函数，是将全部元素克隆到一个新的LinkedList对象中。不过集合中的对象有可能指向的是相同的地址。
>4. LinkedList实现java.io.Serializable。当写入到输出流时，先写入“容量”，再依次写入“每一个节点保护的值”；当读出输入流时，先读取“容量”，再依次读取“每一个元素”。
>5.  由于LinkedList实现了Deque，而Deque接口定义了在双端队列两端访问元素的方法。提供插入、移除和检查元素的方法。每种方法都存在两种形式：一种形式在操作失败时抛出异常，另一种形式返回一个特殊值（null 或 false，具体取决于操作）。
>
>

### LinkedList遍历方式

>LinkedList支持多种遍历方式。建议不要采用随机访问的方式去遍历LinkedList，而采用逐个遍历的方式。
>(01) 第一种，通过**迭代器**遍历。即通过Iterator去遍历。
>
>```
>for(Iterator iter = list.iterator(); iter.hasNext();)
>    iter.next();
>```
>
>(02) 通过**快速随机**访问遍历LinkedList
>
>```
>int size = list.size();
>for (int i=0; i<size; i++) {
>    list.get(i);        
>}
>```
>
>(03) 通过**另外一种for循环**来遍历LinkedList
>
>```
>for (Integer integ:list) 
>    ;
>```
>
>(04) 通过**pollFirst()**来遍历LinkedList
>
>```
>while(list.pollFirst() != null)
>    ;
>```
>
>(05) 通过**pollLast()**来遍历LinkedList
>
>```
>while(list.pollLast() != null)
>    ;
>```
>
>(06) 通过**removeFirst()**来遍历LinkedList
>
>```
>try {
>    while(list.removeFirst() != null)
>        ;
>} catch (NoSuchElementException e) {
>}
>```
>
>(07) 通过**removeLast()**来遍历LinkedList
>
>```
>try {
>    while(list.removeLast() != null)
>        ;
>} catch (NoSuchElementException e) {
>}
>```
>
> 测试代码
>
>```java
>import java.util.Iterator;
>import java.util.LinkedList;
>import java.util.NoSuchElementException;
>
>/**************************************
> *      Author : zhangke
> *      Date   : 2018/1/31 19:05
> *      Desc   : 比较不同遍历类型的时间开销
> ***************************************/
>public class LinkedListVisit {
>
>    public static void main(String[] args) {
>        //通过迭代器遍历
>        iteratorLinkedListThruIterator(getLinkedList());
>
>        //通过随机访问遍历
>        iteratorLinkedListThruRan(getLinkedList());
>
>        //通过foreach遍历
>        iteratorLinkedListThruForeach(getLinkedList());
>
>        //通过revmoveFirst遍历
>        iteratorLinkedListThruRemoveFirst(getLinkedList());
>
>        //通过removeLast遍历
>        iteratorLinkedListThruRemoveLast(getLinkedList());
>
>        //通过pollFirst遍历
>        iteratorLinkedListThruPollFirst(getLinkedList());
>
>        //通过pollLast遍历
>        iteratorLinkedListThruPollLast(getLinkedList());
>    }
>
>    /**
>     * 创建一个LinkedList包含 10000个元素
>     *
>     * @return
>     */
>    private static LinkedList getLinkedList() {
>        LinkedList<Integer> list = new LinkedList<>();
>        for (int i = 0; i < 10000; i++) {
>            list.add(i);
>        }
>        return list;
>    }
>
>    /**
>     * 通过迭代器遍历LinkedList
>     */
>    private static void iteratorLinkedListThruIterator(LinkedList<Integer> list) {
>        if (list == null)
>            return;
>
>        //记录开始时间
>        long start = System.currentTimeMillis();
>        for (Iterator iter = list.iterator(); iter.hasNext(); )
>            iter.next();
>
>        //记录结束时间
>        long end = System.currentTimeMillis();
>        System.out.println("iteratorLinkedListThruIterator：" + (end - start));
>    }
>
>    /**
>     * 通过随机访问遍历LinkedList
>     */
>    private static void iteratorLinkedListThruRan(LinkedList<Integer> list) {
>        if (list == null)
>            return;
>
>        //记录开始时间
>        long start = System.currentTimeMillis();
>        for (int n = list.size(), i = 0; i < n; i++)
>            list.get(i);
>        //记录结束时间
>        long end = System.currentTimeMillis();
>        System.out.println("iteratorLinkedListThruRan：" + (end - start));
>    }
>
>    /**
>     * 通过foreach来遍历LinkedList
>     */
>    private static void iteratorLinkedListThruForeach(LinkedList<Integer> list) {
>        if (list == null)
>            return;
>
>        //记录开始时间
>        long start = System.currentTimeMillis();
>        for (Integer e : list)
>            ;
>        //记录结束时间
>        long end = System.currentTimeMillis();
>        System.out.println("iteratorLinkedListThruForeach：" + (end - start));
>    }
>
>    /**
>     * 通过pollFirst来遍历LinkedList
>     */
>    private static void iteratorLinkedListThruPollFirst(LinkedList<Integer> list) {
>        if (list == null)
>            return;
>
>        //记录开始时间
>        long start = System.currentTimeMillis();
>        while (list.pollLast() != null)
>            ;
>        //记录结束时间
>        long end = System.currentTimeMillis();
>        System.out.println("iteratorLinkedListThruPollFisrst：" + (end - start));
>    }
>
>    /**
>     * 通过pollLast来遍历LinkedList
>     */
>    private static void iteratorLinkedListThruPollLast(LinkedList<Integer> list) {
>        if (list == null)
>            return;
>
>        //记录开始时间
>        long start = System.currentTimeMillis();
>        while (list.pollLast() != null)
>            ;
>        //记录结束时间
>        long end = System.currentTimeMillis();
>        System.out.println("iteratorLinkedListThruPollLast：" + (end - start));
>    }
>
>    /**
>     * 通过removeFirst来遍历LinkedList
>     */
>    private static void iteratorLinkedListThruRemoveFirst(LinkedList<Integer> list) {
>        if (list == null)
>            return;
>
>        //记录开始时间
>        long start = System.currentTimeMillis();
>        try {
>            while (list.removeFirst() != null)
>                ;
>        } catch (NoSuchElementException e) {
>            //处理链表中没有此元素
>        }
>
>        //记录结束时间
>        long end = System.currentTimeMillis();
>        System.out.println("iteratorLinkedListThruRemoveFirst：" + (end - start));
>    }
>
>    /**
>     * 通过removeFirst来遍历LinkedList
>     */
>    private static void iteratorLinkedListThruRemoveLast(LinkedList<Integer> list) {
>        if (list == null)
>            return;
>
>        //记录开始时间
>        long start = System.currentTimeMillis();
>        try {
>            while (list.removeLast() != null)
>                ;
>        } catch (NoSuchElementException e) {
>            //处理链表中没有此元素
>        }
>
>        //记录结束时间
>        long end = System.currentTimeMillis();
>        System.out.println("iteratorLinkedListThruRemoveLast：" + (end - start));
>    }
>}
>
>```
>
>执行结果
>
>```
>iteratorLinkedListThruIterator：4
>iteratorLinkedListThruRan：4854
>iteratorLinkedListThruForeach：3
>iteratorLinkedListThruRemoveFirst：2
>iteratorLinkedListThruRemoveLast：1
>iteratorLinkedListThruPollFisrst：1
>iteratorLinkedListThruPollLast：1
>```
>
>我运行了很多次结果都会出现1的结果但是用纳秒又会使得数字很大，所以最后就用了上面的结果，遍历LinkedList，使用pollFirst或pollLast效率最高。但他们遍历时，则会删除原始数据；若是只读取，而不删除，应该使用foreach来遍历，而不是fori遍历。

### 6. 使用栈

>```java
>package Collections.cnblog.collection.list;
>
>import java.util.LinkedList;
>
>/**************************************
> *      Author : zhangke
> *      Date   : 2018/2/1 10:26
> *      Desc   : LinkedList API 简单使用
> ***************************************/
>public class SimpleUseLinkedList {
>
>    public static void main(String[] args) {
>        testLinkedListAPIs();
>        useLinkedFIFO();
>        useLinkedListAsFIFO();
>    }
>
>    /**
>     * 简单使用LinkedList中部分API
>     */
>    private static void testLinkedListAPIs() {
>        //新建一个LinkedList
>        LinkedList<String> list = new LinkedList<>();
>
>        //添加操作
>        list.add("1");
>        list.add("2");
>        list.add("3");
>
>        //将 4 添加到第一个位置
>        list.add(1, "4");
>        System.out.println("使用addFitst,removeFirst,getFirst");
>
>        //下面三个如果操作失败，则抛出异常
>
>        //将10 添加到第一个位置，失败的话，则抛出异常
>        list.addFirst("10");
>        System.out.println("list:" + list);
>
>        //将一个元素删除，失败的话，抛出异常
>        System.out.println("list.removeList" + list.removeFirst());
>
>        //获取第一个元素，失败的话，抛出异常
>        System.out.println("List.getFirst" + list.getFirst());
>
>        System.out.println("使用offerFirst，pollFirst,peekFirst");
>        //将10 添加到第一个位置，返回true
>        list.offerFirst("10");
>
>        System.out.println("list.offer" + list);
>
>        //将第一个元素删除，失败的话返回null
>        System.out.println("list.pollFirst" + list.pollFirst());
>        System.out.println("list：" + list);
>
>        //获取第一个元素，失败的话返回null
>        System.out.println("list.peekFirst" + list.peekFirst());
>
>        //下面三个添加元素到最后一个位置，失败的话，都会抛出异常
>        // (01) 将“20”添加到最后一个位置。  失败的话，抛出异常！
>        list.addLast("20");
>        System.out.println("llist:" + list);
>        // (02) 将最后一个元素删除。        失败的话，抛出异常！
>        System.out.println("llist.removeLast():" + list.removeLast());
>        System.out.println("llist:" + list);
>        // (03) 获取最后一个元素。          失败的话，抛出异常！
>        System.out.println("llist.getLast():" + list.getLast());
>
>        System.out.println("使用 offerLast(), pollLast(), peekLast()");
>        // (01) 将“20”添加到最后一个位置。  返回true。
>        list.offerLast("20");
>        System.out.println("llist:" + list);
>        // (02) 将最后一个元素删除。        失败的话，返回null。
>        System.out.println("llist.pollLast():" + list.pollLast());
>        System.out.println("llist:" + list);
>        // (03) 获取最后一个元素。          失败的话，返回null。
>        System.out.println("llist.peekLast():" + list.peekLast());
>
>
>        //不建议在LinkedList中使用下面俩个操作，因为效率低，需要进行检索
>        //替换元素
>        list.set(1, "10");
>        System.out.println(list.get(1));
>
>        //将LinkedList转换成数组
>        String[] arr = (String[]) list.toArray();
>        for (String s : arr)
>            System.out.println(s);
>        // 输出大小
>        System.out.println("size:" + list.size());
>        // 清空LinkedList
>        list.clear();
>        // 判断LinkedList是否为空
>        System.out.println("isEmpty():" + list.isEmpty() + "\n");
>    }
>
>    /**
>     * 将LinkedList当做LIFO（后进先出）的堆栈
>     */
>    private static void useLinkedFIFO() {
>        LinkedList<Integer> stack = new LinkedList<>();
>
>        //进栈
>        stack.push(1);
>        stack.push(2);
>
>        //打印栈
>        System.out.println(stack);
>
>        //删除栈顶元素
>        System.out.println("stack.pop:" + stack.pop());
>        // 取出“栈顶元素”
>        System.out.println("stack.peek():" + stack.peek());
>
>        // 打印“栈”
>        System.out.println("stack:" + stack);
>    }
>
>    /**
>     * 将LinkedList当作 FIFO(先进先出)的队列
>     */
>    private static void useLinkedListAsFIFO() {
>        System.out.println("\nuseLinkedListAsFIFO");
>        // 新建一个LinkedList
>        LinkedList queue = new LinkedList();
>
>        // 将10,20,30,40添加到队列。每次都是插入到末尾
>        queue.add("10");
>        queue.add("20");
>        queue.add("30");
>        queue.add("40");
>        // 打印“队列”
>        System.out.println("queue:" + queue);
>
>        // 删除(队列的第一个元素)
>        System.out.println("queue.remove():" + queue.remove());
>
>        // 读取(队列的第一个元素)
>        System.out.println("queue.element():" + queue.element());
>
>        // 打印“队列”
>        System.out.println("queue:" + queue);
>    }
>}
>```

