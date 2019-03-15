abbrlink: 7
title: java多线程系列 07 ThreadGroup
tags:
  - 多线程
categories:
  - java
author: zhangke
date: 2018-07-13 15:27:00
---
# java多线程系列之07 ThreadGroup

### 概要

>1. ThreadGroup 介绍
>2. 基本API的使用与介绍

### 1. ThreadGroup 介绍

> 在java的多线程处理中有线程组ThreadGroup的概念，ThreadGroup是为了方便线程管理出现了，可以统一设定线程组的一些属性，比如setDaemon，设置未处理异常的处理方法，设置统一的安全策略等等；也可以通过线程组方便的获得线程的一些信息。
>
> 每一个ThreadGroup都可以包含一组的子线程和一组子线程组，在一个进程中线程组是以树形的方式存在，通常情况下根线程组是system线程组。system线程组下是main线程组，默认情况下第一级应用自己的线程组是通过main线程组创建出来的。
<!-- more -->

### 2. 基本API介绍

>```
>// 构造函数 
>ThreadGroup(String name)  
>ThreadGroup(ThreadGroup parent, String name)
>
>// 基本API
>int	activeCount()  //返回一个预估的当前TreadGroup和子group中存活线程的数量
>int	activeGroupCount() //返回一个预估的当前TreadGroup所包含的group中存活ThreadGroup的数量
>void	checkAccess() //判断当前运行的线程是否有权限修改此group
>void	destroy()   //销毁当前group和子group
>int	enumerate(Thread[] list) //拷贝当前group和子group中的没有dead的线程
>int	enumerate(Thread[] list,boolean recurs)//和上一个的区别就是是否需要拷贝子group中的线程
>int	enumerate(ThreadGroup[] list)  //拷贝当前group和子group中ThreadGroup
>int	enumerate(ThreadGroup[] list, boolean recurse) //是否需要子Group
>String	getName()
>ThreadGroup	getParent()
>void	interrupt()  //设置当前ThreadGroup中所有的线程中断标记为true
>boolean	isDaemon()
>boolean	isDestroyed()  //判断当前group是否被销毁
>void	list() //打印当前group中的信息去标准输入流
>boolean	parentOf(ThreadGroup g)
>void	setDaemon(boolean daemon)  //改变当前group中的线程为daemon线程
>void	setMaxPriority(int pri)  //设置当前group的权限最大值
>int	    getMaxPriority() //返回当前ThreadGroup的最大权限
>
>void	uncaughtException(Thread t, Throwable e)
>```
>
>### 创建ThreadGroup
>
>简单demo
>
>```
>  //创建ThreadGroup
>    public static void createThreadGroup() {
>        //获取当前的ThreadGroup
>        ThreadGroup currentGroup = Thread.currentThread().getThreadGroup();
>
>        //定义一个新的ThreadGroup，默认panrent为当前线程所对应的group
>        ThreadGroup group1 = new ThreadGroup("Group1");
>
>        //判断当前线程对应的ThreadGroup是否是group1的parentgroup
>        System.out.println(currentGroup == group1.getParent());
>
>        //定义一个新的group2，其parent为group1
>        ThreadGroup group2 = new ThreadGroup(group1, "group2");
>
>        //使用ThreadGroup自带的API判断group1是否是group2的parent
>        System.out.println(group1.parentOf(group2));
>    }
>```
>
>运行结果
>
>```
>true
>true
>```
>
>结果分析：说明如果没有指定创建ThreadGroup的parent，则默认为当前线程所对应的ThreadGroup，另外需要注意的是，ThreadGroup是树形的分布，这课树的根是system，也就是在类加载时就建立好的，接着在main线程启动时，创建了一个以main为名的ThreadGroup。
>
>### 使用enumerate 获取当前thread
>
>```
>    //使用enumerate 复制Thread
>    public static void enumerateThread() throws InterruptedException {
>        //创建一个新的ThreadGroup
>        ThreadGroup group = new ThreadGroup("group");
>
>        //创建线程，设置ThreadGroup
>        Thread thread = new Thread(group, () -> {
>            while (true) {
>                try {
>                    TimeUnit.SECONDS.sleep(1);
>                } catch (Exception e) {
>                    e.printStackTrace();
>                }
>            }
>        });
>
>        thread.start();
>        TimeUnit.MILLISECONDS.sleep(2);
>
>        //得到当前线程对应的ThreadGroup
>        ThreadGroup mainGroup = Thread.currentThread().getThreadGroup();
>
>        //创建存储当前ThreadGroup对应线程的数组
>        Thread[] list = new Thread[mainGroup.activeCount()];
>
>        int recuresize = mainGroup.enumerate(list);
>        System.out.println(recuresize);
>
>        recuresize = mainGroup.enumerate(list, false);
>        System.out.println(recuresize);
>    }
>```
>
>运行结果:
>
>```
>2
>1
>```
>
>### 基本API的使用
>
>```
> //一些基本API的操作
>    public static void testAPI() throws InterruptedException {
>        //创建一个ThreadGroup
>        ThreadGroup group = new ThreadGroup("group1");
>
>        //创建线程，设置ThreadGroup
>        Thread thread = new Thread(group, () -> {
>            while (true) {
>                try {
>                    TimeUnit.SECONDS.sleep(2);
>                } catch (Exception e) {
>                    e.printStackTrace();
>                }
>            }
>        });
>        thread.setDaemon(true);
>        thread.start();
>
>
>        //确保thread开启
>        TimeUnit.MILLISECONDS.sleep(2);
>        ThreadGroup mainThreadGroup = Thread.currentThread().getThreadGroup();
>        System.out.println("activeCount = " + mainThreadGroup.activeCount());
>        System.out.println("activeGroupCount=" + mainThreadGroup.activeGroupCount());
>        System.out.println("getMaxPriority = " + mainThreadGroup.getMaxPriority());
>        System.out.println("getName = " + mainThreadGroup.getName());
>        System.out.println("getParent = " + mainThreadGroup.getName());
>        mainThreadGroup.list();
>        System.out.println("------------------------------------");
>        System.out.println("parentOf = " + mainThreadGroup.parentOf(group));
>        System.out.println("parentOf = " + mainThreadGroup.parentOf(mainThreadGroup));
>
>    }
>```
>
>运行结果：
>
>```
>activeCount = 2
>activeGroupCount=1
>getMaxPriority = 10
>getName = main
>getParent = main
>java.lang.ThreadGroup[name=main,maxpri=10]
>    Thread[main,5,main]
>    java.lang.ThreadGroup[name=group1,maxpri=10]
>        Thread[Thread-0,5,group1]
>------------------------------------
>parentOf = true
>parentOf = true
>```
>
>最后需要注意的是，group的parent也可以是自己本身，这不知道是不是bug。
>
>### setMaxPriority
>
>```
>//线程组优先级设置
>    public static void threadGroupPriority() {
>        //创建一个ThreadGroup
>        ThreadGroup group = new ThreadGroup("group1");
>
>        //创建线程，设置ThreadGroup
>        Thread thread = new Thread(group, () -> {
>            while (true) {
>                try {
>                    TimeUnit.SECONDS.sleep(2);
>                } catch (Exception e) {
>                    e.printStackTrace();
>                }
>            }
>        });
>        thread.setDaemon(true);
>        thread.start();
>        System.out.println("group getMaxPriority()=" + group.getMaxPriority());
>        System.out.println("thread.getPriority()=" + thread.getPriority());
>
>        //改变group的最大优先级
>        group.setMaxPriority(3);
>        System.out.println("group getMaxPriority()=" + group.getMaxPriority());
>        System.out.println("thread.getPriority()=" + thread.getPriority());
>    }
>```
>
>运行结果
>
>```
>group getMaxPriority()=10
>thread.getPriority()=5
>group getMaxPriority()=3
>thread.getPriority()=5
>```
>
>在ThreadGroup中线程的优先级是不能大于ThreadGroup设置的最大优先级，但是上面的结果显示线程的优先级大于了ThreadGroup的最大优先级。这是因为，线程在添加时优先级是不大于ThreadGroup的最大优先级，但是后来ThreadGroup修改了最大优先级，但由于线程的优先级已经设置好了，ThreadGroup将不能去更改这个优先级，所以就存在线程组中有大于线程组最大优先级的线程。但是在这之后添加的线程就不会大于线程组的优先级。
>
>### ThreadGroup的Damon设置和destory
>
>```
>//守护ThreadGroup 和destory
>    public static void threadGroupDaemon() throws InterruptedException {
>        //创建一个ThreadGroup
>        ThreadGroup group = new ThreadGroup("group1");
>
>        //创建线程，设置ThreadGroup
>        new Thread(group, () -> {
>
>            try {
>                TimeUnit.SECONDS.sleep(1);
>            } catch (Exception e) {
>                e.printStackTrace();
>            }
>
>        }, "group1-thread").start();
>        //创建一个ThreadGroup
>        ThreadGroup group2 = new ThreadGroup("group2");
>
>        //创建线程，设置ThreadGroup
>        new Thread(group2, () -> {
>
>            try {
>                TimeUnit.SECONDS.sleep(1);
>            } catch (Exception e) {
>                e.printStackTrace();
>            }
>
>        }, "group2-thread").start();
>
>        //设置group2为daemon为true
>        group2.setDaemon(true);
>        TimeUnit.SECONDS.sleep(3);
>        System.out.println(group.isDestroyed());
>        System.out.println(group2.isDestroyed());
>    }
>```
>
>运行结果:
>
>```
>false
>true
>```
>
>当线程组设置为daemon之后，只要线程组中不存在活跃的线程，线程组则自动destory。但是如果线程组没有设置daemon为true，即使线程组中没有活跃的线程，也不会自动destory。
>
>注意一点是：destory只有当线程组和子线程组中没有活跃的线程才能调用，否则抛出异常。
>
>
>
>
>
>