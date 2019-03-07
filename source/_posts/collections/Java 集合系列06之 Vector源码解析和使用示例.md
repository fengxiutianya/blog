---
abbrlink: 3
---
### **概要**

学完ArrayList和LinkedList，我们接着学习Vector。学习方式还是和之前一样，先对Vector有个整体认识，然后再学习它的源码；最后再通过实例来学会使用它。

1. Vector介绍
2. Vector数据结构
3. Vector源码解析
4. Vector遍历方式

### 1. Vector 介绍

>Vector 简介
>
>Vector 是**矢量队列**，它是JDK1.0版本添加的类。继承于AbstractList，实现了List, RandomAccess, Cloneable这些接口。
>Vector 继承了AbstractList，实现了List；所以，**它是一个队列，支持相关的添加、删除、修改、遍历等功能**。
>Vector 实现了RandmoAccess接口，即**提供了随机访问功能**。RandmoAccess是java中用来被List实现，为List提供快速访问功能的。在Vector中，我们即可以通过元素的序号快速获取元素对象；这就是快速随机访问。
>Vector 实现了Cloneable接口，即实现clone()函数。它能被克隆。
>
>和ArrayList的最大不同,vector 是线程安全的。保证线程安全使用synchronized发， 因此代价也会相当大的。
>
>Vector 的构造函数
>
>```java
>
>Vector共有4个构造函数
>// 默认构造函数
>Vector()
>
>// capacity是Vector的默认容量大小。当由于增加数据导致容量增加时，每次容量会增加一倍。
>Vector(int capacity)
>
>// capacity是Vector的默认容量大小，capacityIncrement是每次Vector容量增加时的增量值。
>Vector(int capacity, int capacityIncrement)
>
>// 创建一个包含collection的Vector
>Vector(Collection<? extends E> collection)
>```
>
>Vector的API:
>
>```java
>public synchronized void copyInto(Object[] anArray) //拷贝集合元素到数组
>public synchronized void trimToSize()   //缩短集合长度和实际元素数量相同
>public synchronized void ensureCapacity(int minCapacity)  //设置集合长度
>public synchronized int  capacity()  //返回集合容量
>public synchronized int size()    //返回集合元素数量
>public synchronized boolean isEmpty()  //判断集合是否为空
>public synchronized Enumeration<E> elements()
>  // 从指定位置开始搜索和对象o相同的元素索引
>public synchronized int indexOf(Object o, int index)
>  										
>// 返回最后一个和指定元素o匹配的对象索引
>public synchronized int lastIndexOf(Object o) 
>  										
>public synchronized E elementAt(int index) //返回指定索引地点的元素  
>public synchronized E firstElement() //返回第一个元素对象
>public synchronized E lastElement()  //返回最后一个元素对象  
>public synchronized void setElementAt(E obj, int index) // 替换指定位置的对象元素  
>public synchronized void removeElementAt(int index) // 删除指定位置的元素
>public synchronized void insertElementAt(E obj, int index) //在指定位置插入对象元素
>public synchronized void addElement(E obj) //添加元素到集合末尾  
>public synchronized boolean removeElement(Object obj) // 删除集合的第一个元素  
>public synchronized void removeAllElements()   //删除所有元素  
>public synchronized Object clone()  //对象clone  
>public synchronized Object[] toArray() // 返回包含所有元素的数组  
>public synchronized < T > T[] toArray(T[] a)   //返回集合中的所有元素到数组a中
>public synchronized E get(int index) //返回指定索引位置上的元素  
>public synchronized E set(int index, E element) //替换指定位置的元素  
>public synchronized boolean add(E e) //添加元素到集合的末尾  
>public synchronized E remove(int index) //删除指定位置的元素
>  //返回集合是否包含集合c中所有元素  
>public synchronized boolean containsAll(Collection<?> c) 
>  									
>public synchronized boolean addAll(Collection<? extends E> c) //添加集合c到vector的末尾  
>public synchronized  boolean removeAll(Collection<?> c) //删除集合所有集合c中包含的元素  
>public synchronized boolean retainAll(Collection<?> c) //仅保留集合c中由的元素
>  //在指定位置开始插入集合c中元素
>public synchronized boolean addAll(int index, Collection<? extends E> c) 
>  //判断此集合和o是否相同
>public synchronized boolean equals(Object o)
>public synchronized int hashCode()
>public synchronized List<E> subList(int fromIndex, int toIndex)
>public synchronized void removeRange(int fromIndex, int toIndex) 
>public synchronized ListIterator<E> listIterator(int index) 
>public synchronized ListIterator<E> listIterator()
>public synchronized Iterator<E> iterator()
>public boolean contains(Object o)  //是否包含此集合元素
>public int indexOf(Object o)  //返回第一次出现和指定元素相同的元素的索引
>public boolean remove(Object o)  //移除队首元素
>public void add(int index, E element) //在指定位置插入元素
>public void clear()  //清空所有的元素
>```
>
>
>
>

