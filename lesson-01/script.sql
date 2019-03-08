DROP TABLE publisher;
DROP TABLE book;

CREATE TABLE publisher (
    id SERIAL unique,
    name VARCHAR(255),
    city VARCHAR(255)
);

CREATE TABLE book (
    id SERIAL,
    name VARCHAR(255),
    author VARCHAR(255),
    publisher_id INT REFERENCES publisher(id)
);

INSERT INTO publisher (name, city)
VALUES ('DMK', 'Moscow'),
       ('MIF', 'Moscow'),
       ('Piter', 'St. Petersburg'),
       ('AST', 'Moscow'),
       ('Rosman', 'Moscow'),
       ('Kazan-book', 'Kazan');

INSERT INTO book (name, author, publisher_id)
VALUES ('War and Peace', 'Tolstoy', 1),
       ('SICP', 'Abelson', 1),
       ('Anna Karenina', 'Tolstoy', 4),
       ('Poetry', 'Pushkin', 3),
       ('Harry Potter', 'Rowling', 5);

INSERT INTO publisher (name, city)
VALUES ('Open source', 'New York');

INSERT INTO publisher (name, city)
VALUES ('Oreilly', 'Sebastopol');

SELECT * FROM publisher;

INSERT INTO book (name, author, publisher_id)
VALUES ('The Subtle Art', 'Manson', 3),
       ('LYAHFAGG', 'Miron', 7),
       ('Learning Java', 'Niemeyer', 8),
       ('Learning React', 'Banks', 8),
       ('Unix in a Nutshell', 'Robbins', 8),
       ('HTML5', 'Pilgrim', 8);


-----------------------
-------- TASKS --------
-----------------------

-- вывести пары автор - издательство, упорядоченные по авторам
SELECT DISTINCT b.author, p.name FROM
  book b INNER JOIN publisher p
  ON b.publisher_id = p.id
  ORDER BY b.author;


-- вывести издательства, которые выпускают только Пушкина
SELECT *
FROM publisher p
WHERE EXISTS(SELECT 1
             FROM book b
             WHERE b.publisher_id = p.id
               AND b.author = 'Pushkin')
      AND NOT EXISTS(SELECT 1 FROM book b
              WHERE b.publisher_id = p.id
                AND b.author != 'Pushkin');

SELECT *
FROM publisher p
WHERE EXISTS(SELECT 1
             FROM book b
             WHERE b.publisher_id = p.id
               AND b.author = 'Pushkin');


SELECT DISTINCT p.id, p.name
  FROM publisher p JOIN book b
  ON p.id = b.publisher_id
GROUP BY b.author, p.id, p.name
HAVING COUNT(b.author) = 1 AND EXISTS(b.author = 'Pushkin')
;

SELECT p.id, p.name
  FROM publisher p JOIN book b on p.id = b.publisher_id
  WHERE EXISTS(b.author = 'Pushkin')
    AND NOT EXISTS(b.author <> 'Pushkin')
;

-- вывести топ 10 издательств по количесвту книг
SELECT p.id, p.name, COUNT(b.id) AS books_count
  FROM publisher p
    LEFT JOIN book b
      ON p.id = b.publisher_id
  GROUP BY p.id, p.name
  ORDER BY books_count DESC
LIMIT 10
;


-- вывести авторов у которых меньше двух книг в библиотеке
SELECT b.author, COUNT(b.id) AS books_count
  FROM book b
  GROUP BY b.author
;

-- вывести все издастельва с количеством книг в библиотеке
SELECT p.id, p.name, COUNT(b.id) AS books_count
  FROM publisher p
    LEFT JOIN book b
      ON p.id = b.publisher_id
  GROUP BY p.id, p.name
;

-- вывести первые 6 чисел Фибоначчи
SELECT 1 UNION ALL
SELECT 1 UNION ALL
SELECT 2 UNION ALL
SELECT 3 UNION ALL
SELECT 5 UNION ALL
SELECT 8;

SELECT * FROM book LIMIT 120;

DELETE FROM book WHERE id > 15;

-- сгенерировать тысячу записей в книги
INSERT INTO book (name, author, publisher_id)
SELECT k :: VARCHAR, k :: VARCHAR, k % 8 + 1
FROM generate_series(1, 1000) AS k;
