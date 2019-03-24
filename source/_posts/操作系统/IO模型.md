---
title: IO模型：阻塞、非阻塞、同步和异步之间的区别
abbrlink: aeafbee0
tags:
  - 操作系统
categories:
  - 操作系统
date: 2019-03-22 23:04:13
---
## 概述
在Unix系统中，主要有以下5种IO模型:
* 阻塞式IO
* 非阻塞式IO
* IO复用
* 信号量式驱动IO
* 异步IO

本篇文章主要是想弄明白阻塞和非阻塞、同步与异步之间的区别，因此信号量式驱动IO本篇文章不会涉及，如果以后我用到的话，会在来补充。

对于一个network IO (这里我们以read举例)，它会涉及到两个系统对象，一个是调用这个IO的process (or thread)，另一个就是系统内核(kernel)。当一个read操作发生时，它会经历两个阶段：

1. 等待数据准备 (Waiting for the data to be ready)
2. 将数据从内核拷贝到进程中 (Copying the data from the kernel 
    to the process)

记住这两点很重要，因为这些IO Model的区别就是在两个阶段上各有不同的情况。下面首先介绍每种IO模型，然后在来总结他们之间的区别。
<!-- more -->
## IO模型
### 阻塞式IO模型
在linux中，默认情况下所有的socket都是blocking，一个典型的读操作流程大概是这样：

![Xnip2019-03-22_23-17-28](/images/Xnip2019-03-22_23-17-28.jpg)
当用户进程调用了recvfrom这个系统调用，kernel就开始了IO的第一个阶段：准备数据。对于network io来说，很多时候数据在一开始还没有到达，这个时候kernel就要等待足够的数据到来。而在用户进程这边，整个进程会被阻塞。当kernel一直等到数据准备好，它就会将数据从kernel中拷贝到用户内存，然后kernel返回结果，用户进程才解除block的状态，重新运行起来。

阻塞式IO的特点就是在IO执行的两个阶段都被block了。
### 非租塞式IO模型
linux下，可以通过设置socket使其变为non-blocking。当对一个non-blocking socket执行读操作时，流程如下图：

![Xnip2019-03-22_23-23-06](/images/Xnip2019-03-22_23-23-06.jpg)
从图中可以看出，当用户进程发出read操作时，如果kernel中的数据还没有准备好，那么它并不会block用户进程，而是立刻返回一个error。从用户进程角度讲 ，它发起一个read操作后，并不需要等待，而是马上就得到了一个结果。用户进程判断结果是一个error时，它就知道数据还没有准备好，于是它可以再次发送read操作。一旦kernel中的数据准备好了，并且又再次收到了用户进程的system call，那么它马上就将数据拷贝到了用户内存，然后返回。

当一个应用进程像这样对一个非阻塞描述符循环调用recvfrom时，我们称之为轮询。应用进程持续轮询内核，已查看某个操作是否就绪，这么操作往往耗费大量的CPU时间。

非阻塞式IO虽然没有在第一个阶段阻塞用户进程，但是用户进程其实是需要不断的主动询问kernel数据好了没有。

### IO复用模型
IO复用这个词可能有点陌生，但是如果我说select，epoll，大概就都能明白了。有些地方也称这种IO方式为event driven IO。我们都知道，select/epoll的好处就在于单个process就可以同时处理多个网络连接的IO。它的基本原理就是select/epoll这个function会不断的轮询所负责的所有socket，当某个socket有数据到达了，就通知用户进程。它的流程如下图：

![Xnip2019-03-22_23-31-08](/images/Xnip2019-03-22_23-31-08.jpg)
当用户进程调用了select，那么整个进程会被block，而同时，kernel会“监视”所有select负责的socket，当任何一个socket中的数据准备好了，select就会返回。这个时候用户进程再调用read操作，将数据从kernel拷贝到用户进程。

这个图和阻塞式IO的图其实并没有太大的不同，事实上，还更差一些。因为这里需要使用两个system call (select 和 recvfrom)，而blocking IO只调用了一个system call (recvfrom)。但是，用select的优势在于它可以同时处理多个connection。

