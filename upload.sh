#!/bin/bash
if [ ! -n "$1" ] ;then
    echo "请输入此次提交git的注释"
else
    git config  user.email "398757724@qq.com"
    git config  user.name "zhangke"
    hexo clean
    git commit -am $1
    git push origin master:master
fi