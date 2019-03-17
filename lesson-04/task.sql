CREATE TABLE resource (
  id   SERIAL PRIMARY KEY,
  link TEXT NOT NULL
);

CREATE TABLE tag (
  id    SERIAL PRIMARY KEY,
  title TEXT
);

CREATE TABLE resource_tag (
  resource_id INTEGER NOT NULL,
  tag_id      INTEGER NOT NULL,
  CONSTRAINT resource_fk FOREIGN KEY (resource_id) REFERENCES resource (id),
  CONSTRAINT tag_fk FOREIGN KEY (tag_id) REFERENCES tag (id)
);

-- fill tables with Java


-- 0.1.1 - 10.8s
EXPLAIN ANALYZE
SELECT DISTINCT resource_id FROM resource_tag WHERE tag_id IN (1, 2, 3, 4);

-- 0.1.2 - 8.4s
EXPLAIN ANALYZE
SELECT DISTINCT resource_id FROM resource_tag WHERE tag_id = 1 OR tag_id = 2 OR tag_id = 3 OR tag_id = 4;

-- 0.0.1 - 8.6s
EXPLAIN ANALYZE
SELECT resource_id FROM resource_tag WHERE tag_id IN (1, 2, 3, 4);

-- 0.0.2 - 7.8s
EXPLAIN ANALYZE
SELECT resource_id FROM resource_tag WHERE tag_id = 1 OR tag_id = 2 OR tag_id = 3 OR tag_id = 4;


-- 1.1.1 - 10.2s
EXPLAIN ANALYZE
WITH selected AS (SELECT DISTINCT resource_id FROM resource_tag WHERE tag_id IN (1, 2, 3, 4))
SELECT r.*
FROM resource r
       INNER JOIN selected ON r.id = selected.resource_id;

-- 1.1.2 - 9.5s
EXPLAIN ANALYZE
WITH selected AS (SELECT DISTINCT resource_id FROM resource_tag WHERE tag_id = 1 OR tag_id = 2 OR tag_id = 3 OR tag_id = 4)
SELECT r.*
FROM resource r
       INNER JOIN selected ON r.id = selected.resource_id;

-- 1.0.1 - 9.7s
EXPLAIN ANALYZE
WITH selected AS (SELECT resource_id FROM resource_tag WHERE tag_id IN (1, 2, 3, 4))
SELECT r.*
FROM resource r
       INNER JOIN selected ON r.id = selected.resource_id;

-- 1.0.2 - 9.2s
EXPLAIN ANALYZE
WITH selected AS (SELECT resource_id FROM resource_tag WHERE tag_id = 1 OR tag_id = 2 OR tag_id = 3 OR tag_id = 4)
SELECT r.*
FROM resource r
       INNER JOIN selected ON r.id = selected.resource_id;

-- 2.1.1 - 0.09s
EXPLAIN ANALYZE
WITH selected AS (SELECT DISTINCT resource_id FROM resource_tag WHERE tag_id IN (1, 2, 3, 4) LIMIT 1000)
SELECT r.*
FROM resource r
       INNER JOIN selected ON r.id = selected.resource_id;

