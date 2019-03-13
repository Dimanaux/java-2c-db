# Дз

В базе хранятся ресурсы и теги (примерно
1000000 ресурсов, 400 тегов, в среднем у ресурса
100 тегов). Теги привязаны к
ресурсам через вспомогательную таблицу. Необходимо
написать запрос для выборки всех ресурсов, которые
соответствуют набору тегов (если набор тегов, 
соответствующих некоторому ресурсу, включает искомый
набор тегов, то он включается в выборку). Задача -
предложить некоторый оптимальный по времени
вариант для получения такой выборки.

Для оценки работы запроса можно использовать
`EXPLAIN ANALYZE` - команда служит
для анализа работы запроса (в
том числе показывает реальное время выполнения)

# Работа
## Подготовка данных
0. Убедиться, что на диске достаточно места. При текущих настройках необходимо до 3.5GB
1. Создать базу данных
2. В файле `Main.java` в процедуре `main` заменить переменные `databaseName`, `username` и `password` на необходимые
3. Запустить
    - mvn compile
    - mvn exec:java

## Анализ
1. Придумать запрос
2. Выполнить `EXPLAIN <запрос>`
3. Предложить улучшения структуры данных или запроса для ускорения выборки.

```
SELECT COUNT(1) FROM resource_tag; -- сколько записей в таблице tag?
SELECT pg_size_pretty(pg_database_size('java')); -- сколько памяти нужно для хранения базы данных?
```

## Результаты
Мой запрос выполняется очень долго.

### Subquery
```
=# EXPLAIN ANALYZE SELECT DISTINCT resource_id FROM resource_tag WHERE tag_id IN (1, 2, 3, 4);
                                                                  QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------------------
 HashAggregate  (cost=1164830.79..1165615.83 rows=78504 width=4) (actual time=40244.120..40451.282 rows=665182 loops=1)
   Group Key: resource_id
   ->  Gather  (cost=1000.00..1162352.28 rows=991406 width=4) (actual time=2.320..39246.706 rows=993756 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Parallel Seq Scan on resource_tag  (cost=0.00..1062211.68 rows=413086 width=4) (actual time=0.281..39458.059 rows=331252 loops=3)
               Filter: (tag_id = ANY ('{1,2,3,4}'::integer[]))
               Rows Removed by Filter: 32837595
 Planning Time: 0.403 ms
 Execution Time: 40507.978 ms
(10 rows)

=# EXPLAIN ANALYZE SELECT DISTINCT resource_id FROM resource_tag WHERE tag_id IN (1, 2);
                                                                  QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------------
 HashAggregate  (cost=1010368.45..1011152.09 rows=78364 width=4) (actual time=39862.734..39995.992 rows=430183 loops=1)
   Group Key: resource_id
   ->  Gather  (cost=1000.00..1009129.20 rows=495703 width=4) (actual time=11.508..39191.429 rows=496556 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Parallel Seq Scan on resource_tag  (cost=0.00..958558.90 rows=206543 width=4) (actual time=2.393..39296.007 rows=165519 loops=3)
               Filter: (tag_id = ANY ('{1,2}'::integer[]))
               Rows Removed by Filter: 33003328
 Planning Time: 0.634 ms
 Execution Time: 40036.719 ms
(10 rows)
```
Как мы видим, уменьшение количества параметров не приводит к ускорению выполнения.

### Full query
```
=# EXPLAIN ANALYZE
-# WITH selected AS (SELECT DISTINCT resource_id FROM resource_tag WHERE tag_id IN (1, 2, 3, 4))
-# SELECT *
-# FROM resource r
-#        INNER JOIN selected ON r.id = selected.resource_id;
                                                                      QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------------------------------
 Hash Join  (cost=1198404.83..1205677.98 rows=78504 width=17) (actual time=40779.384..41942.236 rows=665182 loops=1)
   Hash Cond: (selected.resource_id = r.id)
   CTE selected
     ->  HashAggregate  (cost=1164830.79..1165615.83 rows=78504 width=4) (actual time=40441.404..40607.633 rows=665182 loops=1)
           Group Key: resource_tag.resource_id
           ->  Gather  (cost=1000.00..1162352.28 rows=991406 width=4) (actual time=2.578..39459.479 rows=993756 loops=1)
                 Workers Planned: 2
                 Workers Launched: 2
                 ->  Parallel Seq Scan on resource_tag  (cost=0.00..1062211.68 rows=413086 width=4) (actual time=0.235..39676.787 rows=331252 loops=3)
                       Filter: (tag_id = ANY ('{1,2,3,4}'::integer[]))
                       Rows Removed by Filter: 32837595
   ->  CTE Scan on selected  (cost=0.00..1570.08 rows=78504 width=4) (actual time=40441.409..40790.094 rows=665182 loops=1)
   ->  Hash  (cost=15406.00..15406.00 rows=1000000 width=13) (actual time=333.003..333.004 rows=1000000 loops=1)
         Buckets: 131072  Batches: 16  Memory Usage: 3832kB
         ->  Seq Scan on resource r  (cost=0.00..15406.00 rows=1000000 width=13) (actual time=0.573..127.807 rows=1000000 loops=1)
 Planning Time: 6.225 ms
 Execution Time: 41992.261 ms
(17 rows)
```

