---
title: Java NIO之浅谈内存映射文件原理与DirectMemory
tags:
  - NIO
  - 直接内存
categories:
  - java
  - IO
  - nio
abbrlink: e3ecb02e
date: 2019-01-13 16:40:00
---
# Java NIO之浅谈内存映射文件原理与DirectMemory

### 概述

1. 传统文件IO操作原理
2. 什么是内存映射
3. NIO中内存映射
4. 直接缓冲区（DirectMemory）

学习了很久的NIO，但是一直对NIO中内存映射和DirectMemory有很多的不理解，恰好最近在读《深入理解操作系统》，对其中一些不理解的地点有了自己的一些感悟。此篇文章将结合操作系统谈谈自己对NIO中的内存映射和DirectMemory的理解。

<!-- more -->

### 1.传统文件IO操作原理

在传统的文件IO操作中，我们都是调用操作系统提供的底层标准IO系统调用函数  read()、write() ，此时调用此函数的进程（在Java中即java进程）会从用户态切换到内核态，接着OS的内核代码负责将相应的文件数据读取到内核的IO缓冲区，然后再把数据从内核IO缓冲区拷贝到进程的私有地址空间中去，这样便完成了一次IO操作。至于为什么要多此一举搞一个内核IO缓冲区把原本只需一次拷贝数据的事情搞成需要2次数据拷贝呢？ 我想学过操作系统或者计算机系统结构的人都知道，这么做是为了减少磁盘的IO操作，为了提高性能而考虑的，因为我们的程序访问一般都带有局部性，也就是所谓的局部性原理，在这里主要是指的空间局部性，即我们访问了文件的某一段数据，那么接下去很可能还会访问接下去的一段数据，由于磁盘IO操作的速度比直接访问内存慢了好几个数量级，所以OS根据局部性原理会在一次 read()系统调用过程中预读更多的文件数据缓存在内核IO缓冲区中，当继续访问的文件数据在缓冲区中时便直接拷贝数据到进程私有空间，避免了再次的低效率磁盘IO操作。在Java中当我们采用IO包下的文件操作流，如：  

```
FileInputStream in = new FileInputStream("D:\\java.txt");
in.read();
```

 Java虚拟机内部便会调用OS底层的 read()系统调用完成操作，如上所述，在第二次调用 in.read()的时候可能就是从内核缓冲区直接返回数据了（可能还有经过 native堆做一次中转，因为这些函数都被声明为 native，即本地平台相关，所以可能在C代码中有做一次中转，如 win32中是通过 C代码从OS读取数据，然后再传给JVM内存）。既然如此，Java的IO包中为啥还要提供一个BufferedInputStream类来作为缓冲区呢。关键在于四个字，"系统调用"！当读取OS内核缓冲区数据的时候，便发起了一次系统调用操作（通过native的C函数调用），而系统调用的代价相对来说是比较高的，涉及到进程用户态和内核态的上下文切换等一系列操作，所以我们经常采用如下的包装：

```java
FileInputStream in = new FileInputStream("D:\\java.txt"); 
BufferedInputStream buf_in = new BufferedInputStream(in);
buf_in.read();
```

这样一来，我们每一次 buf_in.read() 时候，BufferedInputStream 会根据情况自动为我们预读更多的字节数据到它自己维护的一个内部字节数组缓冲区中，这样我们便可以减少系统调用次数，从而达到其缓冲区的目的。所以要明确的一点是BufferedInputStream的作用不是减少磁盘IO操作次数（这个OS已经帮我们做了），而是通过减少系统调用次数来提高性能的。同理 BufferedOuputStream , BufferedReader/Writer 也是一样的。在 C语言的函数库中也有类似的实现，如 fread()，这个函数就是 C语言中的缓冲IO，作用与BufferedInputStream()相同.

​    这里简单的引用下JDK8 中 BufferedInputStream 的源码验证下：

```java
public class BufferedInputStream extends FilterInputStream {
    /**
    * 只列出了重要的部分
    */
    protected volatile byte buf[];

    public synchronized int read() throws IOException {
        if (pos >= count) {
            fill();
            if (pos >= count)
                return -1;
        }
        return getBufIfOpen()[pos++] & 0xff;
    }
}
```

