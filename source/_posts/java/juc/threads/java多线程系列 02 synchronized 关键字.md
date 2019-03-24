---
title: java多线程系列 02 sychronized关键字
tags:
  - java
  - 并发
categories:
  - java
  - juc
  - threads
author: zhangke
abbrlink: aa8f827d
date: 2018-07-12 15:55:00
---
# java多线程系列 02 sychronized关键字

### 概要

1. Sychronized 基本用法
2. sychronized基本规则
3. 对象锁和类索

<!-- more -->

### 1. sychronized基本用法

sychronized主要由俩种用法，一种是用来修饰方法，另外一种是用来修饰代码块。

**synchronized方法示例**

```java
public synchronized void foo1() {
    System.out.println("synchronized methoed");
}
```

**synchronized代码块**

```java
public void foo2() {
    synchronized (this) {
        System.out.println("synchronized methoed");
    }
}
```

synchronized代码块中的this是指当前对象。也可以将this替换成其他对象，例如将this替换成obj，则foo2()在执行synchronized(obj)时就获取的是obj的同步锁。

synchronized代码块可以更精确的控制冲突限制访问区域，有时候表现更高效率(并不是在所有情况下是最好的)。下面通过一个示例来演示：

```Java
public class Demo4 {

    public synchronized void synMethod() {
        for (int i = 0; i < 1000000; i++)
            ;
    }

    public void synBlock() {
        synchronized (this) {
            for (int i = 0; i < 1000000; i++)
                ;
        }
    }

    public static void main(String[] args) {
        Demo4 demo = new Demo4();

        long start, diff;
        start = System.currentTimeMillis();                // 获取当前时间(millis)
        demo.synMethod();                                // 调用“synchronized方法”
        diff = System.currentTimeMillis() - start;        // 获取“时间差值”
        System.out.println("synMethod() : " + diff);

        start = System.currentTimeMillis();                // 获取当前时间(millis)
        demo.synBlock();                                // 调用“synchronized方法块”
        diff = System.currentTimeMillis() - start;        // 获取“时间差值”
        System.out.println("synBlock()  : " + diff);
    }
}
```
>
>下面是在我电脑上运行的结果：
>
>```
>synMethod() : 2
>synBlock()  : 3
>```
>
>

### 2. sychronized基本规则我们将synchronized的基本规则总结为下面3条，并通过实例对它们进行说明。 