### 2. Vector数据结构

>![upload successful](/images/pasted-158.png)
>
>Vector的数据结构和ArrayList差不多，它包含了3个成员变量：elementData , elementCount， capacityIncrement。
>
>(01) elementData 是"Object[]类型的数组"，它保存了添加到Vector中的元素。elementData是个动态数组，如果初始化Vector时，没指定动态数组的>大小，则使用默认大小10。随着Vector中元素的增加，Vector的容量也会动态增长，capacityIncrement是与容量增长相关的增长系数，具体的增长方式，请参考源码分析中的ensureCapacity()函数。
>
>(02) elementCount 是动态数组的实际大小。
>
>(03) capacityIncrement 是动态数组的增长系数。如果在创建Vector时，指定了capacityIncrement的大小；则，每次当Vector中动态数组容量增加时，增加的大小都是capacityIncrement。

### 3. Vector 源码分析

```Java
package java.util;

import java.util.function.Consumer;
import java.util.function.Predicate;
import java.util.function.UnaryOperator;

/**
 * Vector 是一个动态数组，同时也是一个矢量队列
 * 是List的一种，只不过是因为是java 1就开始就添加进来，为了兼容之前的代码
 * 所以在有了集合类之后也没有删除。
 * 既然是List，那么他也具备List所有的特性，保证插入的顺序和输出的顺序相同
 * 
 * 和ArrayList的最大不同,vector 是线程安全的。保证线程安全使用synchronized发，
 * 因此代价也会相当大的。
 * 
 * 实现RandomAccess 接口说明此集合可以支持随机接入
 * 实现Cloneable    接口，说明此类支持克隆
 * 实现java.io.Serializable 接口，可以支持序列化
 */
public class Vector<E> extends AbstractList<E> implements List<E>, RandomAccess, Cloneable, java.io.Serializable {

    //存储集合元素的数组
    protected Object[] elementData;

    //集合的实际数量
    protected int elementCount;

    //当容量不足时，增加数组容量的大小
    protected int capacityIncrement;

    private static final long serialVersionUID = -2767605614048989439L;

    /**
     * 指定集合最初大小和集合动态增长的数量初始化vector对象
     *
     * @param   initialCapacity     vector最初的大小
     * @param   capacityIncrement   当集合容量不足时，增加多大的数组容量
     * @throws IllegalArgumentException 如果指定的初始容量是负数时。
     */
    public Vector(int initialCapacity, int capacityIncrement) {
        super();
        if (initialCapacity < 0)
            throw new IllegalArgumentException("Illegal Capacity: " + initialCapacity);
        this.elementData = new Object[initialCapacity];
        this.capacityIncrement = capacityIncrement;
    }

    /**
     * 指定最初容量来初始化Vector
     * 
     * @param   initialCapacity   vector最初的大小
     * @throws IllegalArgumentException 如果指定的最初容量是负数
     */
    public Vector(int initialCapacity) {
        this(initialCapacity, 0);
    }

    /**
     * 默认初始化vector，默认容量为10
     */
    public Vector() {
        this(10);
    }

    /**
     *利用一个现有的集合初始化Vector
     *
     * @param c 需要存储的集合
     * @throws NullPointerException 如果指定的集合为空
     * @since   1.2
     */
    public Vector(Collection<? extends E> c) {
        elementData = c.toArray();
        elementCount = elementData.length;
        // c.toArray 有可能返回的数组类型 和 Object[] 不匹配 
        if (elementData.getClass() != Object[].class)
            elementData = Arrays.copyOf(elementData, elementCount, Object[].class);
    }

    /**
     * 拷贝当前集合元素到指定的数组
     *
     */
    public synchronized void copyInto(Object[] anArray) {
        System.arraycopy(elementData, 0, anArray, 0, elementCount);
    }

    /**
     * 减少数组长度和实际元素长度相同
     */
    public synchronized void trimToSize() {
        modCount++;
        int oldCapacity = elementData.length;
        if (elementCount < oldCapacity) {
            elementData = Arrays.copyOf(elementData, elementCount);
        }
    }

    /**
     * 增加容量到指定的值
     * 这个函数式判断给定的值是否大于0 
     * 这样做是为了在synchronized中做尽量少的操作
     * 保证效率
     * 
     */
    public synchronized void ensureCapacity(int minCapacity) {
        if (minCapacity > 0) {
            modCount++;
            ensureCapacityHelper(minCapacity);
        }
    }

    /**
     * 确信容量大于包含元素的数量
     */
    private void ensureCapacityHelper(int minCapacity) {
        // overflow-conscious code
        if (minCapacity - elementData.length > 0)
            grow(minCapacity);
    }

    /**
     * 允许最大分配的值
     */
    private static final int MAX_ARRAY_SIZE = Integer.MAX_VALUE - 8;

    /**
     * 增长数组到指定的容量
     */
    private void grow(int minCapacity) {
        // overflow-conscious code
        int oldCapacity = elementData.length;
        int newCapacity = oldCapacity + ((capacityIncrement > 0) ? capacityIncrement : oldCapacity);
        if (newCapacity - minCapacity < 0)
            newCapacity = minCapacity;
        if (newCapacity - MAX_ARRAY_SIZE > 0)
            newCapacity = hugeCapacity(minCapacity);
        elementData = Arrays.copyOf(elementData, newCapacity);
    }

    /**
     * 如果指定的容量大于最大值，则设置容量为最大值
     */
    private static int hugeCapacity(int minCapacity) {
        if (minCapacity < 0) // overflow
            throw new OutOfMemoryError();
        return (minCapacity > MAX_ARRAY_SIZE) ? Integer.MAX_VALUE : MAX_ARRAY_SIZE;
    }

    /**
     * 设置集合的长度，如果大于集合元素的数量，则多余的数组空间为null值
     * 如果小于数组的长度，则把大于指定的长度的元素设置为null
     */
    public synchronized void setSize(int newSize) {
        modCount++;
        if (newSize > elementCount) {
            ensureCapacityHelper(newSize);
        } else {
            for (int i = newSize; i < elementCount; i++) {
                elementData[i] = null;
            }
        }
        elementCount = newSize;
    }

    /**
     * 返回当前vector的容量
     */
    public synchronized int capacity() {
        return elementData.length;
    }

    /**
     * 返回当前vector元素数量
     */
    public synchronized int size() {
        return elementCount;
    }

    /**
     * 判断vector是否为空
     */
    public synchronized boolean isEmpty() {
        return elementCount == 0;
    }

    /**
     * Returns an enumeration of the components of this vector. The
     * returned {@code Enumeration} object will generate all items in
     * this vector. The first item generated is the item at index {@code 0},
     * then the item at index {@code 1}, and so on.
     *
     * @return  an enumeration of the components of this vector
     * @see     Iterator
     */
    public Enumeration<E> elements() {
        return new Enumeration<E>() {
            int count = 0;

            public boolean hasMoreElements() {
                return count < elementCount;
            }

            public E nextElement() {
                synchronized (Vector.this) {
                    if (count < elementCount) {
                        return elementData(count++);
                    }
                }
                throw new NoSuchElementException("Vector Enumeration");
            }
        };
    }

    /**
     * 返回集合是否包含指定的元素
     */
    public boolean contains(Object o) {
        return indexOf(o, 0) >= 0;
    }

    /**
     * 返回第一次出现和指定元素相同的元素的索引
     */
    public int indexOf(Object o) {
        return indexOf(o, 0);
    }

    /**
     * 从指定位置开始搜索和对象o相同的元素索引
     */
    public synchronized int indexOf(Object o, int index) {
        if (o == null) {
            for (int i = index; i < elementCount; i++)
                if (elementData[i] == null)
                    return i;
        } else {
            for (int i = index; i < elementCount; i++)
                if (o.equals(elementData[i]))
                    return i;
        }
        return -1;
    }

    /**
     * 返回最后一个和指定元素o匹配的对象索引
     */
    public synchronized int lastIndexOf(Object o) {
        return lastIndexOf(o, elementCount - 1);
    }

    /**
     * 返回从指定位置开始和对象o匹配的元素索引
     */
    public synchronized int lastIndexOf(Object o, int index) {
        if (index >= elementCount)
            throw new IndexOutOfBoundsException(index + " >= " + elementCount);

        if (o == null) {
            for (int i = index; i >= 0; i--)
                if (elementData[i] == null)
                    return i;
        } else {
            for (int i = index; i >= 0; i--)
                if (o.equals(elementData[i]))
                    return i;
        }
        return -1;
    }

    /**
     * 返回指定索引地点的元素
     */
    public synchronized E elementAt(int index) {
        if (index >= elementCount) {
            throw new ArrayIndexOutOfBoundsException(index + " >= " + elementCount);
        }

        return elementData(index);
    }

    /**
     * 返回第一个元素对象
     */
    public synchronized E firstElement() {
        if (elementCount == 0) {
            throw new NoSuchElementException();
        }
        return elementData(0);
    }

    /**
     * 返回最后一个对象元素
     */
    public synchronized E lastElement() {
        if (elementCount == 0) {
            throw new NoSuchElementException();
        }
        return elementData(elementCount - 1);
    }

    /**
     * 替换指定位置的对象元素
     */
    public synchronized void setElementAt(E obj, int index) {
        if (index >= elementCount) {
            throw new ArrayIndexOutOfBoundsException(index + " >= " + elementCount);
        }
        elementData[index] = obj;
    }

    /**
     *删除指定位置的元素
     */
    public synchronized void removeElementAt(int index) {
        modCount++;
        if (index >= elementCount) {
            throw new ArrayIndexOutOfBoundsException(index + " >= " + elementCount);
        } else if (index < 0) {
            throw new ArrayIndexOutOfBoundsException(index);
        }
        int j = elementCount - index - 1;
        if (j > 0) {
            System.arraycopy(elementData, index + 1, elementData, index, j);
        }
        elementCount--;
        elementData[elementCount] = null; /* to let gc do its work */
    }

    /**
     * 在指定位置插入对象元素
     */
    public synchronized void insertElementAt(E obj, int index) {
        modCount++;
        if (index > elementCount) {
            throw new ArrayIndexOutOfBoundsException(index + " > " + elementCount);
        }
        ensureCapacityHelper(elementCount + 1);
        System.arraycopy(elementData, index, elementData, index + 1, elementCount - index);
        elementData[index] = obj;
        elementCount++;
    }

    /**
     * 添加元素到集合末尾
     */
    public synchronized void addElement(E obj) {
        modCount++;
        ensureCapacityHelper(elementCount + 1);
        elementData[elementCount++] = obj;
    }

    /**
     * 删除集合的第一个元素
     */
    public synchronized boolean removeElement(Object obj) {
        modCount++;
        int i = indexOf(obj);
        if (i >= 0) {
            removeElementAt(i);
            return true;
        }
        return false;
    }

    /**
     * 删除所有元素
     */
    public synchronized void removeAllElements() {
        modCount++;
        // Let gc do its work
        for (int i = 0; i < elementCount; i++)
            elementData[i] = null;

        elementCount = 0;
    }

    /**
     * 返回一个克隆对象
     */
    public synchronized Object clone() {
        try {
            @SuppressWarnings("unchecked")
            Vector<E> v = (Vector<E>) super.clone();
            v.elementData = Arrays.copyOf(elementData, elementCount);
            v.modCount = 0;
            return v;
        } catch (CloneNotSupportedException e) {
            // this shouldn't happen, since we are Cloneable
            throw new InternalError(e);
        }
    }

    /**
     * 返回包含所有元素的数组
     */
    public synchronized Object[] toArray() {
        return Arrays.copyOf(elementData, elementCount);
    }

    /**
     * 返回集合中的所有元素到数组a中
     */
    @SuppressWarnings("unchecked")
    public synchronized <T> T[] toArray(T[] a) {
        if (a.length < elementCount)
            return (T[]) Arrays.copyOf(elementData, elementCount, a.getClass());

        System.arraycopy(elementData, 0, a, 0, elementCount);

        if (a.length > elementCount)
            a[elementCount] = null;

        return a;
    }

    // 位置操作

    //返回指定索引位置上的元素
    @SuppressWarnings("unchecked")
    E elementData(int index) {
        return (E) elementData[index];
    }

    /**
     * 返回指定索引位置上的元素
     */
    public synchronized E get(int index) {
        if (index >= elementCount)
            throw new ArrayIndexOutOfBoundsException(index);

        return elementData(index);
    }

    /**
     * 替换指定位置的元素
     */
    public synchronized E set(int index, E element) {
        if (index >= elementCount)
            throw new ArrayIndexOutOfBoundsException(index);

        E oldValue = elementData(index);
        elementData[index] = element;
        return oldValue;
    }

    /**
     * 添加元素到集合的末尾
     */
    public synchronized boolean add(E e) {
        modCount++;
        ensureCapacityHelper(elementCount + 1);
        elementData[elementCount++] = e;
        return true;
    }

    /**
     * 移除队首元素
     */
    public boolean remove(Object o) {
        return removeElement(o);
    }

    /**
     * 插入元素到指定位置
     */
    public void add(int index, E element) {
        insertElementAt(element, index);
    }

    /**
     * 删除指定位置的元素
     */
    public synchronized E remove(int index) {
        modCount++;
        if (index >= elementCount)
            throw new ArrayIndexOutOfBoundsException(index);
        E oldValue = elementData(index);

        int numMoved = elementCount - index - 1;
        if (numMoved > 0)
            System.arraycopy(elementData, index + 1, elementData, index, numMoved);
        elementData[--elementCount] = null; // Let gc do its work

        return oldValue;
    }

    /**
     * 清空所有的元素
     */
    public void clear() {
        removeAllElements();
    }

    // 批量操作

    /**
     * 返回集合是否包含集合c中所有元素
     */
    public synchronized boolean containsAll(Collection<?> c) {
        return super.containsAll(c);
    }

    /**
     * 添加集合c到vector的末尾
     */
    public synchronized boolean addAll(Collection<? extends E> c) {
        modCount++;
        Object[] a = c.toArray();
        int numNew = a.length;
        ensureCapacityHelper(elementCount + numNew);
        System.arraycopy(a, 0, elementData, elementCount, numNew);
        elementCount += numNew;
        return numNew != 0;
    }

    /**
     * 删除集合所有集合c中包含的元素
     */
    public synchronized boolean removeAll(Collection<?> c) {
        return super.removeAll(c);
    }

    /**
     * 仅保留集合c中由的元素
     */
    public synchronized boolean retainAll(Collection<?> c) {
        return super.retainAll(c);
    }

    /**
     * 在指定位置开始插入集合c中元素
     */
    public synchronized boolean addAll(int index, Collection<? extends E> c) {
        modCount++;
        if (index < 0 || index > elementCount)
            throw new ArrayIndexOutOfBoundsException(index);

        Object[] a = c.toArray();
        int numNew = a.length;
        ensureCapacityHelper(elementCount + numNew);

        int numMoved = elementCount - index;
        if (numMoved > 0)
            System.arraycopy(elementData, index, elementData, index + numNew, numMoved);

        System.arraycopy(a, 0, elementData, index, numNew);
        elementCount += numNew;
        return numNew != 0;
    }

    /**
     * 判断此集合和o是否相同
     */
    public synchronized boolean equals(Object o) {
        return super.equals(o);
    }

    /**
     * Returns the hash code value for this Vector.
     */
    public synchronized int hashCode() {
        return super.hashCode();
    }

    /**
     * 
     */
    public synchronized String toString() {
        return super.toString();
    }

    /**
     * 返回从fromIndex 到toIndex的子集合
     */
    public synchronized List<E> subList(int fromIndex, int toIndex) {
        return Collections.synchronizedList(super.subList(fromIndex, toIndex), this);
    }

    /**
     * 移除指定范围的元素
     */
    protected synchronized void removeRange(int fromIndex, int toIndex) {
        modCount++;
        int numMoved = elementCount - toIndex;
        System.arraycopy(elementData, toIndex, elementData, fromIndex, numMoved);

        // Let gc do its work
        int newElementCount = elementCount - (toIndex - fromIndex);
        while (elementCount != newElementCount)
            elementData[--elementCount] = null;
    }

    /**
     * Save the state of the {@code Vector} instance to a stream (that
     * is, serialize it).
     * This method performs synchronization to ensure the consistency
     * of the serialized data.
     */
    private void writeObject(java.io.ObjectOutputStream s) throws java.io.IOException {
        final java.io.ObjectOutputStream.PutField fields = s.putFields();
        final Object[] data;
        synchronized (this) {
            fields.put("capacityIncrement", capacityIncrement);
            fields.put("elementCount", elementCount);
            data = elementData.clone();
        }
        fields.put("elementData", data);
        s.writeFields();
    }

    /**
     * Returns a list iterator over the elements in this list (in proper
     * sequence), starting at the specified position in the list.
     * The specified index indicates the first element that would be
     * returned by an initial call to {@link ListIterator#next next}.
     * An initial call to {@link ListIterator#previous previous} would
     * return the element with the specified index minus one.
     *
     * <p>The returned list iterator is <a href="#fail-fast"><i>fail-fast</i></a>.
     *
     * @throws IndexOutOfBoundsException {@inheritDoc}
     */
    public synchronized ListIterator<E> listIterator(int index) {
        if (index < 0 || index > elementCount)
            throw new IndexOutOfBoundsException("Index: " + index);
        return new ListItr(index);
    }

    /**
     * Returns a list iterator over the elements in this list (in proper
     * sequence).
     *
     * <p>The returned list iterator is <a href="#fail-fast"><i>fail-fast</i></a>.
     *
     * @see #listIterator(int)
     */
    public synchronized ListIterator<E> listIterator() {
        return new ListItr(0);
    }

    /**
     * Returns an iterator over the elements in this list in proper sequence.
     *
     * <p>The returned iterator is <a href="#fail-fast"><i>fail-fast</i></a>.
     *
     * @return an iterator over the elements in this list in proper sequence
     */
    public synchronized Iterator<E> iterator() {
        return new Itr();
    }

    /**
     * An optimized version of AbstractList.Itr
     */
    private class Itr implements Iterator<E> {
        int cursor; // index of next element to return
        int lastRet = -1; // index of last element returned; -1 if no such
        int expectedModCount = modCount;

        public boolean hasNext() {
            // Racy but within spec, since modifications are checked
            // within or after synchronization in next/previous
            return cursor != elementCount;
        }

        public E next() {
            synchronized (Vector.this) {
                checkForComodification();
                int i = cursor;
                if (i >= elementCount)
                    throw new NoSuchElementException();
                cursor = i + 1;
                return elementData(lastRet = i);
            }
        }

        public void remove() {
            if (lastRet == -1)
                throw new IllegalStateException();
            synchronized (Vector.this) {
                checkForComodification();
                Vector.this.remove(lastRet);
                expectedModCount = modCount;
            }
            cursor = lastRet;
            lastRet = -1;
        }

        @Override
        public void forEachRemaining(Consumer<? super E> action) {
            Objects.requireNonNull(action);
            synchronized (Vector.this) {
                final int size = elementCount;
                int i = cursor;
                if (i >= size) {
                    return;
                }
                @SuppressWarnings("unchecked")
                final E[] elementData = (E[]) Vector.this.elementData;
                if (i >= elementData.length) {
                    throw new ConcurrentModificationException();
                }
                while (i != size && modCount == expectedModCount) {
                    action.accept(elementData[i++]);
                }
                // update once at end of iteration to reduce heap write traffic
                cursor = i;
                lastRet = i - 1;
                checkForComodification();
            }
        }

        final void checkForComodification() {
            if (modCount != expectedModCount)
                throw new ConcurrentModificationException();
        }
    }

    /**
     * An optimized version of AbstractList.ListItr
     */
    final class ListItr extends Itr implements ListIterator<E> {
        ListItr(int index) {
            super();
            cursor = index;
        }

        public boolean hasPrevious() {
            return cursor != 0;
        }

        public int nextIndex() {
            return cursor;
        }

        public int previousIndex() {
            return cursor - 1;
        }

        public E previous() {
            synchronized (Vector.this) {
                checkForComodification();
                int i = cursor - 1;
                if (i < 0)
                    throw new NoSuchElementException();
                cursor = i;
                return elementData(lastRet = i);
            }
        }

        public void set(E e) {
            if (lastRet == -1)
                throw new IllegalStateException();
            synchronized (Vector.this) {
                checkForComodification();
                Vector.this.set(lastRet, e);
            }
        }

        public void add(E e) {
            int i = cursor;
            synchronized (Vector.this) {
                checkForComodification();
                Vector.this.add(i, e);
                expectedModCount = modCount;
            }
            cursor = i + 1;
            lastRet = -1;
        }
    }

    @Override
    public synchronized void forEach(Consumer<? super E> action) {
        Objects.requireNonNull(action);
        final int expectedModCount = modCount;
        @SuppressWarnings("unchecked")
        final E[] elementData = (E[]) this.elementData;
        final int elementCount = this.elementCount;
        for (int i = 0; modCount == expectedModCount && i < elementCount; i++) {
            action.accept(elementData[i]);
        }
        if (modCount != expectedModCount) {
            throw new ConcurrentModificationException();
        }
    }

    @Override
    @SuppressWarnings("unchecked")
    public synchronized boolean removeIf(Predicate<? super E> filter) {
        Objects.requireNonNull(filter);
        // figure out which elements are to be removed
        // any exception thrown from the filter predicate at this stage
        // will leave the collection unmodified
        int removeCount = 0;
        final int size = elementCount;
        final BitSet removeSet = new BitSet(size);
        final int expectedModCount = modCount;
        for (int i = 0; modCount == expectedModCount && i < size; i++) {
            @SuppressWarnings("unchecked")
            final E element = (E) elementData[i];
            if (filter.test(element)) {
                removeSet.set(i);
                removeCount++;
            }
        }
        if (modCount != expectedModCount) {
            throw new ConcurrentModificationException();
        }

        // shift surviving elements left over the spaces left by removed elements
        final boolean anyToRemove = removeCount > 0;
        if (anyToRemove) {
            final int newSize = size - removeCount;
            for (int i = 0, j = 0; (i < size) && (j < newSize); i++, j++) {
                i = removeSet.nextClearBit(i);
                elementData[j] = elementData[i];
            }
            for (int k = newSize; k < size; k++) {
                elementData[k] = null; // Let gc do its work
            }
            elementCount = newSize;
            if (modCount != expectedModCount) {
                throw new ConcurrentModificationException();
            }
            modCount++;
        }

        return anyToRemove;
    }

    @Override
    @SuppressWarnings("unchecked")
    public synchronized void replaceAll(UnaryOperator<E> operator) {
        Objects.requireNonNull(operator);
        final int expectedModCount = modCount;
        final int size = elementCount;
        for (int i = 0; modCount == expectedModCount && i < size; i++) {
            elementData[i] = operator.apply((E) elementData[i]);
        }
        if (modCount != expectedModCount) {
            throw new ConcurrentModificationException();
        }
        modCount++;
    }

    @SuppressWarnings("unchecked")
    @Override
    public synchronized void sort(Comparator<? super E> c) {
        final int expectedModCount = modCount;
        Arrays.sort((E[]) elementData, 0, elementCount, c);
        if (modCount != expectedModCount) {
            throw new ConcurrentModificationException();
        }
        modCount++;
    }

    /**
     * Creates a <em><a href="Spliterator.html#binding">late-binding</a></em>
     * and <em>fail-fast</em> {@link Spliterator} over the elements in this
     * list.
     *
     * <p>The {@code Spliterator} reports {@link Spliterator#SIZED},
     * {@link Spliterator#SUBSIZED}, and {@link Spliterator#ORDERED}.
     * Overriding implementations should document the reporting of additional
     * characteristic values.
     *
     * @return a {@code Spliterator} over the elements in this list
     * @since 1.8
     */
    @Override
    public Spliterator<E> spliterator() {
        return new VectorSpliterator<>(this, null, 0, -1, 0);
    }

    /** Similar to ArrayList Spliterator */
    static final class VectorSpliterator<E> implements Spliterator<E> {
        private final Vector<E> list;
        private Object[] array;
        private int index; // current index, modified on advance/split
        private int fence; // -1 until used; then one past last index
        private int expectedModCount; // initialized when fence set

        /** Create new spliterator covering the given  range */
        VectorSpliterator(Vector<E> list, Object[] array, int origin, int fence, int expectedModCount) {
            this.list = list;
            this.array = array;
            this.index = origin;
            this.fence = fence;
            this.expectedModCount = expectedModCount;
        }

        private int getFence() { // initialize on first use
            int hi;
            if ((hi = fence) < 0) {
                synchronized (list) {
                    array = list.elementData;
                    expectedModCount = list.modCount;
                    hi = fence = list.elementCount;
                }
            }
            return hi;
        }

        public Spliterator<E> trySplit() {
            int hi = getFence(), lo = index, mid = (lo + hi) >>> 1;
            return (lo >= mid) ? null : new VectorSpliterator<E>(list, array, lo, index = mid, expectedModCount);
        }

        @SuppressWarnings("unchecked")
        public boolean tryAdvance(Consumer<? super E> action) {
            int i;
            if (action == null)
                throw new NullPointerException();
            if (getFence() > (i = index)) {
                index = i + 1;
                action.accept((E) array[i]);
                if (list.modCount != expectedModCount)
                    throw new ConcurrentModificationException();
                return true;
            }
            return false;
        }

        @SuppressWarnings("unchecked")
        public void forEachRemaining(Consumer<? super E> action) {
            int i, hi; // hoist accesses and checks from loop
            Vector<E> lst;
            Object[] a;
            if (action == null)
                throw new NullPointerException();
            if ((lst = list) != null) {
                if ((hi = fence) < 0) {
                    synchronized (lst) {
                        expectedModCount = lst.modCount;
                        a = array = lst.elementData;
                        hi = fence = lst.elementCount;
                    }
                } else
                    a = array;
                if (a != null && (i = index) >= 0 && (index = hi) <= a.length) {
                    while (i < hi)
                        action.accept((E) a[i++]);
                    if (lst.modCount == expectedModCount)
                        return;
                }
            }
            throw new ConcurrentModificationException();
        }

        public long estimateSize() {
            return (long) (getFence() - index);
        }

        public int characteristics() {
            return Spliterator.ORDERED | Spliterator.SIZED | Spliterator.SUBSIZED;
        }
    }
}

```

