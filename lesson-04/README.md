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
0. Убедиться, что на диске достаточно места. При текущих настройках необходимо до 3512 MB
1. Создать базу данных
2. В файле `Main.java` в процедуре `main` заменить переменные `databaseName`, `username` и `password` на необходимые
3. Запустить
    - mvn compile
    - mvn exec:java

Таблица resource_tag заполнялась 1ч 43 мин. (Generic SSD)

## Анализ
1. Придумать запрос
2. Выполнить `EXPLAIN ANALYZE <запрос>`
3. Предложить улучшения структуры данных или запроса для ускорения выборки.

`SELECT COUNT(1) FROM resource_tag;` -- сколько записей в таблице tag?
`SELECT pg_size_pretty(pg_database_size('java'));` -- сколько памяти нужно для хранения базы данных?

## Результаты
В таблице resource_tag 99 миллионов записей (99 497 980).
Мой запрос выполняется очень долго.
Время также сильно разнится

### Subquery
Перед контрольными запросами я сделал несколько подобных запросов с другими параметрами.
```
java=# EXPLAIN ANALYZE SELECT DISTINCT resource_id FROM resource_tag WHERE tag_id IN (11, 16, 18, 20);
 HashAggregate  (cost=1164848.71..1165643.64 rows=79493 width=4) (actual time=8319.339..8458.052 rows=665221 loops=1)
   Group Key: resource_id
   ->  Gather  (cost=1000.00..1162367.52 rows=992475 width=4) (actual time=1.622..7771.679 rows=994854 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Parallel Seq Scan on resource_tag  (cost=0.00..1062120.02 rows=413531 width=4) (actual time=0.347..7937.630 rows=331618 loops=3)
               Filter: (tag_id = ANY ('{11,16,18,20}'::integer[]))
               Rows Removed by Filter: 32834375
 Planning Time: 0.122 ms
 Execution Time: 8490.495 ms

java=# EXPLAIN ANALYZE SELECT DISTINCT resource_id FROM resource_tag WHERE tag_id IN (30, 50);
 HashAggregate  (cost=1010340.48..1011133.89 rows=79341 width=4) (actual time=7297.768..7390.765 rows=430540 loops=1)
   Group Key: resource_id
   ->  Gather  (cost=1000.00..1009099.89 rows=496237 width=4) (actual time=1.575..6979.329 rows=497251 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Parallel Seq Scan on resource_tag  (cost=0.00..958476.19 rows=206765 width=4) (actual time=0.369..7073.741 rows=165750 loops=3)
               Filter: (tag_id = ANY ('{30,50}'::integer[]))
               Rows Removed by Filter: 33000243
 Planning Time: 0.118 ms
 Execution Time: 7414.197 ms
```
Как мы видим, уменьшение количества параметров приводит к небольшому ускорению выполнения.

### Full query
```
java=# EXPLAIN ANALYZE WITH selected AS (SELECT DISTINCT resource_id FROM resource_tag WHERE tag_id IN (1, 2, 3, 4))
java-# SELECT r.*
java-# FROM resource r
java-#        INNER JOIN selected ON r.id = selected.resource_id;
 Hash Join  (cost=1209035.35..1216338.87 rows=79493 width=13) (actual time=8438.422..9440.001 rows=665149 loops=1)
   Hash Cond: (selected.resource_id = r.id)
   CTE selected
     ->  HashAggregate  (cost=1175451.42..1176246.35 rows=79493 width=4) (actual time=8115.405..8262.534 rows=665149 loops=1)
           Group Key: resource_tag.resource_id
           ->  Gather  (cost=1000.00..1172711.63 rows=1095916 width=4) (actual time=0.949..7590.381 rows=996030 loops=1)
                 Workers Planned: 2
                 Workers Launched: 2
                 ->  Parallel Seq Scan on resource_tag  (cost=0.00..1062120.02 rows=456632 width=4) (actual time=0.233..7757.638 rows=332010 loops=3)
                       Filter: (tag_id = ANY ('{1,2,3,4}'::integer[]))
                       Rows Removed by Filter: 32833983
   ->  CTE Scan on selected  (cost=0.00..1589.86 rows=79493 width=4) (actual time=8115.410..8406.545 rows=665149 loops=1)
   ->  Hash  (cost=15406.00..15406.00 rows=1000000 width=13) (actual time=318.747..318.747 rows=1000000 loops=1)
         Buckets: 131072  Batches: 16  Memory Usage: 3832kB
         ->  Seq Scan on resource r  (cost=0.00..15406.00 rows=1000000 width=13) (actual time=0.550..127.882 rows=1000000 loops=1)
 Planning Time: 28.373 ms
 Execution Time: 9484.142 ms
```

