#!/bin/bash
if [ ! -n "$1" ] ;then
    echo "请输入此次提交git的注释"
else
    git config --global user.email "398757724@qq.com"
    git config  --global user.name "zhangke"
    hexo clean
    git add --all
    git commit -m $1
    git push origin master:master
fi