### 4. Vector 遍历方式

>Vector 支持4种遍历方式。
>
>1. 通过迭代器遍历。即通过Iterator遍历
>
>   ```
>    for(Iterator iter = list.iterator(); iter.hasNext(); ) {
>               iter.next();
>           }
>   ```
>
>2. 随机访问，通过索引值去遍历
>
>   ```
>   Integer value = null;
>   int size = vec.size();
>   for (int i=0; i<size; i++) {
>       value = (Integer)vec.get(i);        
>   }
>   ```
>
>3. 通过foreach访问
>
>   ```
>   for (Integer integ:vec) {
>       value = integ;
>   }
>   ```
>
>4. 通过Enumeration遍历
>
>   ```
>   Integer value = null;
>   Enumeration enu = vec.elements();
>   while (enu.hasMoreElements()) {
>       value = (Integer)enu.nextElement();
>   }
>   ```
>
>   **测试这些遍历方式效率的代码如下**：
>
>   ```
>   package Collections.cnblog.collection.list;
>
>   /**************************************
>    *      Author : zhangke
>    *      Date   : 2018/1/31 11:54
>    *      Desc   : vector 学习
>    ***************************************/
>
>   import java.util.*;
>
>   public class StudyVector {
>
>       public static void main(String[] args) {
>           Vector vec = new Vector();
>           for (int i = 0; i < 100000; i++)
>               vec.add(i);
>           iteratorThroughRandomAccess(vec);
>           iteratorThroughIterator(vec);
>           iteratorThroughFor2(vec);
>           iteratorThroughEnumeration(vec);
>
>       }
>
>       private static void isRandomAccessSupported(List list) {
>           if (list instanceof RandomAccess) {
>               System.out.println("RandomAccess implemented!");
>           } else {
>               System.out.println("RandomAccess not implemented!");
>           }
>
>       }
>
>       public static void iteratorThroughRandomAccess(List list) {
>
>           long startTime;
>           long endTime;
>           startTime = System.currentTimeMillis();
>           for (int i = 0; i < list.size(); i++) {
>               list.get(i);
>           }
>           endTime = System.currentTimeMillis();
>           long interval = endTime - startTime;
>           System.out.println("iteratorThroughRandomAccess：" + interval + " ms");
>       }
>
>       public static void iteratorThroughIterator(List list) {
>
>           long startTime;
>           long endTime;
>           startTime = System.currentTimeMillis();
>           for (Iterator iter = list.iterator(); iter.hasNext(); ) {
>               iter.next();
>           }
>           endTime = System.currentTimeMillis();
>           long interval = endTime - startTime;
>           System.out.println("iteratorThroughIterator：" + interval + " ms");
>       }
>   ```
>
>
>       public static void iteratorThroughFor2(List list) {
>    
>           long startTime;
>           long endTime;
>           startTime = System.currentTimeMillis();
>           for (Object obj : list)
>               ;
>           endTime = System.currentTimeMillis();
>           long interval = endTime - startTime;
>           System.out.println("iteratorThroughFor2：" + interval + " ms");
>       }
>    
>       public static void iteratorThroughEnumeration(Vector vec) {
>    
>           long startTime;
>           long endTime;
>           startTime = System.currentTimeMillis();
>           for (Enumeration enu = vec.elements(); enu.hasMoreElements(); ) {
>               enu.nextElement();
>           }
>           endTime = System.currentTimeMillis();
>           long interval = endTime - startTime;
>           System.out.println("iteratorThroughEnumeration：" + interval + " ms");
>       }
>   运行结果几次都显示 foreach遍历最快

