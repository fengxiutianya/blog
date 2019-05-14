---
title: ubuntu安装字体
abbrlink: dd3a9eb3
categories:
  - linux
date: 2019-05-14 15:51:23
tags:
  - 字体
---
最近在学习使用latex，需要一些windows下面特有的字体，因此需要安装这些字体到ubuntu下面。本篇文章将主要记录我在ubuntu中安装windows中的字体过程。也适用于安装其他的字体。另外这个安装过程适用于以Debian为基础的系统。
<!-- more  -->
linux系统的字体文件放在`/usr/share/fonts/`目录以及用户的`~/.fonts`和`~/.local/share/fonts`目录下，第一个位置为系统所用用户共享，将字体安装到这个目录需要管理员权限；后面两个位置则为当前登陆用户所有，安装字体到这个目录不需要管理员权限。 

下面来讲解我的安装过程。
### 安装字体到`/usr/share/fonts`
```  shell
## 准备安装的字体，这里是我从windows下面拷贝过来的，目录名称font

## 最好自己在/usr/share/fonts 目录下面创建一个子目录放置自己需要安装的字体
sudo mkdir -p /usr/share/fonts/windows
sudo mv font /usr/lshare/fonts/windows

## 生成核心字体，下面俩个命令是可选
sudo mkfontscale
sudo mkfontdir

## 刷新字体缓存
sudo fc-cache -fv
```
上面已经成功安装字体到系统中，但是如何确定安装是否成功呢，下面是我自己想的办法，如果你有好的办法，可以留言给我。
下面这个命令可以查看系统中的所有字体
``` shell
fc-list  # 查看所有的字体
fc-list :lang=zh # 查看所有的中文字体
```
我通过下面这个命令来查看字体是否安装成功
```
fc-list | grep "替换成自己安装的字体名"
```

### 参考
1. [ubuntu查看支持的字体库](https://blog.csdn.net/weixin_35804181/article/details/71224294)
2. [ubuntu安装新字体](https://blog.csdn.net/bitcarmanlee/article/details/79729634)