Подзапрос занимает значительную часть времени, необходимо его ускорить.
Я вижу несколько оптимизаций:
    - для каждого тега создать MATERIALIZED VIEW выборку из resource_tag и таком запросе делать объединение таких view. (слишком сложно)
    - добавить индекс для resource_tag.tag_id
    - ограничить максимальное количество тегов для одного ресурса числом 5 или 10
    - использовать графовую СУБД вместо реляционной
Очевидно, что необходима оптимизация первого подзапроса, т.к. большая часть времени уходит на его обработку.

## Создаём индекс
`CREATE INDEX CONCURRENTLY ON resource_tag(tag_id);`
База данных выросла до 5.5GB.
```
=# EXPLAIN ANALYZE SELECT DISTINCT resource_id FROM resource_tag WHERE tag_id IN (1, 2, 3, 4);
                                                                           QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------------------------------
 HashAggregate  (cost=1137519.86..1138304.90 rows=78504 width=4) (actual time=8689.645..8850.513 rows=665182 loops=1)
   Group Key: resource_id
   ->  Gather  (cost=19513.65..1135041.35 rows=991404 width=4) (actual time=258.802..8147.353 rows=993756 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Parallel Bitmap Heap Scan on resource_tag  (cost=18513.65..1034900.95 rows=413085 width=4) (actual time=172.003..8263.111 rows=331252 loops=3)
               Recheck Cond: (tag_id = ANY ('{1,2,3,4}'::integer[]))
               Rows Removed by Index Recheck: 27031255
               Heap Blocks: exact=13296 lossy=113487
               ->  Bitmap Index Scan on resource_tag_tag_id_index  (cost=0.00..18265.80 rows=991404 width=0) (actual time=244.546..244.546 rows=993756 loops=1)
                     Index Cond: (tag_id = ANY ('{1,2,3,4}'::integer[]))
 Planning Time: 0.226 ms
 Execution Time: 8897.591 ms
(13 rows)
```
Время выполнения подзапроса уменьшилось до 9 секунд!

```
=# EXPLAIN ANALYZE WITH selected AS (SELECT DISTINCT resource_id FROM resource_tag WHERE tag_id IN (1, 2, 3, 4))
-# SELECT *
-# FROM resource r
-#        INNER JOIN selected ON r.id = selected.resource_id;
                                                                               QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Hash Join  (cost=1171093.90..1178367.05 rows=78504 width=17) (actual time=20117.681..21167.974 rows=665182 loops=1)
   Hash Cond: (selected.resource_id = r.id)
   CTE selected
     ->  HashAggregate  (cost=1137519.86..1138304.90 rows=78504 width=4) (actual time=19778.385..19937.288 rows=665182 loops=1)
           Group Key: resource_tag.resource_id
           ->  Gather  (cost=19513.65..1135041.35 rows=991404 width=4) (actual time=220.157..19087.411 rows=993756 loops=1)
                 Workers Planned: 2
                 Workers Launched: 2
                 ->  Parallel Bitmap Heap Scan on resource_tag  (cost=18513.65..1034900.95 rows=413085 width=4) (actual time=81.109..19176.032 rows=331252 loops=3)
                       Recheck Cond: (tag_id = ANY ('{1,2,3,4}'::integer[]))
                       Rows Removed by Index Recheck: 27031255
                       Heap Blocks: exact=13654 lossy=113613
                       ->  Bitmap Index Scan on resource_tag_tag_id_index  (cost=0.00..18265.80 rows=991404 width=0) (actual time=204.162..204.162 rows=993756 loops=1)
                             Index Cond: (tag_id = ANY ('{1,2,3,4}'::integer[]))
   ->  CTE Scan on selected  (cost=0.00..1570.08 rows=78504 width=4) (actual time=19778.389..20111.073 rows=665182 loops=1)
   ->  Hash  (cost=15406.00..15406.00 rows=1000000 width=13) (actual time=334.955..334.955 rows=1000000 loops=1)
         Buckets: 131072  Batches: 16  Memory Usage: 3832kB
         ->  Seq Scan on resource r  (cost=0.00..15406.00 rows=1000000 width=13) (actual time=5.978..138.983 rows=1000000 loops=1)
 Planning Time: 18.017 ms
 Execution Time: 21222.805 ms
(20 rows)
```
Также замена конструкции tag_id IN (...) на tag_id = 1 OR tag_id = 2 OR ... немного ускоряет запрос.


