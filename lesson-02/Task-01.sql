
CREATE TABLE office
(
  id        SERIAL PRIMARY KEY,
  name      VARCHAR(31) NOT NULL,
  emp_count INTEGER     NOT NULL DEFAULT 0,
  CONSTRAINT emp_count_cant_be_less_than_zero CHECK (emp_count >= 0)
);

CREATE TABLE emp
(
  id        SERIAL PRIMARY KEY,
  name      VARCHAR(31) NOT NULL,
  office_id INTEGER     NOT NULL,
  CONSTRAINT office_fk FOREIGN KEY (office_id) REFERENCES office (id)
);

-- hire new employee and refresh emp_count in office table
CREATE FUNCTION office_new_emp_count() RETURNS TRIGGER AS
$office_new_emp_count$
BEGIN
  UPDATE office SET emp_count = emp_count + 1 WHERE (id = NEW.office_id);
  RETURN NEW;
END;
$office_new_emp_count$ LANGUAGE plpgsql;

DROP TRIGGER office_new_emp_count ON emp;

CREATE TRIGGER office_new_emp_count
  AFTER INSERT
  ON emp
  FOR EACH ROW
EXECUTE PROCEDURE office_new_emp_count();

-- fire an employee and refresh emp_count in office table
CREATE OR REPLACE FUNCTION office_emp_left_count() RETURNS TRIGGER AS
$office_emp_left_count$
BEGIN
  UPDATE office SET emp_count = emp_count - 1 WHERE (id = OLD.office_id);
  RETURN NULL;
END;
$office_emp_left_count$ LANGUAGE plpgsql;

DROP TRIGGER office_emp_left_count ON emp;
CREATE TRIGGER office_emp_left_count
  AFTER DELETE
  ON emp
  FOR EACH ROW
EXECUTE PROCEDURE office_emp_left_count();


-- move employee to another office and refresh emp_count in office table
CREATE FUNCTION office_emp_moved_count() RETURNS TRIGGER AS
$office_emp_moved_count$
BEGIN
  IF OLD.office_id <> NEW.office_id THEN
    UPDATE office SET emp_count = emp_count - 1 WHERE (id = OLD.office_id);
    UPDATE office SET emp_count = emp_count + 1 WHERE (id = NEW.office_id);
  END IF;
  RETURN NEW;
END;
$office_emp_moved_count$ LANGUAGE plpgsql;

DROP TRIGGER office_emp_moved_count ON emp;
CREATE TRIGGER office_emp_moved_count
  AFTER UPDATE
  ON emp
  FOR EACH ROW
EXECUTE PROCEDURE office_emp_moved_count();

INSERT INTO office (name)
VALUES ('Business office'),
       ('Open space office');

SELECT *
FROM office;
SELECT *
FROM emp;

INSERT INTO emp (name, office_id)
VALUES ('Daler', 2);
UPDATE emp
SET office_id = 1
WHERE id = 1;
DELETE
FROM emp
WHERE id = 1;
