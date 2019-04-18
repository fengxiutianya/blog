---
title: linux命令之time
abbrlink: 3374b24f
categories:
  - linux
date: 2019-04-17 20:29:16
tags:
  - time
---
time 命令用于统计给定命令所花费的时间。

**语法**
```
time [-f 参数] 命令
```
当测试一个程序或比较不同算法时，执行时间是非常重要的，一个好的算法应该是用时最短的。所有类UNIX系统都包含time命令，使用这个命令可以统计时间消耗。例如：
``` shell
$ time ls
 ......

real    0m0.016s
user    0m0.002s
sys     0m0.000s
```
<!-- more -->
执行time命令，默认输出的信息分别显示了该命令所花费的real时间、user时间和sys时间。
* **real** ： 时间是指挂钟时间，也就是命令开始执行到结束的时间。这个短时间包括其他进程所占用的时间片，和进程被阻塞时所花费的时间（比如等待IO完成的时间）。
* **user**：时间是指进程花费在用户模式中的CPU时间，这是唯一真正用于执行进程所花费的时间，其他进程和花费阻塞状态中的时间没有计算在内。
* **sys**：时间是指花费在内核模式中的CPU时间，代表在内核中执系统调用所花费的时间，这也是真正由进程使用的CPU时间。

使用-o选项将执行时间写入到文件中：
``` shell
/usr/bin/time -o outfile.txt ls
```
使用-a选项追加信息：
``` shell
/usr/bin/time -a -o outfile.txt ls
```
使用-f选项格式化时间输出：
``` shell
/usr/bin/time -f "time: %U" ls
```
-f选项后的参数：
```
%E	real时间，显示格式为[小时:]分钟:秒
%U	user时间。
%S	sys时间。
%C	进行计时的命令名称和命令行参数。
%D	进程非共享数据区域，以KB为单位。
%x	命令退出状态。
%k	进程接收到的信号数量。
%w	进程被交换出主存的次数。
%Z	系统的页面大小，这是一个系统常量，不用系统中常量值也不同。
%P	进程所获取的CPU时间百分百，这个值等于user+system时间除以总共的运行时间。
%K	进程的平均总内存使用量（data+stack+text），单位是KB。
%w	进程主动进行上下文切换的次数，例如等待I/O操作完成。
%c	进程被迫进行上下文切换的次数（由于时间片到期）。
```
上面已经将基本的命令解释完，下面讲一下real，sys，user这三个的关系。
###  real_time = user_time + sys_time
经常错误的理解为，real time 就等于 user time + sys time，这是不对的，real time是时钟走过的时间，user time 是程序在用户态的cpu时间，sys time 为程序在核心态的cpu时间。

利用这三者，我们可以计算程序运行期间的cpu利用率如下：
```
%cpu_usage = (user_time + sys_time)/real_time * 100%
```

如：
```
time sleep 2

real 0m2.003s
user 0m0.000s
sys 0m0.000s
```
cpu利用率为0，因为本身就是这样的，sleep 了2秒，时钟走过了2秒，但是cpu时间都为0，所以利用率为0


### real_time > user_time + sys_time
一般来说，上面是成立的，上面的情况在单cpu的情况下，往往都是对的。但是在多核cpu情况下，而且代码写的确实很漂亮，能把多核cpu都利用起来，那么这时候上面的关系就不成立了，例如可能出现下面的情况。
```
 real 1m47.363s
 user 2m41.318s
 sys 0m4.013s
```
## 参考
1. [time命令](http://man.linuxde.net/time)
2. [What do 'real', 'user' and 'sys' mean in the output of time(1)?](https://stackoverflow.com/questions/556405/what-do-real-user-and-sys-mean-in-the-output-of-time1)