Подзапрос занимает значительную часть времени, необходимо его ускорить.
Я вижу несколько оптимизаций:
    - для каждого тега создать MATERIALIZED VIEW выборку из resource_tag и таком запросе делать объединение таких view. (слишком сложно)
    - добавить индекс для resource_tag.tag_id
    - ограничить максимальное количество тегов для одного ресурса (например числом 5 или 10)
    - использовать графовую СУБД вместо реляционной
Очевидно, что необходима оптимизация первого подзапроса, т.к. большая часть времени уходит на его обработку.

## Создаём индекс
`CREATE INDEX CONCURRENTLY ON resource_tag(tag_id);`
База данных выросла до 5643 MB

list indexes
`SELECT * FROM pg_indexes WHERE tablename NOT LIKE 'pg%';`

```
java=# EXPLAIN ANALYZE
java-# WITH selected AS (SELECT DISTINCT resource_id FROM resource_tag WHERE tag_id IN (1, 2, 3, 4))
java-# SELECT r.*
java-# FROM resource r
java-#        INNER JOIN selected ON r.id = selected.resource_id;
 Hash Join  (cost=1183723.28..1191026.81 rows=79493 width=13) (actual time=9017.187..9918.579 rows=665149 loops=1)
   Hash Cond: (selected.resource_id = r.id)
   CTE selected
     ->  HashAggregate  (cost=1150139.35..1150934.28 rows=79493 width=4) (actual time=8734.051..8879.006 rows=665149 loops=1)
           Group Key: resource_tag.resource_id
           ->  Gather  (cost=21463.62..1147399.56 rows=1095915 width=4) (actual time=168.478..8192.122 rows=996030 loops=1)
                 Workers Planned: 2
                 Workers Launched: 2
                 ->  Parallel Bitmap Heap Scan on resource_tag  (cost=20463.62..1036808.06 rows=456631 width=4) (actual time=127.521..8354.188 rows=332010 loops=3)
                       Recheck Cond: (tag_id = ANY ('{1,2,3,4}'::integer[]))
                       Rows Removed by Index Recheck: 27030058
                       Heap Blocks: exact=14101 lossy=116126
                       ->  Bitmap Index Scan on resource_tag_tag_id_idx  (cost=0.00..20189.64 rows=1095915 width=0) (actual time=157.111..157.111 rows=996030 loops=1)
                             Index Cond: (tag_id = ANY ('{1,2,3,4}'::integer[]))
   ->  CTE Scan on selected  (cost=0.00..1589.86 rows=79493 width=4) (actual time=8734.054..9025.773 rows=665149 loops=1)
   ->  Hash  (cost=15406.00..15406.00 rows=1000000 width=13) (actual time=279.010..279.010 rows=1000000 loops=1)
         Buckets: 131072  Batches: 16  Memory Usage: 3832kB
         ->  Seq Scan on resource r  (cost=0.00..15406.00 rows=1000000 width=13) (actual time=0.069..110.617 rows=1000000 loops=1)
 Planning Time: 0.278 ms
 Execution Time: 9962.033 ms
```
Время выполнения подзапроса увеличилось ненамного.

```
java=# EXPLAIN ANALYZE
java-# WITH selected AS (SELECT DISTINCT resource_id FROM resource_tag WHERE tag_id = 1 OR tag_id = 2 OR tag_id = 3 OR tag_id = 4)
java-# SELECT r.*
java-# FROM resource r
java-#        INNER JOIN selected ON r.id = selected.resource_id;
 Hash Join  (cost=1376170.88..1383474.41 rows=79493 width=13) (actual time=8523.880..9416.492 rows=665149 loops=1)
   Hash Cond: (selected.resource_id = r.id)
   CTE selected
     ->  HashAggregate  (cost=1342586.95..1343381.88 rows=79493 width=4) (actual time=8236.998..8381.641 rows=665149 loops=1)
           Group Key: resource_tag.resource_id
           ->  Gather  (cost=22341.06..1339858.35 rows=1091437 width=4) (actual time=163.349..7697.737 rows=996030 loops=1)
                 Workers Planned: 2
                 Workers Launched: 2
                 ->  Parallel Bitmap Heap Scan on resource_tag  (cost=21341.06..1229714.65 rows=454765 width=4) (actual time=125.271..7862.174 rows=332010 loops=3)
                       Recheck Cond: ((tag_id = 1) OR (tag_id = 2) OR (tag_id = 3) OR (tag_id = 4))
                       Rows Removed by Index Recheck: 27030058
                       Heap Blocks: exact=13813 lossy=113667
                       ->  BitmapOr  (cost=21341.06..21341.06 rows=1095915 width=0) (actual time=151.955..151.955 rows=0 loops=1)
                             ->  Bitmap Index Scan on resource_tag_tag_id_idx  (cost=0.00..4585.45 rows=248118 width=0) (actual time=81.367..81.367 rows=248801 loops=1)
                                   Index Cond: (tag_id = 1)
                             ->  Bitmap Index Scan on resource_tag_tag_id_idx  (cost=0.00..4585.45 rows=248118 width=0) (actual time=29.128..29.128 rows=248368 loops=1)
                                   Index Cond: (tag_id = 2)
                             ->  Bitmap Index Scan on resource_tag_tag_id_idx  (cost=0.00..6493.27 rows=351560 width=0) (actual time=22.836..22.836 rows=249749 loops=1)
                                   Index Cond: (tag_id = 3)
                             ->  Bitmap Index Scan on resource_tag_tag_id_idx  (cost=0.00..4585.45 rows=248118 width=0) (actual time=18.619..18.619 rows=249112 loops=1)
                                   Index Cond: (tag_id = 4)
   ->  CTE Scan on selected  (cost=0.00..1589.86 rows=79493 width=4) (actual time=8237.001..8527.867 rows=665149 loops=1)
   ->  Hash  (cost=15406.00..15406.00 rows=1000000 width=13) (actual time=282.595..282.595 rows=1000000 loops=1)
         Buckets: 131072  Batches: 16  Memory Usage: 3832kB
         ->  Seq Scan on resource r  (cost=0.00..15406.00 rows=1000000 width=13) (actual time=0.065..110.351 rows=1000000 loops=1)
 Planning Time: 0.162 ms
 Execution Time: 9459.173 ms
```
Также замена конструкции `tag_id IN (...)` на `tag_id = 1 OR tag_id = 2 OR ...` немного ускоряет запрос.


