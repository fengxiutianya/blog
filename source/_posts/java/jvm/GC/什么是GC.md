---
title: 什么是GC
abbrlink: f1158e94
categories:
  - java
  - jvm
  - GC
date: 2019-04-19 15:03:49
tags:
  - GC
---
本篇文章主要讨论什么是GC，为什么要有GC？
## 什么是GC(Garbage Collection)
乍一看，垃圾收集应该处理名称所暗示的 ----找到并扔掉垃圾。实际上它恰恰相反。垃圾收集器追踪仍在使用的所有对象，并将其余对象标记为垃圾。考虑到这一点，我们开始深入研究Java虚拟机是如何实现内存的自动回收，在Java中这个过程叫做GC。
 
 这篇文章不会一开始就深入GC的细节，而是先介绍垃圾收集器的一般性质，然后介绍核心概念和方法。

免责声明：此内容侧重于Oracle Hotspot和OpenJDK。在其他JVM（例如jRockit或IBM J9）上，本文中涉及的某些方面可能表现不同。

## 手动内存管理
在我们开始介绍垃圾收集之前，让我们快速回顾一下您必须手动并明确地为数据分配和释放内存的日子。如果你忘了释放它，你将无法重复使用内存。内存被声明但没有使用。这种情况称为内存泄漏。

下面是一个C语言写的例子，手动管理内存
``` c
int send_request() {
    size_t n = read_size();
    // 申请内存
    int *elements = malloc(n * sizeof(int));

    if(read_elements(n, elements) < n) {
        // elements not freed!
        return -1;
    }

    // …
    // 释放内存
    free(elements)
    return 0;
}
```
我们可以看到，这是很容易忘记释放申请的内存。内存泄露是比较高常见的问题，相对于现在比现在。你只能通过修复代码来释放它们。因此，更好的方法是自动回收未使用的内存，完全消除人为错误的可能性。这种自动化称为垃圾收集（简称GC）。
### 智能指针



## 参考
1. [what-is-garbage-collection](https://plumbr.io/handbook/what-is-garbage-collection)