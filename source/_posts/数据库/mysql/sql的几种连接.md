---
title: sql的几种连接
abbrlink: 527f2873
categories:
  - 数据库
  - mysql
date: 2019-03-28 17:38:33
tags:
copyright:
---
在Mysql中连接主要有内连接和外连接，本篇文章主要讲解这俩种连接。
表的定义和数据如下
``` sql
create table student(
  id int auto_increment primary key,
  stuname varchar(128) not null
);
insert into student value (1,"张三");
insert into student value (2,"李四");
insert into student value (3,"王wu");
insert into student value (4,"任六");
insert into student value (5,"赵七");


create table course(
  id int auto_increment primary key ,
  course_name varchar(128),
   stuid int
);
insert  into course value( 1,"python编程",1);
insert  into course value (2,"sql编程",2);
insert  into course value (3,"java编程",3);
insert  into course value (4,"php编程",4);
insert  into course value  (5,"test编程",10);
```
<!-- more  -->
## 内连接
内连接就是讲俩个表中都存在的数据显示来，下面俩个sql语句的作用是一样的：
```sql
select * from course inner join student on course.stuid=student.id;
select * from course,student where course.stuid=student.id;
```
![Xnip2019-03-28_20-24-55](/images/Xnip2019-03-28_20-24-55.jpg)

## 外连接
### 左连接
是以左表为基准，将a.stuid = b.stuid的数据进行连接，然后将左表没有的对应项显示，右表的列为NULL
```sql
select *from course as a left join student as b on a.stuid=b.id;
```
![Xnip2019-03-28_20-27-01](/images/Xnip2019-03-28_20-27-01.jpg)
### 右连接
是以右表为基准，将a.stuid = b.stuid的数据进行连接，然以将右表没有的对应项显示，左表的列为NULL
```sql
select *from course as a right join student as b on a.stuid=b.id;
```
![Xnip2019-03-28_20-28-30](/images/Xnip2019-03-28_20-28-30.jpg)

### 全连接
完整外部联接返回左表和右表中的所有行。当某行在另一个表中没有匹配行时，则另一个表的选择列表列包含空值。如果表之间有匹配行，则整个结果集行包含基表的数据值。
相当于一个笛卡尔乘积。在mysql中是不支持的。

## 补充
### 自然连接
自然连接(Natural join)是一种特殊的等值连接，要求两个关系表中进行比较的属性组必须是名称相同的属性组，并且在结果中把重复的属性列去掉（即：留下名称相同的属性组中的其中一组）。