与IO复用模型密切相关的另一种IO模型是在多线程中使用阻塞式IO，这种模型与上述模型极为相似，但它没有使用select阻塞在多个文件描述符上，而是使用多个线程（每个文件描述符一个线程），这样每个线程都可以自由的调用诸如recvfrom子类的阻塞式的IO系统调用。
这里补充俩点：
1. 如果处理的连接数不是很高的话，使用select/epoll的web server不一定比使用multi-threading + blocking IO的web server性能更好，可能延迟还更大。select/epoll的优势并不是对于单个连接能处理得更快，而是在于能处理更多的连接。
   
2. 如果连接非常多，多线程模式的性能就会下降，多线程切换会导致一定损耗，如果我们有一个线程专门负责select操作，其他线程负责处理数据已经准备好的连接符操作，这样可以减少创建的线程，从而减少线程切换的损耗。这就是Reactor模型快的原因之一。

在IO复用模型中，对于每一个socket，一般都设置成为非阻塞，但是，如上图所示，整个用户进程其实是一直被阻塞。只不过用户进程是被select调用阻塞，而不是被Socket IO阻塞。
### 异步IO模型
linux下的异步IO其实用得很少，我看过一篇文章，说linux异步IO的底层使用的还是Epoll，因此性能不是很好，而异步IO实现相对较好的是windows系统。先看一下它的流程：
![Xnip2019-03-22_23-44-28](/images/Xnip2019-03-22_23-44-28.jpg)
用户进程发起read操作之后，立刻就可以开始去做其它的事。而另一方面，从kernel的角度，当它受到一个异步读之后，首先它会立刻返回，所以不会对用户进程产生任何阻塞。然后，内核会等待数据准备完成，然后将数据拷贝到用户内存，当这一切都完成之后，内核会给用户进程发送一个信号，告诉它read操作完成了。

异步IO特点：在IO执行的俩个阶段都不会阻塞。
## 总结
**阻塞和非阻塞IO**定义
1. **阻塞IO**：阻塞IO会一直阻塞住对应的进程直到操作完成。
2. **非阻塞IO**：非阻塞IO是指在内核还没准备好数据的情况下立刻返回。而从内核向用户进程拷贝数据阶段是阻塞。

**异步IO和同步IO**定义，POSIX的定义如下：
1. **同步IO**：A synchronous I/O operation causes the requesting process to be blocked until that I/O operation completes;
2. **异步IO**An asynchronous I/O operation does not cause the requesting process to be blocked; 

两者的区别就在于异步IO做IO操作的时候会将进程阻塞。按照这个定义，之前所述的blocking IO，non-blocking IO，IO multiplexing都属于synchronous IO。有人可能会说，non-blocking IO并没有被阻塞。这里有个非常“狡猾”的地方，定义中所指的”IO operation”是指真实的IO操作，就是例子中的recvfrom这个system call。non-blocking IO在执行recvfrom这个system call的时候，如果kernel的数据没有准备好，这时候不会block进程。但是，当kernel中数据准备好的时候，recvfrom会将数据从kernel拷贝到用户内存中，这个时候进程是被block了，在这段时间内，进程是被block的。而asynchronous IO则不一样，当进程发起IO 操作之后，就直接返回再也不理睬了，直到kernel发送一个信号，告诉进程说IO完成。在这整个过程中，进程完全没有被block。
**各种IO模型比图如下**
![Xnip2019-03-23_00-02-42](/images/Xnip2019-03-23_00-02-42.jpg)
经过上面的介绍，会发现non-blocking IO和asynchronous IO的区别还是很明显的。在non-blocking IO中，虽然进程大部分时间都不会被block，但是它仍然要求进程去主动的检查，并且当数据准备完成以后，也需要进程主动的再次调用recvfrom来将数据拷贝到用户内存。而asynchronous IO则完全不同。它就像是用户进程将整个IO操作交给了他人（kernel）完成，然后他人做完后发信号通知。在此期间，用户进程不需要去检查IO操作的状态，也不需要主动的去拷贝数据。
## 参考
1. [ UNIX网络编程 卷1：套接字联网API（第3版）](https://book.douban.com/subject/4859464/)
2. [IO - 同步，异步，阻塞，非阻塞 （亡羊补牢篇）](https://blog.csdn.net/historyasamirror/article/details/5778378)