#!/bin/bash
if [ ! -n "$1" ] ;then
    echo "请输入此次提交git的注释"
else
    git add --all
    git commit -m $1
    git push orgin master:master
fi