>
>
>>## 第一条
>>
>>当一个线程访问“某对象”的“synchronized方法”或者“synchronized代码块”时，其他线程对“该对象”的该“synchronized方法”或者“synchronized代码块”的访问将被阻塞。 
>>
>>下面是“synchronized代码块”对应的演示程序。
>>
>>```java
>>class MyRunable implements Runnable {
>>
>>    @Override
>>    public void run() {
>>        //锁住当前线程
>>        synchronized (this) {
>>            try {
>>                for (int i = 0; i < 5; i++) {
>>                    Thread.sleep(100); // 休眠100ms
>>                    System.out.println(Thread.currentThread().getName() 
>>                                       + " loop " + i);
>>                }
>>            } catch (InterruptedException ie) {
>>            }
>>        }
>>    }
>>}
>>
>>public class Demo1_1 {
>>
>>    public static void main(String[] args) {
>>        // 新建“Runnable对象”
>>        Runnable demo = new MyRunable();
>>
>>        // 新建“线程t1”, t1是基于demo这个Runnable对象
>>        Thread t1 = new Thread(demo, "t1");
>>
>>        // 新建“线程t2”, t2是基于demo这个Runnable对象
>>        Thread t2 = new Thread(demo, "t2");
>>        t1.start();           // 启动“线程t1”
>>        t2.start();           // 启动“线程t2”
>>    }
>>}
>>```
>>
>>运行结果
>>
>>```
>>t1 loop 0
>>t1 loop 1
>>t1 loop 2
>>t1 loop 3
>>t1 loop 4
>>t2 loop 0
>>t2 loop 1
>>t2 loop 2
>>t2 loop 3
>>t2 loop 4
>>```
>>
>>**结果说明**：
>>run()方法中存在“synchronized(this)代码块”，而且t1和t2都是基于"demo这个Runnable对象"创建的线程。这就意味着，我们可以将synchronized(this)中的this看作是“demo这个Runnable对象”；因此，线程t1和t2共享“demo对象的同步锁”。所以，当一个线程运行的时候，另外一个线程必须等待“运行线程”释放“demo的同步锁”之后才能运行。
>>
>>如果你确认，你搞清楚这个问题了。那我们将上面的代码进行修改，然后再运行看看结果怎么样，看看你是否会迷糊。修改后的源码如下：
>>
>>```
>>class MyThread extends Thread {
>>    
>>    public MyThread(String name) {
>>        super(name);
>>    }
>>
>>    @Override
>>    public void run() {
>>        synchronized(this) {
>>            try {  
>>                for (int i = 0; i < 5; i++) {
>>                    Thread.sleep(100); // 休眠100ms
>>                    System.out.println(Thread.currentThread().getName() 
>>                    + " loop " + i);  
>>                }
>>            } catch (InterruptedException ie) {  
>>            }
>>        }  
>>    }
>>}
>>
>>public class Demo1_2 {
>>
>>    public static void main(String[] args) {  
>>        Thread t1 = new MyThread("t1");  // 新建“线程t1”
>>        Thread t2 = new MyThread("t2");  // 新建“线程t2”
>>        t1.start();                          // 启动“线程t1”
>>        t2.start();                          // 启动“线程t2” 
>>    } 
>>}
>>```
>>
>>**代码说明**： 比较Demo1_2 和 Demo1_1，我们发现，Demo1_2中的MyThread类是直接继承于Thread，而且t1和t2都是MyThread子线程。 幸运的是，在“Demo1_2的run()方法”也调用了synchronized(this)，正如“Demo1_1的run()方法”也调用了synchronized(this)一样！ 那么，Demo1_2的执行流程是不是和Demo1_1一样呢？
>>
>>运行结果
>>
>>```
>>t1 loop 0
>>t2 loop 0
>>t1 loop 1
>>t2 loop 1
>>t1 loop 2
>>t2 loop 2
>>t1 loop 3
>>t2 loop 3
>>t1 loop 4
>>t2 loop 4
>>```
>>
>>**结果说明**：
>>如果这个结果一点也不令你感到惊讶，那么我相信你对synchronized和this的认识已经比较深刻了。否则的话，请继续阅读这里的分析。
>>synchronized(this)中的this是指“当前的类对象”，即synchronized(this)所在的类对应的当前对象。它的作用是获取“当前对象的同步锁”。
>>对于Demo1_2中，synchronized(this)中的this代表的是MyThread对象，而t1和t2是两个不同的MyThread对象，因此t1和t2在执行synchronized(this)时，获取的是不同对象的同步锁。对于Demo1_1对而言，synchronized(this)中的this代表的是MyRunable对象；t1和t2共同一个MyRunable对象，因此，一个线程获取了对象的同步锁，会造成另外一个线程等待。
>>
>>## 第二条
>>
>>当一个线程访问“某对象”的“synchronized方法”或者“synchronized代码块”时，其他线程仍然可以访问“该对象”的非同步代码块。 下面是“synchronized代码块”对应的演示程序:
>>
>>```
>>class Count {
>>
>>    // 含有synchronized同步块的方法
>>    public void synMethod() {
>>        synchronized(this) {
>>            try {  
>>                for (int i = 0; i < 5; i++) {
>>                    Thread.sleep(100); // 休眠100ms
>>                    System.out.println(Thread.currentThread().getName() + " synMethod loop " + i);  
>>                }
>>            } catch (InterruptedException ie) {  
>>            }
>>        }  
>>    }
>>
>>    // 非同步的方法
>>    public void nonSynMethod() {
>>        try {  
>>            for (int i = 0; i < 5; i++) {
>>                Thread.sleep(100);
>>                System.out.println(Thread.currentThread().getName() + " nonSynMethod loop " + i);  
>>            }
>>        } catch (InterruptedException ie) {  
>>        }
>>    }
>>}
>>
>>public class Demo2 {
>>
>>    public static void main(String[] args) {  
>>        final Count count = new Count();
>>        // 新建t1, t1会调用“count对象”的synMethod()方法
>>        Thread t1 = new Thread(
>>                new Runnable() {
>>                    @Override
>>                    public void run() {
>>                        count.synMethod();
>>                    }
>>                }, "t1");
>>
>>        // 新建t2, t2会调用“count对象”的nonSynMethod()方法
>>        Thread t2 = new Thread(
>>                new Runnable() {
>>                    @Override
>>                    public void run() {
>>                        count.nonSynMethod();
>>                    }
>>                }, "t2");  
>>
>>
>>        t1.start();  // 启动t1
>>        t2.start();  // 启动t2
>>    } 
>>}
>>```
>>
>>运行结果：
>>
>>```
>>t1 synMethod loop 0
>>t2 nonSynMethod loop 0
>>t1 synMethod loop 1
>>t2 nonSynMethod loop 1
>>t1 synMethod loop 2
>>t2 nonSynMethod loop 2
>>t1 synMethod loop 3
>>t2 nonSynMethod loop 3
>>t1 synMethod loop 4
>>t2 nonSynMethod loop 4
>>```
>>
>>**结果说明**： 主线程中新建了两个子线程t1和t2。t1会调用count对象的synMethod()方法，该方法内含有同步块；而t2则会调用count对象的nonSynMethod()方法，该方法不是同步方法。t1运行时，虽然调用synchronized(this)获取“count的同步锁”；但是并没有造成t2的阻塞，因为t2没有用到“count”同步锁。
>>
>># 第三条
>>
>>当一个线程访问“某对象”的“synchronized方法”或者“synchronized代码块”时，其他线程对“该对象”的其他的“synchronized方法”或者“synchronized代码块”的访问将被阻塞。 我们将上面的例子中的nonSynMethod()方法体的也用synchronized(this)修饰。修改后的源码如下：
>>
>>```
>>class Count {
>>
>>    // 含有synchronized同步块的方法
>>    public void synMethod() {
>>        synchronized(this) {
>>            try {  
>>                for (int i = 0; i < 5; i++) {
>>                    Thread.sleep(100); // 休眠100ms
>>                    System.out.println(Thread.currentThread().getName() + " synMethod loop " + i);  
>>                }
>>            } catch (InterruptedException ie) {  
>>            }
>>        }  
>>    }
>>
>>    // 也包含synchronized同步块的方法
>>    public void nonSynMethod() {
>>        synchronized(this) {
>>            try {  
>>                for (int i = 0; i < 5; i++) {
>>                    Thread.sleep(100);
>>                    System.out.println(Thread.currentThread().getName() + " nonSynMethod loop " + i);  
>>                }
>>            } catch (InterruptedException ie) {  
>>            }
>>        }
>>    }
>>}
>>
>>public class Demo3 {
>>
>>    public static void main(String[] args) {  
>>        final Count count = new Count();
>>        // 新建t1, t1会调用“count对象”的synMethod()方法
>>        Thread t1 = new Thread(
>>                new Runnable() {
>>                    @Override
>>                    public void run() {
>>                        count.synMethod();
>>                    }
>>                }, "t1");
>>
>>        // 新建t2, t2会调用“count对象”的nonSynMethod()方法
>>        Thread t2 = new Thread(
>>                new Runnable() {
>>                    @Override
>>                    public void run() {
>>                        count.nonSynMethod();
>>                    }
>>                }, "t2");  
>>
>>
>>        t1.start();  // 启动t1
>>        t2.start();  // 启动t2
>>    } 
>>}
>>```
>>
>>运行结果：
>>
>>```
>>t1 synMethod loop 0
>>t1 synMethod loop 1
>>t1 synMethod loop 2
>>t1 synMethod loop 3
>>t1 synMethod loop 4
>>t2 nonSynMethod loop 0
>>t2 nonSynMethod loop 1
>>t2 nonSynMethod loop 2
>>t2 nonSynMethod loop 3
>>t2 nonSynMethod loop 4
>>```
>>
>>**结果说明**： 主线程中新建了两个子线程t1和t2。t1和t2运行时都调用synchronized(this)，这个this是Count对象(count)，而t1和t2共用count。因此，在t1运行时，t2会被阻塞，等待t1运行释放“count对象的同步锁”，t2才能运行。
>
>

