---
title: Java 8元空间
tags:
  - MetaSpace
  - 元空间
  - java 8
categories:
  - java
  - jvm
  - 内存
abbrlink: bda9e2c7
date: 2019-04-22 16:50:11
---
本文主要讲解Java8中JVM的一个更新，就是持久代的移除。将会介绍为什么需要移除持久代以及它的替代者：元空间(Metaspace)。
## 持久代
java 6中JVM的内存结构如下：
![java_memory_permGen](/images/java_memory_permGen.png)

持久代中包含了虚拟机中所有可通过反射获取到的数据，比如Class和Method对象。不同的Java虚拟机之间可能会进行类共享，因此持久代又分为只读区和读写区。

JVM用于描述应用程序中用到的类和方法的元数据也存储在持久代中。JVM运行时会用到多少持久代的空间取决于应用程序用到了多少类。除此之外，Java SE库中的类和方法也都存储在这里。

如果JVM发现有的类已经不再需要了，它会去回收（卸载）这些类，将它们的空间释放出来给其它类使用。Full GC会进行持久代的回收。
* JVM中类的元数据在Java堆中的存储区域。
* Java类对应的HotSpot虚拟机中的内部表示也存储在这里。
* 类的层级信息，字段，名字。
* 方法的编译信息及字节码。
* 变量
* 常量池和符号解析
<!-- more  -->
### 持久代的大小
* 它的上限是MaxPermSize，默认是64M
* Java堆中的连续区域 : 如果存储在非连续的堆空间中的话，要定位出持久代到新对象的引用非常复杂并且耗时。卡表（card table），是一种记忆集（Remembered Set），它用来记录某个内存代中普通对象指针（oops）的修改。

* **持久代用完后，会抛出OutOfMemoryError "PermGen space"异常。**
解决方案：应用程序清理引用来触发类卸载；增加MaxPermSize的大小。
* 需要多大的持久代空间取决于类的数量，方法的大小，以及常量池的大小。

### 为什么移除持久代
* 它的大小是在启动时固定好的——很难进行调优。-XX:MaxPermSize，设置成多少好呢？
* HotSpot的内部类型也是Java对象：它可能会在Full GC中被移动，同时它对应用不透明，且是非强类型的，难以跟踪调试，还需要存储元数据的元数据信息（meta-metadata）。
* 简化Full GC：每一个回收器有专门的元数据迭代器。
* 可以在GC不进行暂停的情况下并发地释放类数据。
* 使得原来受限于持久代的一些改进未来有可能实现

## 元空间
![jvm_metapsace](/images/jvm_metapsace.png)
持久代的空间被彻底地删除了，它被一个叫元空间的区域所替代了。持久代删除了之后，很明显，JVM会忽略PermSize和MaxPermSize这两个参数，还有就是你再也看不到java.lang.OutOfMemoryError: PermGen error的异常。

JDK 8的HotSpot JVM现在使用的是本地内存来表示类的元数据，这个区域就叫做元空间。

**元空间的特点：**
* 充分利用了Java语言规范中的好处：类及相关的元数据的生命周期与类加载器的一致。
* 每个加载器有专门的存储空间
* 只进行线性分配
* 不会单独回收某个类(除了RedefineClasses和类加载失败)
* 省掉了GC扫描及压缩的时间
* 元空间里的对象的位置是固定的
* 如果GC发现某个类加载器不再存活了，会把相关的空间整个回收掉
**元空间的内存分配模型**
* 绝大多数的类元数据的空间都从本地内存中分配
* 用来描述类元数据的类也被删除了
* 可以给元数据分配多个虚拟映射内存空间。
* 给每个类加载器分配一个内存块的列表。
      1. 块的大小取决于类加载器的类型; 
      2. sun/反射/代理对应的类加载器的块会小一些
* 归还内存块，释放内存块列表
* 一旦元空间的数据被清空了，虚拟内存的空间会被回收掉
* 减少碎片的策略

我们来看下JVM是如何给元数据分配虚拟内存的空间的
![metaspace_allocation_java_latte](/images/metaspace_allocation_java_latte.png)
你可以看到虚拟内存空间是如何分配的(vs1,vs2,vs3) ，以及类加载器的内存块是如何分配的。CL是Class Loader的缩写。
**理解_mark和_klass指针**
要想理解下面这张图，你得搞清楚这些指针都是什么东西。
JVM中，每个对象都有一个指向它自身类的指针，不过这个指针只是指向具体的实现类，而不是接口或者抽象类。
**对于32位的JVM:**
_mark : 4字节常量
_klass: 指向类的4字节指针 对象的内存布局中的第二个字段( _klass，在32位JVM中，相对对象在内存中的位置的偏移量是4，64位的是8)指向的是内存中对象的类定义。

**64位的JVM：**
_mark : 8字节常量
_klass: 指向类的8字节的指针
开启了指针压缩的64位JVM： _mark : 8字节常量，_klass: 指向类的4字节的指针

