---
title: Spring源码解析之 01环境搭建
tags:
  - spring源码解析
categories:
  - java
  - spring
  - spring 源码分析
  - SpringCore
author: fengxiutianya
abbrlink: c51c4fa0
date: 2019-01-07 03:33:00
---
# spring源码解析之 01环境搭建

### 概述

1. 前提条件
2. 环境搭建

### 1. 前提条件

Spring采用gradle来进行包管理，因此你需要安装gradle，这个网上面有很多的教程，就不在这里进行介绍。

另外Spring的源码时放在github上，因此你需要安装git。

spring 5 默认是jdk1.8以上的java版本 ，因此需要你本地的java环境是为1.8 以上。

<!-- more -->

### 2. 环境搭建

1. 下载源代码

   ```
   git clone git@github.com:spring-projects/spring-framework.git
   ```

   下载好源码之后，因为git默认是在master分支上，本文使用的是**v5.1.3.RELEASE**，因此你需要切换到指定的版本下，使用下面命令

   ```
   git checkout v5.1.3.RELEASE
   ```

2. 导入IDE

   在源码下面有俩个markdown文件，分别是**import-into-idea.md**和**import-into-eclipse.md**

   这俩个文件分别针对俩大主流的IDE来介绍如何导入。我平常使用的IDE是idea，所以这篇文章也是介绍如何在idea搭建环境

   导入分为俩步

   1. 预先编译spring-oxm

      切换到项目根目录，使用如下命令

      ```
      ./gradlew :spring-oxm:compileTestJava
      ```

   2. 导入项目

      这里只有一点是需要注意的，选择导入环境时，选择gradle即可，其他的就是等待下载依赖和构建。这个过程时间挺长，不过这个和你的电脑配置以及网络有关。