我们可以看到，BufferedInputStream 内部维护着一个 字节数组 byte[] buf 来实现缓冲区的功能，我们调用的  buf_in.read() 方法在返回数据之前有做一个if判断，如果buf数组的当前索引不在有效的索引范围之内，即 if 条件成立， buf 字段维护的缓冲区已经不够了，这时候会调用内部的fill()方法进行填充，而fill()会预读更多的数据到 buf 数组缓冲区中去，然后再返回当前字节数据，如果 if 条件不成立便直接从 buf缓冲区数组返回数据了。其中getBufIfOpen()返回的就是 buf字段的引用。顺便说下，源码中的 buf 字段声明为  protected volatile byte buf[];  主要是为了通过 volatile 关键字保证 buf数组在多线程并发环境中的内存可见性.

### 2. 什么是内存映射

Linux通过将一个虚拟内存区域与一个磁盘上的对象关联起来，以初始化这个虚拟内存区域的内容，这个过程称为内存映射(memory mapping)。虚拟内存区域可以映射到俩种类型的对象一种：

1. linux文件系统中的普通文件：一个区域可以映射到一个普通磁盘文件的连续部分。并且磁盘文件区被分成页大小的片，每一片包含一个虚拟页面的初始内容。此时并没有拷贝数据到内存中去，而是当进程代码第一次引用这段代码内的虚拟地址时，触发了缺页异常，这时候OS根据映射关系直接将文件的相关部分数据拷贝到进程的用户私有空间中去，当有操作第N页数据的时候重复这样的OS页面调度程序操作。**现在终于找出内存映射效率高的原因，原来内存映射文件的效率比标准IO高的重要原因就是因为少了把数据拷贝到OS内核缓冲区这一步（可能还少了native堆中转这一步）。如果区域比文件区要大，那么就用零来填充这个区域的余下部分。**
2. 匿名文件：一个区域也可以映射到一个匿名文件，匿名文件时有内核穿件的，包含的去不是二进制零。CPU第一次引用这样的一个区域内的虚拟页面时，内核就在物理内存中找到一个合适的牺牲页面，如果该页面被修改过，就将这个页面换出来，用二进制零覆盖牺牲页面并更新页表，经这个页面标记为是驻留在内存中的。注意在磁盘和内存之间并没有实际的数据传送。因为这个原因，映射到匿名文件的区域中的页面有时也叫做请求二进制零的页。

**注：如果你对虚拟内存不是很明白，推介你去看《深入理解操作系统》第九章**

### 3.NIO中内存映射

上面介绍了普通文件IO和内存映射，已经总结了为什么内存映射比普通的IO函数要快。现在来了解java中的内存映射，这也是NIO中的一个特性。其实java中的内存映射就是用c语言封装了一层，方便我们用java来调用，因此在了解概念的基础后，我们来看看如何使用。

  java中提供了3种内存映射模式，即：只读(readonly)、读写(read_write)、专用(private) ，

1. 对于只读模式来说，如果程序试图进行写操作，则会抛出ReadOnlyBufferException异常；
2. 第二种的读写模式表明了通过内存映射文件的方式写或修改文件内容的话是会立刻反映到磁盘文件中去的，别的进程如果共享了同一个映射文件，那么也会立即看到变化！而不是像标准IO那样每个进程有各自的内核缓冲区，比如Java代码中，没有执行 IO输出流的 flush() 或者  close() 操作，那么对文件的修改不会更新到磁盘去，除非进程运行结束；
3. 最后一种专用模式采用的是OS的“写时拷贝”原则，即在没有发生写操作的情况下，多个进程之间都是共享文件的同一块物理内存（进程各自的虚拟地址指向同一片物理地址），一旦某个进程进行写操作，那么将会把受影响的文件数据单独拷贝一份到进程的私有缓冲区中，不会反映到物理文件中去。

在Java NIO中可以很容易的创建一块内存映射区域，下面创建了一个只读方式的内存映射，代码如下：

```java
File file = new File("E:\download\office2007pro.chs.ISO");
FileInputStream in = new FileInputStream(file);
FileChannel channel = in.getChannel();
MappedByteBuffer buff = channel.map(FileChannel.MapMode.READ_ONLY, 0,channel.size());
```

接下来是我对普通的读写和内存映射方式的读写做的一个性能对比。

