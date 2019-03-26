---
title: mysql explain 详解
abbrlink: dd6beb0a
categories:
  - 数据库
  - mysql
date: 2019-03-26 19:57:28
tags: 
  - mysql
  - explain
copyright:
---
今天在看《高性能mysql》这本书的时候，经常看到explain这个命令。所以希望总结一下这个命令的一些知识点。此外，我们为了能够在数据库运行过程中去优化，就会开启慢查询日志，而慢查询日志记录一些执行时间比较久的SQL语句，但是找出这些SQL语句并不意味着完事了。我们需要分析为什么这条sql执行的慢，也就是找出具体的原因。这时我们常常用到explain这个命令来查看一个这些SQL语句的执行计划，查看该SQL语句有没有使用上了索引，有没有做全表扫描，这都可以通过explain命令来查看。所以我们深入了解MySQL的基于开销的优化器，还可以获得很多可能被优化器考虑到的访问策略的细节，以及当运行SQL语句时哪种策略预计会被优化器采用。（QEP：sql生成一个执行计划query Execution plan）
首先我们看看这个命令输出的具体格式，然后分别的解释其中每列代表的意思：

如果执行这条sql语句`explain  select * from film`,输出的内容如下：

| id  | select_type | table | type | possible_keys | key  | key_len | ref  | rows | filtered | Extras |
|-----|-------------|-------|------|---------------|------|---------|------|------|----------|--------|
| 1   | SIMPLE      | film  | ALL  | NULL          | NULL | NULL    | NULL | 1000 | 100      | NULL   |

以上就是explain命令打印出来的信息，下面分别解释上面每一列的内容
1. **id**

   是SQL执行的顺序的标识,SQL从大到小的执行
   1. id相同时，执行顺序由上至下
   2. 如果是子查询，id的序号会递增，id值越大优先级越高，越先被执行
   3. id如果相同，可以认为是一组，从上往下顺序执行；在所有组中，id值越大，优先级越高，越先执行

2. **select_type**

    表示了查询的类型, 它的常用取值有:

    - **SIMPLE**：表示此查询不包含 UNION 查询或子查询,也就是简单的select语句。
    - **PRIMARY** 表示此查询是最外层的查询，也就是查询中包含任何复杂的子部分，最外层的select被标记为此类型。
    - **UNION**：表示此查询是 UNION 的第二或随后的查询
    - **DEPENDENT UNION** ： UNION 中的第二个或后面的查询语句, 取决于外面的查询
    - **UNION RESULT** UNION 的结果
    - **SUBQUERY** 子查询中的第一个 SELECT
    - **DEPENDENT SUBQUERY**: 子查询中的第一个 SELECT, 取决于外面的查询. 即子查询依赖于外层查询的结果.
    - **DERIVED** ：派生表的SELECT, FROM子句的子查询。
    - **UNCACHEABLE SUBQUERY**：一个子查询的结果不能被缓存，必须重新评估外链接的第一行。

3. **table**

    显示这一行的数据是关于哪张表，有时不是真实的表名字，看到的是derivedX(x是个数字，表示第几步执行结果)

4. **type**

    表示MySQL在表中找到所需行的方式，又称"访问类型"。

    常用的类型有：**ALL, index,  range, ref, eq_ref, const, system, NULL（从左到右，性能从差到好）**

    * **ALL**：Full Table Scan， MySQL将遍历全表以找到匹配的行

    * **index**: Full Index Scan，index与ALL区别为index类型只遍历索引树

    * **range**:只检索给定范围的行,通过索引字段范围获取表中部分数据记录. 这个类型通常出现在 =, <>, >, >=, <, <=, IS NULL, <=>, BETWEEN, IN() 操作中。当 `type` 是 `range` 时, 那么 EXPLAIN 输出的 `ref` 字段为 NULL, 并且 `key_len` 字段是此次查询中使用到的索引的最长的那个.

    * **ref**: 表示上述表的连接匹配条件，即哪些列或常量被用于查找索引列上的值

    * **eq_ref**: 类似ref，区别就在使用的索引是唯一索引，对于每个索引键值，表中只有一条记录匹配，简单来说，就是多表连接中使用primary key或者 unique key作为关联条件

    * **const、system**: 当MySQL对查询某部分进行优化，并转换为一个常量时，使用这些类型访问。如将主键置于where列表中，MySQL就能将该查询转换为一个常量。针对主键或唯一索引的等值查询扫描, 最多只返回一行数据. const 查询速度非常快, 因为它仅仅读取一次即可。System是表中只有一条数据. 这个类型是特殊的 `const` 类型.

    * **NULL**: MySQL在优化过程中分解语句，执行时甚至不用访问表或索引，例如从一个索引列里选取最小值可以通过单独索引查找完成。

    下面看一下一些案例：

    **示例1：const，使用主键索引来查询**

    ```sql
    mysql> explain select * from user_info where id = 2
    *************************** 1. row ***************************
               id: 1
      select_type: SIMPLE
            table: user_info
       partitions: NULL
             type: const
    possible_keys: PRIMARY
              key: PRIMARY
          key_len: 8
              ref: const
             rows: 1
         filtered: 100.00
            Extra: NULL
    1 row in set, 1 warning (0.00 sec)
    ```

    **示例2：eq_ref,此类型通常出现在多表的join查询，表示对于前表的每一个结果，都只能匹配到后表的一行结果，并且查询的比较操作通常=，查询效率较高，类如**

    ```java
    mysql> EXPLAIN SELECT * FROM user_info, order_info WHERE user_info.id = order_info.user_id
    *************************** 1. row ***************************
               id: 1
      select_type: SIMPLE
            table: order_info
       partitions: NULL
             type: index
    possible_keys: user_product_detail_index
              key: user_product_detail_index
          key_len: 314
              ref: NULL
             rows: 9
         filtered: 100.00
            Extra: Using where; Using index
    *************************** 2. row ***************************
               id: 1
      select_type: SIMPLE
            table: user_info
       partitions: NULL
             type: eq_ref
    possible_keys: PRIMARY
              key: PRIMARY
          key_len: 8
              ref: test.order_info.user_id
             rows: 1
         filtered: 100.00
            Extra: NULL
    2 rows in set, 1 warning (0.00 sec)
    ```

    **示例3：ref，此类型通常出现在多表的join查询，针对于非唯一或者非主键索引，或者使用了最左前缀规则索引的查询**

    ```sql
    mysql> EXPLAIN SELECT * FROM user_info, order_info WHERE user_info.id = order_info.user_id AND order_info.user_id = 5
    *************************** 1. row ***************************
               id: 1
      select_type: SIMPLE
            table: user_info
       partitions: NULL
             type: const
    possible_keys: PRIMARY
              key: PRIMARY
          key_len: 8
              ref: const
             rows: 1
         filtered: 100.00
            Extra: NULL
    *************************** 2. row ***************************
               id: 1
      select_type: SIMPLE
            table: order_info
       partitions: NULL
             type: ref
    possible_keys: user_product_detail_index
              key: user_product_detail_index
          key_len: 9
              ref: const
             rows: 1
         filtered: 100.00
            Extra: Using index
    2 rows in set, 1 warning (0.01 sec)
    ```

