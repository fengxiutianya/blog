---
title: java多线程系列 01 基本概念以及实现方式
tags:
  - 并发
categories:
  - java
  - 线程
author: zhangke
abbrlink: 51baaf1d
date: 2018-07-11 16:12:00
---
# java 多线程的基本概念以及实现方式

### 概要

1. 线程的基本概念
2. 常用的实现多线程的方式
3. Thread中start()和run()的区别

###  1. 线程的基本概念

线程状态图

![](https://images0.cnblogs.com/blog/497634/201312/18152411-a974ea82ebc04e72bd874c3921f8bfec.jpg)

<!-- more -->

**说明**：
线程共包括以下5种状态。

1. **新建状态(New)**         : 线程对象被创建后，就进入了新建状态。例如，Thread thread = new Thread()。
2. **就绪状态(Runnable)**: 也被称为“可执行状态”。线程对象被创建后，其它线程调用了该对象的start()方法，从而来启动该线程。例如，thread.start()。处于就绪状态的线程，随时可能被CPU调度执行。
3. **运行状态(Running)** : 线程获取CPU权限进行执行。需要注意的是，线程只能从就绪状态进入到运行状态。
4. **阻塞状态(Blocked)**  : 阻塞状态是线程因为某种原因放弃CPU使用权，暂时停止运行。直到线程进入就绪状态，才有机会转到运行状态。阻塞的情况分三种：
   1. 等待阻塞 -- 通过调用线程的wait()方法，让线程等待某工作的完成。
   2.  同步阻塞 -- 线程在获取synchronized同步锁失败(因为锁被其它线程所占用)，它会进入同步阻塞状态。
   3.  其他阻塞 -- 通过调用线程的sleep()或join()或发出了I/O请求时，线程会进入到阻塞状态。当sleep()状态超时、join()等待线程终止或者超时、或者I/O处理完毕时，线程重新转入就绪状态。
5. **死亡状态(Dead)**    : 线程执行完了或者因异常退出了run()方法，该线程结束生命周期。需要注意的是，**线程一旦进入死亡状态就不能在调用start()方法来让线程恢复运行。**
这5种状态涉及到的内容包括Object类, Thread和synchronized关键字。这些内容我们会在后面的章节中逐个进行学习。

**Object类**，定义了wait(), notify(), notifyAll()等休眠/唤醒函数。
**Thread类**，定义了一些列的线程操作函数。例如，sleep()休眠函数, interrupt()中断函数, getName()获取线程名称等。
**synchronized**，是关键字；它区分为synchronized代码块和synchronized方法。synchronized的作用是让线程获取对象的同步锁。
在后面详细介绍wait(),notify()等方法时，我们会分析为什么**wait(), notify()等方法要定义在Object类，而不是Thread类中**。

### 2. 常用的实现多线程的方式

常用的主要有俩种：Thread类 和Runnable接口
### **Thread和Runnable简介**

**Runnable** 是一个接口，该接口中只包含了一个run()方法。它的定义如下：

```
public interface Runnable {
    public abstract void run();
}
```

Runnable的作用，实现多线程。我们可以定义一个类A实现Runnable接口；

然后，通过``new Thread(new A())``等方式新建线程。

**Thread** 是一个类。Thread本身就实现了Runnable接口。它的声明如下：

```
public class Thread implements Runnable {
    
}
```

Thread的作用，实现多线程。

### **Thread和Runnable的异同点**

**Thread 和 Runnable 的相同点**：都是“多线程的实现方式”。

 **Thread 和 Runnable 的不同点**： Thread 是类，而Runnable是接口；Thread本身是实现了Runnable接口的类。我们知道“一个类只能有一个父类，但是却能实现多个接口”，因此Runnable具有更好的扩展性。

 此外，Runnable还可以用于“资源的共享”。即，多个线程都是基于某一个Runnable对象建立的，它们会共享Runnable对象上的资源。 

通常，建议通过“Runnable”实现多线程！

### **Thread和Runnable的多线程示例**



#### Thread的多线程示例

```
class MyThread extends Thread{  
    private int ticket=10;  
    public void run(){
        for(int i=0;i<20;i++){ 
            if(this.ticket>0){
                System.out.println(this.getName()+" 卖票：ticket"+this.ticket--);
            }
        }
    } 
};

public class ThreadTest {  
    public static void main(String[] args) {  
        // 创建3个线程,每个线程各卖10张票！
        MyThread t1=new MyThread();
        MyThread t2=new MyThread();
        MyThread t3=new MyThread();
        //启动线程，开始运行
        t1.start();
        t2.start();
        t3.start();
    }  
}
```

#### **Runnable的多线程示例**

```
// 实现Runnable接口
class MyThread implements Runnable{  
    private int ticket=10;  
    public void run(){
        for(int i=0;i<20;i++){ 
            if(this.ticket>0){
                System.out.println(Thread.currentThread().getName()
                 +" 卖票：ticket"+this.ticket--);
            }
        }
    } 
}; 

public class RunnableTest {  
    public static void main(String[] args) {  
    
        //创建实现了Runnable接口的对象
        MyThread mt=new MyThread();

        // 创建3个线程t1,t2,t3(它们共用一个Runnable对象)，这3个线程一共卖10张票！
        Thread t1=new Thread(mt);
        Thread t2=new Thread(mt);
        Thread t3=new Thread(mt);
        //启动3个线程
        t1.start();
        t2.start();
        t3.start();
    }  
}
```

**结果说明**： 

1.  和上面“MyThread继承于Thread”不同；这里的MyThread实现了Runnable接口。 

2.  主线程main创建并启动3个子线程，而且这3个子线程都是基于“mt这个Runnable对象”而创建的。运行结果是这3个子线程一共卖出了10张票。这说明它们是共享了MyThread接口的。

#### 注意的是:上面不是线程安全的操作

### 3. Thread中start()和run()的区别

**start()** : 它的作用是启动一个新线程，新线程会执行相应的run()方法。start()不能被重复调用。

 **run()**   : run()就和普通的成员方法一样，可以被重复调用。单独调用run()的话，会在当前线程中执行run()，而并不会启动新线程！

后面会将Thread类的源码拿出来单独解析说明。这里只是简单的提一下。