### 3. 对象锁和类索

>**对象锁** -- 锁在某一个实例对象上。如果该类是单例，那么该锁也和类锁具有相同的效果。          
>
> **类锁** -- 该锁针对的是类，无论实例多少个对象，那么线程都共享该锁。 类锁对应的就是static synchronized（或者是锁在该类的class或者classloader对象上）。
>
>关于“实例锁”和“全局锁”有一个很形象的例子：
>
>```
>pulbic class Something {
>    public synchronized void isSyncA(){}
>    public synchronized void isSyncB(){}
>    public static synchronized void cSyncA(){}
>    public static synchronized void cSyncB(){}
>}
>```
>
>假设，Something有两个实例x和y。分析下面4组表达式获取的锁的情况。
>(01) x.isSyncA()与x.isSyncB() 
>(02) x.isSyncA()与y.isSyncA()
>(03) x.cSyncA()与y.cSyncB()
>(04) x.isSyncA()与Something.cSyncA()
>
>**(01) 不能被同时访问。**因为isSyncA()和isSyncB()都是访问同一个对象(对象x)的同步锁！
>
>```
> // LockTest1.java的源码
>class Something {
>    public synchronized void isSyncA(){
>        try {  
>            for (int i = 0; i < 5; i++) {
>                Thread.sleep(100); // 休眠100ms
>                System.out.println(Thread.currentThread().getName()+" : isSyncA");
>            }
>        }catch (InterruptedException ie) {  
>        }  
>    }
>    public synchronized void isSyncB(){
>        try {  
>            for (int i = 0; i < 5; i++) {
>                Thread.sleep(100); // 休眠100ms
>                System.out.println(Thread.currentThread().getName()+" : isSyncB");
>            }
>        }catch (InterruptedException ie) {  
>        }  
>    }
>}
>
>public class LockTest1 {
>
>    Something x = new Something();
>    Something y = new Something();
>
>    // 比较(01) x.isSyncA()与x.isSyncB() 
>    private void test1() {
>        // 新建t11, t11会调用 x.isSyncA()
>        Thread t11 = new Thread(
>                new Runnable() {
>                    @Override
>                    public void run() {
>                        x.isSyncA();
>                    }
>                }, "t11");
>
>        // 新建t12, t12会调用 x.isSyncB()
>        Thread t12 = new Thread(
>                new Runnable() {
>                    @Override
>                    public void run() {
>                        x.isSyncB();
>                    }
>                }, "t12");  
>
>
>        t11.start();  // 启动t11
>        t12.start();  // 启动t12
>    }
>
>    public static void main(String[] args) {
>        LockTest1 demo = new LockTest1();
>        demo.test1();
>    }
>}
>```
>
>**运行结果**：
>
>```
>t11 : isSyncA
>t11 : isSyncA
>t11 : isSyncA
>t11 : isSyncA
>t11 : isSyncA
>t12 : isSyncB
>t12 : isSyncB
>t12 : isSyncB
>t12 : isSyncB
>t12 : isSyncB
>```
>
>**(02) 可以同时被访问。**因为访问的不是同一个对象的同步锁，x.isSyncA()访问的是x的同步锁，而y.isSyncA()访问的是y的同步锁。
>
>```
>// LockTest1.java的源码
>class Something {
>    public synchronized void isSyncA(){
>        try {  
>            for (int i = 0; i < 5; i++) {
>                Thread.sleep(100); // 休眠100ms
>                System.out.println(Thread.currentThread().getName()+" : isSyncA");
>            }
>        }catch (InterruptedException ie) {  
>        }  
>    }
>    public synchronized void isSyncB(){
>        try {  
>            for (int i = 0; i < 5; i++) {
>                Thread.sleep(100); // 休眠100ms
>                System.out.println(Thread.currentThread().getName()+" : isSyncB");
>            }
>        }catch (InterruptedException ie) {  
>        }  
>    }
>}
>
>public class LockTest1 {
>
>    Something x = new Something();
>    Something y = new Something();
>
>    // 比较(01) x.isSyncA()与x.isSyncB() 
>    private void test1() {
>        // 新建t11, t11会调用 x.isSyncA()
>        Thread t11 = new Thread(
>                new Runnable() {
>                    @Override
>                    public void run() {
>                        x.isSyncA();
>                    }
>                }, "t11");
>
>        // 新建t12, t12会调用 x.isSyncB()
>        Thread t12 = new Thread(
>                new Runnable() {
>                    @Override
>                    public void run() {
>                        x.isSyncB();
>                    }
>                }, "t12");  
>
>
>        t11.start();  // 启动t11
>        t12.start();  // 启动t12
>    }
>
>    public static void main(String[] args) {
>        LockTest1 demo = new LockTest1();
>        demo.test1();
>    }
>}
>```
>
>**运行结果**：
>
>```
>t21 : isSyncA
>t22 : isSyncA
>t21 : isSyncA
>t22 : isSyncA
>t21 : isSyncA
>t22 : isSyncA
>t21 : isSyncA
>t22 : isSyncA
>t21 : isSyncA
>t22 : isSyncA
>```
>
>**(03) 不能被同时访问。**因为cSyncA()和cSyncB()都是static类型，x.cSyncA()相当于Something.isSyncA()，y.cSyncB()相当于Something.isSyncB()，因此它们共用一个同步锁，不能被同时反问。
>
>```
> // LockTest3.java的源码
>class Something {
>    public synchronized void isSyncA(){
>        try {  
>            for (int i = 0; i < 5; i++) {
>                Thread.sleep(100); // 休眠100ms
>                System.out.println(Thread.currentThread().getName()+" : isSyncA");
>            }
>        }catch (InterruptedException ie) {  
>        }  
>    }
>    public synchronized void isSyncB(){
>        try {  
>            for (int i = 0; i < 5; i++) {
>                Thread.sleep(100); // 休眠100ms
>                System.out.println(Thread.currentThread().getName()+" : isSyncB");
>            }
>        }catch (InterruptedException ie) {  
>        }  
>    }
>    public static synchronized void cSyncA(){
>        try {  
>            for (int i = 0; i < 5; i++) {
>                Thread.sleep(100); // 休眠100ms
>                System.out.println(Thread.currentThread().getName()+" : cSyncA");
>            } 
>        }catch (InterruptedException ie) {  
>        }  
>    }
>    public static synchronized void cSyncB(){
>        try {  
>            for (int i = 0; i < 5; i++) {
>                Thread.sleep(100); // 休眠100ms
>                System.out.println(Thread.currentThread().getName()+" : cSyncB");
>            } 
>        }catch (InterruptedException ie) {  
>        }  
>    }
>}
>
>public class LockTest3 {
>
>    Something x = new Something();
>    Something y = new Something();
>
>    // 比较(03) x.cSyncA()与y.cSyncB()
>    private void test3() {
>        // 新建t31, t31会调用 x.isSyncA()
>        Thread t31 = new Thread(
>                new Runnable() {
>                    @Override
>                    public void run() {
>                        x.cSyncA();
>                    }
>                }, "t31");
>
>        // 新建t32, t32会调用 x.isSyncB()
>        Thread t32 = new Thread(
>                new Runnable() {
>                    @Override
>                    public void run() {
>                        y.cSyncB();
>                    }
>                }, "t32");  
>
>
>        t31.start();  // 启动t31
>        t32.start();  // 启动t32
>    }
>
>    public static void main(String[] args) {
>        LockTest3 demo = new LockTest3();
>
>        demo.test3();
>    }
>}
>```
>
>**运行结果**：
>
>```
>t31 : cSyncA
>t31 : cSyncA
>t31 : cSyncA
>t31 : cSyncA
>t31 : cSyncA
>t32 : cSyncB
>t32 : cSyncB
>t32 : cSyncB
>t32 : cSyncB
>t32 : cSyncB 
>```
>
>**(04) 可以被同时访问。**因为isSyncA()是实例方法，x.isSyncA()使用的是对象x的锁；而cSyncA()是静态方法，Something.cSyncA()可以理解对使用的是“类的锁”。因此，它们是可以被同时访问的。
>
>```
>// LockTest4.java的源码
>class Something {
>    public synchronized void isSyncA(){
>        try {  
>            for (int i = 0; i < 5; i++) {
>                Thread.sleep(100); // 休眠100ms
>                System.out.println(Thread.currentThread().getName()+" : isSyncA");
>            }
>        }catch (InterruptedException ie) {  
>        }  
>    }
>    public synchronized void isSyncB(){
>        try {  
>            for (int i = 0; i < 5; i++) {
>                Thread.sleep(100); // 休眠100ms
>                System.out.println(Thread.currentThread().getName()+" : isSyncB");
>            }
>        }catch (InterruptedException ie) {  
>        }  
>    }
>    public static synchronized void cSyncA(){
>        try {  
>            for (int i = 0; i < 5; i++) {
>                Thread.sleep(100); // 休眠100ms
>                System.out.println(Thread.currentThread().getName()+" : cSyncA");
>            } 
>        }catch (InterruptedException ie) {  
>        }  
>    }
>    public static synchronized void cSyncB(){
>        try {  
>            for (int i = 0; i < 5; i++) {
>                Thread.sleep(100); // 休眠100ms
>                System.out.println(Thread.currentThread().getName()+" : cSyncB");
>            } 
>        }catch (InterruptedException ie) {  
>        }  
>    }
>}
>
>public class LockTest4 {
>
>    Something x = new Something();
>    Something y = new Something();
>
>    // 比较(04) x.isSyncA()与Something.cSyncA()
>    private void test4() {
>        // 新建t41, t41会调用 x.isSyncA()
>        Thread t41 = new Thread(
>                new Runnable() {
>                    @Override
>                    public void run() {
>                        x.isSyncA();
>                    }
>                }, "t41");
>
>        // 新建t42, t42会调用 x.isSyncB()
>        Thread t42 = new Thread(
>                new Runnable() {
>                    @Override
>                    public void run() {
>                        Something.cSyncA();
>                    }
>                }, "t42");  
>
>
>        t41.start();  // 启动t41
>        t42.start();  // 启动t42
>    }
>
>    public static void main(String[] args) {
>        LockTest4 demo = new LockTest4();
>
>        demo.test4();
>    }
>}**运行结果**：
>```
>

总结：其实你可以将类锁和对象锁相同看待，我这里的相同看待是指，将他们看成俩个不同的对象的形式，其实每个class都有一个监视对象。用来管理类的创建等任务。Synchronized关键字也是锁住了这个监视器对象。所以可以类比着看。