```java
package mapperBuffer;

/**************************************
 *      Author : zhangke
 *      Date   : 2019-03-16 16:29
 *      email  : 398757724@qq.com
 *      Desc   : 把400万条数据输入到文件中并且取出来 对比io和nio的效率
 *  * 当数据量过大的时候采用内存映射文件进行优化处理
 ***************************************/

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.ByteBuffer;
import java.nio.IntBuffer;
import java.nio.channels.FileChannel;

public class Demo {

    public static void main(String[] args) throws IOException {

        long start = System.currentTimeMillis();
        int count = 400_00000;
        String path = "temp_cache_tmp";
        String path2 = "temp_nio.tmp";
        String path3 = "temp_nio_mem.tmp";
        IoWrite(path, count);
        long end = System.currentTimeMillis();
        System.out.println("io写入时间" + (end - start));

        start = System.currentTimeMillis();
        IoRead(path, count);
        end = System.currentTimeMillis();
        System.out.println("io读取时间" + (end - start));

        start = System.currentTimeMillis();
        NioWrite(path2, count);
        end = System.currentTimeMillis();
        System.out.println("nio写入时间" + (end - start));

        start = System.currentTimeMillis();
        NioRead(path2, count);
        end = System.currentTimeMillis();
        System.out.println("nio读取时间" + (end - start));

        start = System.currentTimeMillis();
        NioMemeryWrite(path3, count);
        end = System.currentTimeMillis();
        System.out.println("nio内存映射文件写入" + (end - start));

        start = System.currentTimeMillis();
        NioMemeryRead(path3, count);
        end = System.currentTimeMillis();
        System.out.println("nio内存映射文件读取" + (end - start));
    }


    /**
     * 内存映射文件 读取
     **/
    public static void NioMemeryRead(String path, int count) {
        FileChannel fc = null;
        try {
            fc = new FileInputStream(path).getChannel();
            IntBuffer ib = fc.map(FileChannel.MapMode.READ_ONLY, 0, fc.size()).asIntBuffer();
            while (ib.hasRemaining()) {
                ib.get();
            }

        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            if (fc != null) {
                try {
                    fc.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
    }


    //内存映射文件进行写入数据
    public static void NioMemeryWrite(String path, int count) {
        FileChannel fc = null;
        ;
        try {
            fc = new RandomAccessFile(path, "rw").getChannel();
            IntBuffer ib = fc.map(FileChannel.MapMode.READ_WRITE, 0, count * 4).asIntBuffer();
            for (int i = 0; i < count; i++) {
                ib.put(i);
            }
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            if (fc != null) {
                try {
                    fc.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }

    }


    /**
     * 普通io进行读取
     **/
    public static void IoRead(String path, int count) {
        File file = new File(path);
        DataInputStream dis = null;
        try {
            dis = new DataInputStream(new BufferedInputStream(
                    new FileInputStream(file)));
            for (int i = 0; i < count; i++) {
                dis.readInt();

            }
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            if (dis != null) {
                try {
                    dis.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }

        }

    }


    /*
     * 普通io进行读操作
     */
    public static void IoWrite(String path, int count) {
        File f = new File(path);
        if (!f.exists()) {
            try {
                f.createNewFile();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
        DataOutputStream dos = null;
        try {
            dos = new DataOutputStream(new BufferedOutputStream(
                    new FileOutputStream(f)));
            for (int i = 0; i < count; i++) {
                dos.writeInt(i);
            }
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            if (dos != null) {
                try {
                    dos.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }

    }


    public static int byte2int(byte b1, byte b2, byte b3, byte b4) {
        return ((b1 & 0xff) << 24) | ((b2 & 0xff) << 16) | ((b3 & 0xff) << 18)
                | (b4 & 0xff);
    }


    public static byte[] int2byte(int res) {
        byte[] targets = new byte[4];
        targets[3] = (byte) (res & 0xff);
        targets[2] = (byte) ((res >> 8) & 0xff);
        targets[1] = (byte) ((res >> 16) & 0xff);
        targets[0] = (byte) ((res >>> 24) & 0xff);
        return targets;
    }


    /**
     * 采用Nio进行读取
     */
    public static void NioRead(String path, int count) {
        File file = new File(path);
        FileInputStream fin = null;
        try {
            fin = new FileInputStream(file);
            FileChannel fc = fin.getChannel();
            ByteBuffer byteBuffer = ByteBuffer.allocate(count * 4);
            fc.read(byteBuffer);
            fc.close();
            byteBuffer.flip();
            while (byteBuffer.hasRemaining()) {
                byte2int(byteBuffer.get(), byteBuffer.get(), byteBuffer.get(),
                        byteBuffer.get());
            }
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }


    /**
     * 采用Nio进行写
     */
    public static void NioWrite(String path, int count) {
        File file = new File(path);
        FileOutputStream fout = null;
        try {
            fout = new FileOutputStream(file);
            FileChannel fileChannel = fout.getChannel();
            ByteBuffer byteBuffer = ByteBuffer.allocate(4 * count);
            for (int i = 0; i < count; i++) {
                byteBuffer.put(int2byte(i));
            }
            byteBuffer.flip();
            fileChannel.write(byteBuffer);
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            if (fout != null) {
                try {
                    fout.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }

        }

    }
}
```

