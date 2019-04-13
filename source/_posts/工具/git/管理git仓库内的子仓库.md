---
title: 管理git仓库内的子仓库
abbrlink: 5d8f9bd8
categories:
  - 工具
  - git
date: 2019-04-13 20:12:23
tags:
  - git
  - 子模块
---
我在使用hexo构建自己的博客时遇到过这样的一种情况。使用`hexo init`命令创建一个静态网页目录，然后使用git来管理这个目录。如果这时需要替换themes，一般都是克隆主题对应的的仓库到themes目录下面，这时就会出现一个仓库里面包含另外一个子仓库，在git里面，称这为子模块。但是我们改了主题的配置文件，去提交，会返现主题对应的目录是空的。

首先有一种最简单的方法，就是讲子模块下面的`.git`目录给删除，那么这个仓库就是一个普通的目录，但是这个对以后升级不方便。

下面我们通过实例来讲解如何优雅的解决这个问题。

我创建的目录结构如下

![Xnip2019-04-14_00-30-14](/images/Xnip2019-04-14_00-30-14.jpg)
<!-- more -->
添加完这个模块后会报下面错误：
``` bash
$ git add .
warning: adding embedded git repository: themes/theme-next
hint: You've added another git repository inside your current repository.
hint: Clones of the outer repository will not contain the contents of
hint: the embedded repository and will not know how to obtain it.
hint: If you meant to add a submodule, use:
hint: 
hint: 	git submodule add <url> themes/theme-next
hint: 
hint: If you added this path by mistake, you can remove it from the
hint: index with:
hint: 
hint: 	git rm --cached themes/theme-next
hint: 
hint: See "git help submodule" for more information.

$ git commit -m "add theme-next"
[master 0aa46bf] add theme-next
 2 files changed, 1 insertion(+), 3 deletions(-)
 delete mode 100644 .gitmodules
 create mode 160000 themes/theme-next

$ git push 
Counting objects: 6, done.
Delta compression using up to 4 threads.
Compressing objects: 100% (6/6), done.
Writing objects: 100% (6/6), 567 bytes | 567.00 KiB/s, done.
Total 6 (delta 4), reused 0 (delta 0)
remote: Resolving deltas: 100% (4/4), completed with 3 local objects.
......
   46c54aa..0aa46bf  master -> master
```
从第一步`git add . `的warning提示可以看出git在后续克隆将不会包含这个themes/next的内容，当我push完之后，在GitHub上看到的将是一个灰色的图标，代表这是一个子模块，但是不知道这个子模块的仓库所在的url，因此在GitHub上无法打开这个文件夹。如果你看过git 子模块的介绍，其实这里可以直接使用`git submoudle add`来解决。但是我们没有权限提交对子模块的修改。希望的解决方案是将这些修改提交到当前的主模块上。

解决上面问题，比较简单的解决方案是，直接删除子模块中仓库对文件的缓存，然后将这些文件合并到主模块上，具体做法如下：

1. 删除已经缓存的文件
   ``` bash
    $ git rm --cached themes/theme-next
    rm 'themes/theme-next'
   ```
2. 查看当前状态
   ```
   $ git status 
    On branch master
    Your branch is up to date with 'origin/master'.

    Changes to be committed:
      (use "git reset HEAD <file>..." to unstage)

      deleted:    themes/theme-next

    Untracked files:
      (use "git add <file>..." to include in what will be committed)

      themes/theme-next
   ```
3. 重新缓存这个文件夹
   ```
   $ git add themes/theme-next
   ```
    注意：这里一定要加上 /，表示将这个文件夹加入，而不是将这个文件夹当做一个子模块。
    两者区别：
    git add themes/theme-next: create mode 100644
    git add themes/theme-next/: create mode 160000
    其中160000是git的一个特殊模式，具体的可以看后后面的参考
4. 在此commit和push，你就会发现github上有这个文件，而且不在是跳转到这个仓库的github上。如果你想更新这个子模块，还可以使用子模块的仓库来更新，并且更新的文件也会被主模块察觉到并保存。

## 参考
1. [Git 工具 - 子模块](https://git-scm.com/book/zh/v2/Git-%E5%B7%A5%E5%85%B7-%E5%AD%90%E6%A8%A1%E5%9D%97)
2. [管理 Git 仓库内的子仓库](https://upupming.site/2018/05/31/git-submodules/#%E4%BB%93%E5%BA%93%E5%86%85%E5%85%8B%E9%9A%86%E5%85%B6%E4%BB%96%E4%BB%93%E5%BA%93%E9%81%87%E5%88%B0%E7%9A%84%E9%97%AE%E9%A2%98)
3. 