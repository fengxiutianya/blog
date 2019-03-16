---
title: java 打包技术之jar文件
tags:
  - java
  - jar
categories:
  - java
author: zhangke
abbrlink: 2f7bd7dc
date: 2019-01-08 08:55:00
---
# java 打包技术之jar文件

### 概述

1. jar技术简介及使用
2. Manifest文件

### jar技术简介及使用

本文主要是参照[Lesson: Packaging Programs in JAR Files](https://docs.oracle.com/javase/tutorial/deployment/jar/apiindex.html)来写，如果你的英文不错，可以直接看这个java官方教程。

在开始看下文你需要确认你安装的jdk环境带有jar命令，只需要在命令行中输入**jar -h**看看能不能找到命令即可。如果你安装的是oracle JDK，那么这个命令已经内置在java开发套件中。

下文所使用的源代码地址[gihub](https://github.com/fengxiutianya/blogsource/tree/master/jarstudy)
<!-- more -->
**jar技术是什么以及可以用来干什么？**

官方给出的解释如下：JAR文件以zip文件格式打包，因此您可以将其用于无损数据压缩、归档、解压缩和归档解包等任务。这些任务是JAR文件最常见的用途之一，您只需使用这些基本特性就可以实现许多JAR文件的好处。

我这里先不解释这句话，先看看例子，最后我们来总结一些自己理解的jar技术。

#### 创建jar文件

基本的命令格式

```
jar cf jar-file input-file(s)
```

命令解释：

1. `c` :代表创建一个jar文件
2. `f`: 代表将创建的jar文件输入到指定的文件而不是stdout
3. `jar-file`： 表示创建这个jar文件的名字，通常是以jar后缀结尾，但这不是必须。
4. `input-file(s)`: 代表要包含在jar文件包中的一个或更多的文件，如果是多个文件，以空格隔开，也可以使用通配符`*`来表示所有的文件，如果指定的是文件夹，将递归的将此文件夹中所有的文件都打包进jar中。

参数`c`和`f`的顺序可以是任意的。此命令还会创建一个默认的manifest文件（这个后面会说）。

下面这些参数都是可选的，可以和上面一起使用

|   可选项   |                                             意义                                             |
|:-------:|:------------------------------------------------------------------------------------------:|
|    v    |                                      当创建jar文件时，打印创建过程                                      |
| 0（zero） |                                            不压缩文件                                           |
|    M    |                                      不创建默认的manifest文件                                      |
|    m    | 用来包含指定manifest信息从指定文件中<br />使用格式如下<br />`jar cmf jar-file existing-manifest input-file(s)` |
|    -C   |                                      用于修改打包过程中文件的具体位置                                      |

具体例子:

文件夹内容如下

```
demo1
	Main.class
	images
		test.png
		ico.gif 
	audio
		test.log
```



打包所有文件到一个单个jar文件，命令如下：

```
jar cvf demo1.jar Main.clss audio images
```

执行命令结果

```
已添加清单
正在添加: Main.class(输入 = 409) (输出 = 282)(压缩了 31%)
正在添加: audio/(输入 = 0) (输出 = 0)(存储了 0%)
正在添加: images/(输入 = 0) (输出 = 0)(存储了 0%)
正在添加: images/test.png(输入 = 0) (输出 = 0)(存储了 0%)
正在添加: images/ico.gif(输入 = 0) (输出 = 0)(存储了 0%)
```

从上面的结果可以看出，这个命令在打包过程中压缩了文件。

如果不想压缩使用如下命令

```
jar cvf0 demo1.jar Main.clss audio images
```

如果打包的是整个文件夹下的内容，也可以采用下面的命令

```
jar cvf demo1.jar *
```

如果你希望在打包过程中改变某个文件的位置，可以使用`-C`参数，注意这里是大写的C

```
jar cvf demo1.jar Main.class -C audio . -C images .
```

打包之后，demo1.jar包中的文件位置如下

```
META-INF/
META-INF/MANIFEST.MF
Main.class
test.log
test.png
ico.gif
```

如果没有使用`-C`则包中的文件位置如下

```
META-INF/
META-INF/MANIFEST.MF
Main.class
audio/
audio/test.log
images/
images/test.png
images/ico.gif
```

#### 查看jar文件的内容

这个也是我上面为什么能显示包中文件位置使用的命令。

基本命令格式

```
jar tf jar-file
```

命令解释

1. `t`: 表示显示jar文件的目录
2. `f`:表示显示的jar文件在命令的参数中
3. Jar-file:显示的文件的具体位置

具体例子

```
jar tf demo1.jar
```

输出结果

```
META-INF/
META-INF/MANIFEST.MF
Main.class
audio/
audio/test.log
images/
images/test.png
images/ico.gif
```

使用选项`V`也可以显示额外的信息，具体的就不演示。

#### 解压jar文件的内容

基本的命令格式

```ba&#39;sh
jar xf jar-file [archived-file(s)]
```

命令解释：

1. `x`:表示解压这个jar

2. `[archived-file(s)]`:如果没有这个参数，则解压所有的文件，如果有这个文件解压所有的文件

   其他的和上面的命令一样

具体例子

```bash
## 解压所有的内容
jar xf demo1.jar

## 解压指定的文件
jar xf demo1.jar Main.class images/ico.gif

```

上面的命令会解压所有的文件或者指定的文件到当前目录中，如果当前目录中不存在则创建。

#### 更新jar文件

基本的命令格式

```
jar uf jar-file input-file(s)
```

命令解释：

1. `u`:表示更新文件

其他选项和参数与上面一样

例子

**demo1.jar**的内容如下

```
META-INF/
META-INF/MANIFEST.MF
Main.class
audio/
audio/test.log
images/
images/test.png
images/ico.gif
```

执行下面命令

```
jar uf demo1.jar ../demo2/tem.log
```

**demo1.jar**文件内容如下

```
META-INF/
META-INF/MANIFEST.MF
Main.class
audio/
audio/test.log
images/
images/test.png
images/ico.gif
demo2/tem.log
```

#### 运行jar

如果你看到这里可以跳过，先看后面的内容然后再来看这一块的内容。

如果你希望你打包的jar可以运行，那么就需要在mainfest文件中添加这样一行内容**Main-class: 入口函数，也就是main函数所在的类**，具体怎么添加可以看下文。

运行命令

```
java -jar jar-filename
```
**总结：**其实jar文件就是按照某个特定格式打包的文件，和普通的zip打包的文件没什么区别，这点你可以用解压软件来测试。只不过这个打包的文件里面需要按照java官方规定放置一些特定的文件来方便jar运行或者引用时使用。

### Manifest文件

JAR文件支持广泛的功能，包括电子签名、版本控制、包密封等。什么使JAR文件具有这种多功能性？答案是JAR文件的清单。清单是一个特殊的文件，可以包含关于打包在JAR文件中的文件的信息。通过定制清单包含的这个“元”信息，您可以使JAR文件满足各种目的。

#### 默认Manifest

在前面我们也说过，当创建jar文件时，会默认创建**META-INF/MANIFEST.MF**这样的文件，这个也就是我们所说的manifest文件，只不过是默认生成的，里面的具体内容是什么呢，主要是下面俩行：

```
Manifest-Version: 当前jar的版本号
Created-By: 创建的jdk名称和版本号
```

通过上面俩行你大概也猜出这个文件的具体格式**header:value**每一对是通过换行符分割开。

#### 修改Manifest文件

基本命令格式

```
jar cfm jar-file manifest-addition input-file(s)
```

命令解释

1. m：表示希望合并指定文件中的内容到manifest文件中去。
2. `manifest-addition`:希望合并到manifest文件中的文件名

m和f参数的具体位置必须和上面的相同。

#### 设置应用的入口点

设置入口点也就是增加main函数所在位置，主要是在Manifest文件中加入这一行即可`Main-Class: classname`

加入这行代码之后，就可以使用`jar -jar jar-name`来运行这个jar。

具体例子

首先在当前目录下创建一个文件，名字Manifest.txt,内容如下**这里需要特别注意一点，在这行后面敲一个换行符，要不然这行是添加不进Manifest文件中去，这个在java官方文档中也有说**

```
Main-class: Main (类名要根据你的具体环境来配置，是类的完整路径) 
```

创建jar

```
jar cfm demo1.jar Manifest.txt *.class
```

使用`jar tf demo1.jar`查看文件的内容如下

```
META-INF/
META-INF/MANIFEST.MF
Main.class
```

使用`jar xf demo1.jar  META-INF/MANIFEST.MF` 解压指定的文件，查看内容如下

```
Manifest-Version: 1.0
Created-By: 1.8.0_144 (Oracle Corporation)
Main-class: Main

```

运行jar

```
java -jar demo1.jar
```

结果

```
zhangke
```

运行正确，我在main函数里面就打印了一下我的名称。

通过上面例子我们实现了一个简单的可运行的jar，并且熟悉了前面的内容。

#### 添加类路径到jar文件的类路径中

一般我们在开发项目中，都会用到其他的包，那么我们就需要将这些jar添加到当前jar的类路径中。

也就是添加下面这样一行

```
Class-Path: jar1-name jar2-name directory-name/jar3-name
```

注意的一点是：路径头指向本地网络上的类或JAR文件，而不是JAR文件中的JAR文件或通过Internet协议访问的类。要将JAR文件中的JAR文件中的类加载到类路径中，必须编写自定义代码来加载这些类。例如，如果myjar.jar包含另一个jar文件myutils.jar，则不能使用myjar.jar清单中的类路径头将myutils.jar中的类加载到类路径中

具体例子

1. 创建demo2文件夹，将上面demo1打包成demo1.jar,注意这里不写Main-class，直接使用

   ```
   jar  cf demo1.jar *.class
   ```

2. 将上面打包的demo1.jar,放到lib目录下面

3. 创建manifest.txt添加如下内容

   ```
   Main-class: Main
   Class-path: lib/demo1.jar
   ```

4. 打包此目录

   ```
    jar cfm demo2.jar Manifest.txt *
   ```

5. 运行jar

   ```
   java -jar demo2.jar
   ### 运行结果
   zhangke
   ```

   说明导入的jar已经生效。这有点类似于设置java.ext.path选项，不过我觉得这种比较好，因为将所有的jar打包到jar中，不用在单独的下载所有的依赖。

#### package sealing 

我感觉翻译过来不怎好，就没翻译，直接使用英文。

那么什么是package sealing，简单的说就是将你使用的外部依赖直接打包到你当前的文件中去，和上面添加类路径我现在还没感觉到有什么区别。这里就先不说。后面如果发现了，再来添加。

主要格式如下,在manifest文件中加入下面俩行

```
Name: 包名
Sealed: true
```

如果你有多个不同的包，可以设置多行，

如果希望将所有的包都sealing，那么直接写上，`Sealed:true`

具体的例子可以看这篇[Java中 Package Sealing 的探秘之旅](https://blog.csdn.net/TechNerd/article/details/8945587)



从官方的解释可以看出，jar是采用zip来进行打包，只不过打包的后缀名都已jar来命名，因大家习惯上就成为jar文件，另外如果希望jar能够被使用或者运行，那么就需要遵循java委员会定义的一些规则。

### 参考

1. [ JAR : MANIFEST.MF Class-Path referencing a directory](http://todayguesswhat.blogspot.com/2011/03/jar-manifestmf-class-path-referencing.html) 设置class-path路径，对比了绝对和相对路径
2. [Java中 Package Sealing 的探秘之旅](https://blog.csdn.net/TechNerd/article/details/8945587)