测试结果

```
io写入时间3266
io读取时间3123
nio写入时间858
nio读取时间274
nio内存映射文件写入153
nio内存映射文件读取29
```

上面测试了普通IO，NIO和NIO内存映射的读写性能。从上可以看出，内存映射的读写性能远胜于其他俩种。文件越大，差距便越大。所以内存映射文件特别适合于对大文件的操作，Java中的限制是最大不得超过 Integer.MAX_VALUE，即2G左右，不过我们可以通过多次映射文件(channel.map)的不同部分来达到操作整个文件的目的。

按照jdk文档的官方说法，内存映射文件属于JVM中的直接缓冲区，还可以通过 ByteBuffer.allocateDirect() ，即DirectMemory的方式来创建直接缓冲区。他们相比基础的 IO操作来说就是少了中间缓冲区的数据拷贝开销。同时他们属于JVM堆外内存，不受JVM堆内存大小的限制。

### 4. 直接内存

DirectMemory 默认的大小是等同于JVM最大堆，理论上说受限于进程的虚拟地址空间大小，比如32位的windows上，每个进程有4G的虚拟空间除去 2G为OS内核保留外，再减去 JVM堆的最大值，剩余的才是DirectMemory大小。通过设置 JVM参数 -Xmx64M，即JVM最大堆为64M，然后执行以下程序可以证明DirectMemory不受JVM堆大小控制：

```java
 public static void main(String[] args) {	   
   ByteBuffer.allocateDirect(1024*1024*100); // 100MB
   }
```
我们设置了JVM堆64M限制，然后在直接内存上分配了 100MB空间，程序执行后直接报错：**Exception in thread "main" java.lang.OutOfMemoryError: Direct buffer memory**。

接着我设置 -Xmx200M，程序正常结束。然后我修改配置： -Xmx64M  -XX:MaxDirectMemorySize=200M，程序正常结束。因此得出结论： 直接内存DirectMemory的大小默认为 -Xmx 的JVM堆的最大值，但是并不受其限制，而是由JVM参数 MaxDirectMemorySize单独控制。接下来我们来证明直接内存不是分配在JVM堆中。我们先执行以下程序，并设置 JVM参数       **-XX:+PrintGC** 

```
 public static void main(String[] args) {	   
	 for(int i=0;i<20000;i++) {
            ByteBuffer.allocateDirect(1024*100);  //100K
       }
   }
```

  输出结果如下：

     [GC 1371K->1328K(61312K), 0.0070033 secs]
     [Full GC 1328K->1297K(61312K), 0.0329592 secs]
     [GC 3029K->2481K(61312K), 0.0037401 secs]
     [Full GC 2481K->2435K(61312K), 0.0102255 secs]

我们看到这里执行 GC的次数较少，但是触发 两次 Full GC，原因在于直接内存不受GC(新生代的Minor GC)影响，只有当执行老年代的 Full GC时候才会顺便回收直接内存！而直接内存是通过存储在JVM堆中的DirectByteBuffer对象来引用的，所以当众多的DirectByteBuffer对象从新生代被送入老年代后才触发了full gc。

  再看直接在JVM堆上分配内存区域的情况：

 ```java
public static void main(String[] args) {	   
    for(int i=0;i<10000;i++) {
        ByteBuffer.allocate(1024*100);  //100K
    }
}
 ```

  ByteBuffer.allocate 意味着直接在 JVM堆上分配内存，所以受新生代的 Minor GC影响，输出如下：


    [GC 16023K->224K(61312K), 0.0012432 secs]
    [GC 16211K->192K(77376K), 0.0006917 secs]
    [GC 32242K->176K(77376K), 0.0010613 secs]
    [GC 32225K->224K(109504K), 0.0005539 secs]
    [GC 64423K->192K(109504K), 0.0006151 secs]
    [GC 64376K->192K(171392K), 0.0004968 secs]
    [GC 128646K->204K(171392K), 0.0007423 secs]
    [GC 128646K->204K(299968K), 0.0002067 secs]
    [GC 257190K->204K(299968K), 0.0003862 secs]
    [GC 257193K->204K(287680K), 0.0001718 secs]
    [GC 245103K->204K(276480K), 0.0001994 secs]
    [GC 233662K->204K(265344K), 0.0001828 secs]
    [GC 222782K->172K(255232K), 0.0001998 secs]
    [GC 212374K->172K(245120K), 0.0002217 secs]