```
java=# EXPLAIN ANALYZE
java-# WITH selected AS (SELECT resource_id FROM resource_tag WHERE tag_id = 1 OR tag_id = 2 OR tag_id = 3 OR tag_id = 4)
java-# SELECT r.*
java-# FROM resource r
java-#        INNER JOIN selected ON r.id = selected.resource_id;
 Hash Join  (cost=1372647.35..1410752.13 rows=1091437 width=13) (actual time=447.731..8929.914 rows=996030 loops=1)
   Hash Cond: (selected.resource_id = r.id)
   CTE selected
     ->  Gather  (cost=22341.06..1339858.35 rows=1091437 width=4) (actual time=168.695..7349.046 rows=996030 loops=1)
           Workers Planned: 2
           Workers Launched: 2
           ->  Parallel Bitmap Heap Scan on resource_tag  (cost=21341.06..1229714.65 rows=454765 width=4) (actual time=128.294..7679.641 rows=332010 loops=3)
                 Recheck Cond: ((tag_id = 1) OR (tag_id = 2) OR (tag_id = 3) OR (tag_id = 4))
                 Rows Removed by Index Recheck: 27030058
                 Heap Blocks: exact=13602 lossy=110941
                 ->  BitmapOr  (cost=21341.06..21341.06 rows=1095915 width=0) (actual time=156.078..156.078 rows=0 loops=1)
                       ->  Bitmap Index Scan on resource_tag_tag_id_idx  (cost=0.00..4585.45 rows=248118 width=0) (actual time=83.372..83.372 rows=248801 loops=1)
                             Index Cond: (tag_id = 1)
                       ->  Bitmap Index Scan on resource_tag_tag_id_idx  (cost=0.00..4585.45 rows=248118 width=0) (actual time=29.612..29.612 rows=248368 loops=1)
                             Index Cond: (tag_id = 2)
                       ->  Bitmap Index Scan on resource_tag_tag_id_idx  (cost=0.00..6493.27 rows=351560 width=0) (actual time=23.342..23.342 rows=249749 loops=1)
                             Index Cond: (tag_id = 3)
                       ->  Bitmap Index Scan on resource_tag_tag_id_idx  (cost=0.00..4585.45 rows=248118 width=0) (actual time=19.747..19.747 rows=249112 loops=1)
                             Index Cond: (tag_id = 4)
   ->  CTE Scan on selected  (cost=0.00..21828.74 rows=1091437 width=4) (actual time=168.699..7755.264 rows=996030 loops=1)
   ->  Hash  (cost=15406.00..15406.00 rows=1000000 width=13) (actual time=276.023..276.024 rows=1000000 loops=1)
         Buckets: 131072  Batches: 16  Memory Usage: 3832kB
         ->  Seq Scan on resource r  (cost=0.00..15406.00 rows=1000000 width=13) (actual time=0.039..108.985 rows=1000000 loops=1)
 Planning Time: 0.286 ms
 Execution Time: 8977.375 ms
```
Исключение ключевого слова `DISTINCT` в сочетании с использованием `OR` немного ускоряет выполнение всего запроса.
Исключение ключевого слова `DISTINCT` не ускоряет выполнение значительно.

