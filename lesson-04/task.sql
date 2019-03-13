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

WITH selected AS (SELECT DISTINCT resource_id FROM resource_tag WHERE tag_id IN (1, 2, 3, 4))
SELECT *
FROM resource r
       INNER JOIN selected ON r.id = selected.resource_id;

SELECT resource_id FROM resource_tag WHERE tag_id = 1 OR tag_id = 2 OR tag_id = 3 OR tag_id = 4;

WITH selected AS (SELECT resource_id FROM resource_tag WHERE tag_id IN (1, 2, 3, 4))
SELECT *
FROM resource r
       INNER JOIN selected ON r.id = selected.resource_id;

WITH selected AS (SELECT resource_id FROM resource_tag WHERE tag_id = 1 OR tag_id = 2 OR tag_id = 3 OR tag_id = 4)
SELECT r.*
FROM resource r
       INNER JOIN selected ON r.id = selected.resource_id;