可以看到，由于直接在 JVM堆上分配内存，所以触发了多次GC，且不会触及 Full GC，因为对象根本没机会进入老年代。

在这里要来探讨一下内存映射和DirectMemory的内存回收问题。NIO中的DirectMemory和内存文件映射同属于直接缓冲区，但是前者和 -Xmx和-XX:MaxDirectMemorySize有关，而后者完全没有JVM参数可以影响和控制，这让我不禁怀疑两者的直接缓冲区是否相同，前者指的是Java进程中的native堆，因为C语言中的 malloc()分配的内存就属 native堆，不属 JVM堆，这也是DirectMemory能在一些场景中显著提高性能的原因，因为它避免了在 native堆和jvm堆之间数据的来回复制；而后者则是没有经过native堆，是由Java进程直接建立起某一段虚拟地址空间和文件对象的关联映射关系，所以内存映射文件的区域并不在JVM GC的回收范围内，因为它本身就不属于堆区，卸载这部分区域只能通过系统调用 unmap()来实现 (Linux)中，而Java API 只提供了 FileChannel.map 的形式创建内存映射区域，却没有提供对应的 unmap()。

事实是由JVM帮助我们自动回收这部分内存，在定义这些类时，通过一个虚引用包裹这些创建的NIO对象，当JVM进行GC时检测指向这些内存映射或者直接内存的java对象是否被回收（java对象都是保存在堆上，只是对象中使用变量空间指向对外内存）。如果这些对象被回收，那么JVM就会自动的帮助我们回收这些堆外内存。具体参考：[堆外内存 之 DirectByteBuffer 详解](https://www.jianshu.com/p/007052ee3773)

最后再试试通过 DirectMemory来操作前面内存映射和基本通道操作的例子，来看看直接内存操作的话，程序的性能如何：

```java
    @Test
    public void directBufferTest() throws IOException {
        File file = new File(path);
        FileInputStream in = new FileInputStream(file);
        FileChannel channel = in.getChannel();
        
        ByteBuffer buff = ByteBuffer.allocateDirect(1024);

        long begin = System.currentTimeMillis();
        while (channel.read(buff) != -1) {
            buff.clear();
        }
        long end = System.currentTimeMillis();
        System.out.println("time is:" + (end - begin));
        in.close();
    }
```

程序输出为 130毫秒，看来比普通的NIO通道操作（160毫秒）来的快，但是比 mmap 内存映射的 30差距太多了，我想应该不至于吧，通过修改：

```
ByteBuffer buff = ByteBuffer.allocateDirect(1024);  
//将上面语句修改如下
ByteBuffer buff = ByteBuffer.allocateDirect((int)file.length())，
```

即一次性分配整个文件长度大小的堆外内存，最终输出为 78毫秒，由此可以得出两个结论：

1. 堆外内存的分配耗时比较大.  

2. 还是比mmap内存映射来得慢，都不要说通过mmap读取数据的时候还涉及缺页异常、页面调度的系统调用了。

最后一点为 DirectMemory的内存只有在 JVM执行 full gc 的时候才会被回收，那么如果在其上分配过大的内存空间，那么也将出现 OutofMemoryError，即便 JVM 堆中的很多内存处于空闲状态。

补充下额外的一个知识点，关于 JVM堆大小的设置是不受限于物理内存，而是受限于虚拟内存空间大小，理论上来说是进程的虚拟地址空间大小，但是实际上我们的虚拟内存空间是有限制的，一般windows上默认在C盘，大小为物理内存的2倍左右。我做了个实验：我机子是 64位的win7，那么理论上说进程虚拟空间是几乎无限大，物理内存为4G，而我设置 -Xms5000M， 即在启动JAVA程序的时候一次性申请到超过物理内存大小的5000M内存，程序正常启动，而当我加到 -Xms8000M的时候就报OOM错误了，然后我修改增加 win7的虚拟内存，程序又正常启动了，说明 -Xms 受限于虚拟内存的大小。我设置-Xms5000M，即超过了4G物理内存，并在一个死循环中不断创建对象，并保证不会被GC回收。程序运行一会后整个电脑几乎死机状态，即卡住了，反映很慢很慢，推测是发生了系统颠簸，即频繁的页面调度置换导致，说明 -Xms -Xmx不是局限于物理内存的大小，而是综合虚拟内存了，JVM会根据电脑虚拟内存的设置来控制。

###  参考

1. [JAVA NIO之浅谈内存映射文件原理与DirectMemory](https://blog.csdn.net/fcbayernmunchen/article/details/8635427)