5. **possible_keys**

    表示mysql在查询时，能够使用到的索引。 即使有些索引在 `possible_keys` 中出现, 但是并不表示此索引会真正地被 MySQL 使用到. MySQL 在查询时具体使用了哪些索引, 由 `key` 字段决定。

    如果该列是NULL，则没有相关的索引。在这种情况下，可以通过检查WHERE子句看是否它引用某些列或适合索引的列来提高你的查询性能。如果是这样，创造一个适当的索引并且再次用EXPLAIN检查查询

6. **key**

    是查询实际使用的键。如果没有选择索引，键是NULL。要想强制MySQL使用或忽视possible_keys列中的索引，在查询中使用FORCE INDEX、USE INDEX或者IGNORE INDEX。

7. **key_len**

    **表示索引中使用的字节数，可通过该列计算查询中使用的索引的长度（key_len显示的值为索引字段的最大可能长度，并非实际使用长度，即key_len是根据表定义计算而得，不是通过表内检索出的）**不损失精确性的情况下，长度越短越好 。

8. **ref**

    表示上述连接表的匹配条件，即哪些列或者常量被用于查找索引列上的值。

9. **rows**

    表示根据统计信息及索引选用情况，估算的找到所需的记录所需要读取的行数。

10. Extra

   **该列包含MySQL解决查询的详细信息,有以下几种情况：**

   下面中using filesort和using temporary，这两项非常消耗性能，需要注意，尽量优化掉。

   * **Using index**：覆盖索引查询，表示查询在索引树中就可以查找所需数据，不用扫描数据文件。
   * **Using where**:列数据是从仅仅使用了索引中的信息而没有读取实际的行动的表返回的，这发生在对表的全部的请求列都是同一个索引的部分的时候，表示mysql服务器将在存储引擎检索行后再进行过滤。表示存储引擎返回的记录并不是所有的都满足查询条件，需要在server层进行过滤。查询条件中分为限制条件和检查条件，5.6之前，存储引擎只能根据限制条件扫描数据并返回，然后server层根据检查条件进行过滤再返回真正符合查询的数据。5.6.x之后支持ICP特性，可以把检查条件也下推到存储引擎层，不符合检查条件和限制条件的数据，直接不读取，这样就大大减少了存储引擎扫描的记录数量。extra列显示using index condition。
   * **Using join buffer**：改值强调了在获取连接条件时没有使用索引，并且需要连接缓冲区来存储中间结果。如果出现了这个值，那应该注意，根据查询的具体情况可能需要添加索引来改进能。
   * **Impossible where**：这个值强调了where语句会导致没有符合条件的行。
   * **Select tables optimized away**：这个值意味着仅通过使用索引，优化器可能仅从聚合函数结果中返回一行
   * **Using temporary**：表示MySQL需要使用临时表来存储结果集，常见于排序和分组查询
   * **Using filesort**：MySQL中无法利用索引完成的排序操作称为“文件排序”,也就是mysql需要通过额外的排序操作，最好优化掉，因为这个操作一方面会使CPU资源消耗过大，另一方面可以内存不足，会使得排序的操作存储到磁盘文件上，增加了磁盘IO次数。

11. **filtered**

    这个字段表示存储阴影返回的数据在server层过滤后，剩下多少满足查询的记录数量的比例，是百分比，不是具体的记录数。

      




## 参考
1. [MySQL Explain详解](http://www.cnblogs.com/xuanzhi201111/p/4175635.html)
2. [MySQL 性能优化神器 Explain 使用分析](https://segmentfault.com/a/1190000008131735)
3. [Mysql优化之explain详解，基于5.7来解释](<https://www.jianshu.com/p/73f2c8448722>)