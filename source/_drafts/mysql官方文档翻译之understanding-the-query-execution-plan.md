---
title: mysql官方文档翻译之understanding the query execution plan
abbrlink: 3adcd2d4
categories:
  - 数据库
  - mysql
date: 2019-05-31 11:24:59
tags:
  - explain
  - mysql官方文档
---
原文
根据表、列、索引的详细信息以及WHERE子句中的条件，MySQL优化器考虑了许多有效执行SQL查询中涉及的查找的技术。可以在不读取所有行的情况下对大型表执行查询；可以在不比较每一行组合的情况下执行涉及多个表的联接。优化器选择执行最有效查询的一组操作称为“查询执行计划”，也称为解释计划。您的目标是认识到解释计划的各个方面，这些方面表明查询得到了很好的优化，并学习SQL语法和索引技术，以便在看到一些效率低下的操作时改进计划。