### java对象的内存布局
![java_object_layout_java_latte](/images/java_object_layout_java_latte.png)
**类指针压缩空间（Compressed Class Pointer Space）**
只有是64位平台上启用了类指针压缩才会存在这个区域。对于64位平台，为了压缩JVM对象中的_klass指针的大小，引入了类指针压缩空间（Compressed Class Pointer Space）。
![compressed_class_pointer_space_java_latte](/images/compressed_class_pointer_space_java_latte.png)
**类指针压缩空间（Compressed Class Pointer Space）**
![java_object_layout_compressed_java_latte](/images/java_object_layout_compressed_java_latte.png)
**指针压缩概要**
64位平台上默认打开
* 使用-XX:+UseCompressedOops压缩对象指针 "oops"指的是普通对象指针("ordinary" object pointers)。 Java堆中对象指针会被压缩成32位。 使用堆基地址（如果堆在低26G内存中的话，基地址为0）
* 使用-XX:+UseCompressedClassPointers选项来压缩类指针
* 对象中指向类元数据的指针会被压缩成32位
* 类指针压缩空间会有一个基地址

**元空间和类指针压缩空间的区别**
* 类指针压缩空间只包含类的元数据，比如InstanceKlass, ArrayKlass 仅当打开了UseCompressedClassPointers选项才生效 为了提高性能，Java中的虚方法表也存放到这里 这里到底存放哪些元数据的类型，目前仍在减少
* 元空间包含类的其它比较大的元数据，比如方法，字节码，常量池等。

**元空间的调优**
使用-XX:MaxMetaspaceSize参数可以设置元空间的最大值，默认是没有上限的，也就是说你的系统内存上限是多少它就是多少。-XX:MetaspaceSize选项指定的是元空间的初始大小，如果没有指定的话，元空间会根据应用程序运行时的需要动态地调整大小。

**MaxMetaspaceSize的调优**
* -XX:MaxMetaspaceSize={unlimited}
* 元空间的大小受限于你机器的内存
* 限制类的元数据使用的内存大小，以免出现虚拟内存切换以及本地内存分配失败。如果怀疑有类加载器出现泄露，应当使用这个参数；32位机器上，如果地址空间可能会被耗尽，也应当设置这个参数。
* 元空间的初始大小是21M——这是GC的初始的高水位线，超过这个大小会进行Full GC来进行类的回收。
* 如果启动后GC过于频繁，请将该值设置得大一些
* 可以设置成和持久代一样的大小，以便推迟GC的执行时间
**CompressedClassSpaceSize的调优**
* 只有当-XX:+UseCompressedClassPointers开启了才有效
* -XX:CompressedClassSpaceSize=1G
* 由于这个大小在启动的时候就固定了的，因此最好设置得大点。
* 没有使用到的话不要进行设置
* JVM后续可能会让这个区可以动态的增长。不需要是连续的区域，只要从基地址可达就行；可能会将更多的类元信息放回到元空间中；未来会基于PredictedLoadedClassCount的值来自动的设置该空间的大小
**元空间的一些工具**
* jmap -permstat改成了jmap -clstats。它用来打印Java堆的类加载器的统计数据。对每一个类加载器，会输出它的名字，是否存活，地址，父类加载器，以及它已经加载的类的数量及大小。除此之外，驻留的字符串（intern）的数量及大小也会打印出来。
* jstat -gc，这个命令输出的是元空间的信息而非持久代的
* jcmd GC.class_stats提供类元数据大小的详细信息。使用这个功能启动程序时需要加上-XX:+UnlockDiagnosticVMOptions选项。
**提高GC的性能**
如果你理解了元空间的概念，很容易发现GC的性能得到了提升。
* Full GC中，元数据指向元数据的那些指针都不用再扫描了。很多复杂的元数据扫描的代码（尤其是CMS里面的那些）都删除了。
* 元空间只有少量的指针指向Java堆。这包括：类的元数据中指向java/lang/Class实例的指针;数组类的元数据中，指向java/lang/Class集合的指针。
* 没有元数据压缩的开销
* 减少了根对象的扫描（不再扫描虚拟机里面的已加载类的字典以及其它的内部哈希表）
* 减少了Full GC的时间
* G1回收器中，并发标记阶段完成后可以进行类的卸载
**总结**
* Hotspot中的元数据现在存储到了元空间里。mmap中的内存块的生命周期与类加载器的一致。
* 类指针压缩空间（Compressed class pointer space）目前仍然是固定大小的，但它的空间较大
* 可以进行参数的调优，不过这不是必需的。
* 未来可能会增加其它的优化及新特性。比如， 应用程序类数据共享；新生代GC优化，G1回收器进行类的回收；减少元数据的大小，以及JVM内部对象的内存占用量。
## 参考
1. [Java 8的元空间](http://it.deepinmind.com/gc/2014/05/14/metaspace-in-java-8.html)
2. [Metaspace in Java 8](http://java-latte.blogspot.com/2014/03/metaspace-in-java-8.html)