```
=# EXPLAIN ANALYZE WITH selected AS (SELECT resource_id FROM resource_tag WHERE tag_id = 1 OR tag_id = 2 OR tag_id = 3 OR tag_id = 4)
-# SELECT *
-# FROM resource r
-#        INNER JOIN selected ON r.id = selected.resource_id;
                                                                              QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Hash Join  (cost=1360283.17..1395231.03 rows=987706 width=17) (actual time=572.982..8822.431 rows=993756 loops=1)
   Hash Cond: (selected.resource_id = r.id)
   CTE selected
     ->  Gather  (cost=20305.51..1327494.17 rows=987706 width=4) (actual time=276.797..7221.274 rows=993756 loops=1)
           Workers Planned: 2
           Workers Launched: 2
           ->  Parallel Bitmap Heap Scan on resource_tag  (cost=19305.51..1227723.57 rows=411544 width=4) (actual time=173.857..7458.690 rows=331252 loops=3)
                 Recheck Cond: ((tag_id = 1) OR (tag_id = 2) OR (tag_id = 3) OR (tag_id = 4))
                 Rows Removed by Index Recheck: 27031255
                 Heap Blocks: exact=13318 lossy=109852
                 ->  BitmapOr  (cost=19305.51..19305.51 rows=991404 width=0) (actual time=260.910..260.910 rows=0 loops=1)
                       ->  Bitmap Index Scan on resource_tag_tag_id_index  (cost=0.00..4579.45 rows=247851 width=0) (actual time=177.402..177.402 rows=248655 loops=1)
                             Index Cond: (tag_id = 1)
                       ->  Bitmap Index Scan on resource_tag_tag_id_index  (cost=0.00..4579.45 rows=247851 width=0) (actual time=33.738..33.738 rows=247901 loops=1)
                             Index Cond: (tag_id = 2)
                       ->  Bitmap Index Scan on resource_tag_tag_id_index  (cost=0.00..4579.45 rows=247851 width=0) (actual time=27.502..27.502 rows=248792 loops=1)
                             Index Cond: (tag_id = 3)
                       ->  Bitmap Index Scan on resource_tag_tag_id_index  (cost=0.00..4579.45 rows=247851 width=0) (actual time=22.262..22.263 rows=248408 loops=1)
                             Index Cond: (tag_id = 4)
   ->  CTE Scan on selected  (cost=0.00..19754.12 rows=987706 width=4) (actual time=276.805..7603.981 rows=993756 loops=1)
   ->  Hash  (cost=15406.00..15406.00 rows=1000000 width=13) (actual time=293.877..293.877 rows=1000000 loops=1)
         Buckets: 131072  Batches: 16  Memory Usage: 3832kB
         ->  Seq Scan on resource r  (cost=0.00..15406.00 rows=1000000 width=13) (actual time=0.040..114.708 rows=1000000 loops=1)
 Planning Time: 1.229 ms
 Execution Time: 8877.230 ms
(25 rows)
```

Исключение ключевого слова DISTINCT значительно ускоряет выполнение всего запроса.

Самая мощная оптимизация спросить, а сколько ресурсов мы хотим получить зараз?
Например, если ограничить число ресурсов сотней, то получится 2 милисекунды.
```
=# EXPLAIN ANALYZE WITH selected AS (SELECT resource_id FROM resource_tag WHERE tag_id IN (1, 2, 3, 4) LIMIT 100)
-# SELECT *
-# FROM resource r
-#        INNER JOIN selected ON r.id = selected.resource_id;
                                                                            QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Nested Loop  (cost=185.65..1027.47 rows=100 width=17) (actual time=0.320..2.101 rows=100 loops=1)
   CTE selected
     ->  Limit  (cost=0.57..185.22 rows=100 width=4) (actual time=0.199..1.326 rows=100 loops=1)
           ->  Index Scan using resource_tag_tag_id_index on resource_tag  (cost=0.57..1830676.54 rows=991404 width=4) (actual time=0.189..1.296 rows=100 loops=1)
                 Index Cond: (tag_id = ANY ('{1,2,3,4}'::integer[]))
   ->  CTE Scan on selected  (cost=0.00..2.00 rows=100 width=4) (actual time=0.211..1.400 rows=100 loops=1)
   ->  Index Scan using resource_pkey on resource r  (cost=0.42..8.40 rows=1 width=13) (actual time=0.006..0.006 rows=1 loops=100)
         Index Cond: (id = selected.resource_id)
 Planning Time: 50.029 ms
 Execution Time: 2.640 ms
(10 rows)
```
Для тясячи - 51 милисекунда.

## Добавление второго индекса
`CREATE INDEX CONCURRENTLY ON resource_tag (resource_id);`
Размер базы данных вырос до 7775MB.
Как ни странно, запрос стал выполнятся слегка медленнее.
