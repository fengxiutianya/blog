#!/bin/bash
pwd
if [ ! -n "$1" ] ;then
    echo "请输入此次提交git的注释"
else
    git config  user.email "398757724@qq.com"
    git config  user.name "zhangke"
    hexo clean
    git add --all
    git commit -m $1
    git push orgin master:master
fi