Ограничение числа ресурсов не сильно ускоряет запрос.
```
java=# EXPLAIN ANALYZE
java-# WITH selected AS (SELECT DISTINCT resource_id FROM resource_tag WHERE tag_id IN (1, 2, 3, 4) LIMIT 60)
java-# SELECT r.*
java-# FROM resource r
java-#        INNER JOIN selected ON r.id = selected.resource_id;
 Nested Loop  (cost=1150140.38..1150647.70 rows=60 width=13) (actual time=8395.698..8421.329 rows=60 loops=1)
   CTE selected
     ->  Limit  (cost=1150139.35..1150139.95 rows=60 width=4) (actual time=8395.469..8419.029 rows=60 loops=1)
           ->  HashAggregate  (cost=1150139.35..1150934.28 rows=79493 width=4) (actual time=8395.468..8395.499 rows=60 loops=1)
                 Group Key: resource_tag.resource_id
                 ->  Gather  (cost=21463.62..1147399.56 rows=1095915 width=4) (actual time=165.671..7883.357 rows=996030 loops=1)
                       Workers Planned: 2
                       Workers Launched: 2
                       ->  Parallel Bitmap Heap Scan on resource_tag  (cost=20463.62..1036808.06 rows=456631 width=4) (actual time=126.222..8024.160 rows=332010 loops=3)
                             Recheck Cond: (tag_id = ANY ('{1,2,3,4}'::integer[]))
                             Rows Removed by Index Recheck: 27030058
                             Heap Blocks: exact=13543 lossy=112684
                             ->  Bitmap Index Scan on resource_tag_tag_id_idx  (cost=0.00..20189.64 rows=1095915 width=0) (actual time=154.210..154.210 rows=996030 loops=1)                                   Index Cond: (tag_id = ANY ('{1,2,3,4}'::integer[]))
   ->  CTE Scan on selected  (cost=0.00..1.20 rows=60 width=4) (actual time=8395.472..8419.079 rows=60 loops=1)
   ->  Index Scan using resource_pkey on resource r  (cost=0.42..8.44 rows=1 width=13) (actual time=0.037..0.037 rows=1 loops=60)
         Index Cond: (id = selected.resource_id)
 Planning Time: 0.368 ms
 Execution Time: 8432.285 ms
```
Для тясячи - 51 милисекунда.

## Добавление второго индекса
`CREATE INDEX CONCURRENTLY ON resource_tag (resource_id);`
Размер базы данных вырос до 7775 MB.
Как ни странно, запрос стал выполнятся слегка медленнее.

ОДНАКО сочетание с ограничением числа ресурсов дало невероятную производительность. Время выполнения сократилось до 270 милисекунд.
Выбор 1000 ресурсов.
```
java=# EXPLAIN ANALYZE
java-# WITH selected AS (SELECT DISTINCT resource_id FROM resource_tag WHERE tag_id IN (1, 2, 3, 4) LIMIT 1000)
java-# SELECT r.*
java-# FROM resource r
java-#        INNER JOIN selected ON r.id = selected.resource_id;
 Nested Loop  (cost=35974.11..43484.18 rows=1000 width=13) (actual time=144.737..276.102 rows=1000 loops=1)
   CTE selected
     ->  Limit  (cost=1000.59..35973.68 rows=1000 width=4) (actual time=144.714..268.772 rows=1000 loops=1)
           ->  Unique  (cost=1000.59..2781116.48 rows=79493 width=4) (actual time=144.713..243.651 rows=1000 loops=1)
                 ->  Gather Merge  (cost=1000.59..2778376.69 rows=1095915 width=4) (actual time=144.712..267.987 rows=1503 loops=1)
                       Workers Planned: 2
                       Workers Launched: 2
                       ->  Parallel Index Scan using resource_tag_resource_id_idx on resource_tag  (cost=0.57..2650880.89 rows=456631 width=4) (actual time=0.076..89.067 rows=504 loops=3)
                             Filter: (tag_id = ANY ('{1,2,3,4}'::integer[]))
                             Rows Removed by Filter: 49460
   ->  CTE Scan on selected  (cost=0.00..20.00 rows=1000 width=4) (actual time=144.716..269.208 rows=1000 loops=1)
   ->  Index Scan using resource_pkey on resource r  (cost=0.42..7.49 rows=1 width=13) (actual time=0.006..0.006 rows=1 loops=1000)
         Index Cond: (id = selected.resource_id)
 Planning Time: 0.218 ms
 Execution Time: 276.270 ms
```

# Graph Database
Я использовал Neo4J.

Запрос из файла task.cypher выполняется за 812 милисекунд.

База данных была заполнена так:
400 тегов.
1 миллион ресурсов.
21 миллон отношений. (~ 11% от требования)

