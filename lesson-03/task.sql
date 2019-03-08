
-- inheritance
CREATE TABLE weather
(
  temperature INT  NOT NULL,
  day         DATE NOT NULL DEFAULT now()
);

CREATE TABLE weather_1982
(
  CHECK ( day BETWEEN '1982-01-01' AND '1982-12-31')
) INHERITS (weather);

CREATE TABLE weather_1983
(
  CHECK ( day BETWEEN '1983-01-01' AND '1983-12-31')
) INHERITS (weather);

CREATE TABLE weather_1984
(
  CHECK (day BETWEEN '1984-01-01' AND '1984-12-31')
) INHERITS (weather);

-- task 4
CREATE OR REPLACE FUNCTION insert_into_weather() RETURNS TRIGGER AS
$insert_into_weather$
DECLARE
  table_year INTEGER;
BEGIN
  SELECT date_part('year', NEW.day) INTO table_year;

  -- create table for weather in year if it does not exist
  EXECUTE format(
    'CREATE TABLE IF NOT EXISTS weather_%1$s (CHECK (day BETWEEN ''%1$s-01-01'' AND ''%1$s-12-31'')) INHERITS (weather);',
    table_year
  );
    
  EXECUTE format(
      'INSERT INTO weather_%s (temperature, day) VALUES (%s, ''%s\'');',
      table_year,
      NEW.temperature,
      NEW.day
  );
  RETURN NULL;
END;
$insert_into_weather$ LANGUAGE 'plpgsql';

CREATE TRIGGER insert_into_weather
  BEFORE INSERT
  ON weather
  FOR EACH ROW
EXECUTE PROCEDURE insert_into_weather();

INSERT INTO weather (temperature, day)
VALUES (31, '1984-07-07');

SELECT * FROM weather; -- should contain all the weather
SELECT * FROM ONLY weather; -- should be empty

-- maybe you can add trigger on select to shorten selecting time

CREATE OR REPLACE FUNCTION delete_weather() RETURNS TRIGGER AS
  $delete_weather$
  DECLARE
    table_year INTEGER;
  BEGIN
    SELECT date_part('year', OLD.day) INTO table_year;
    EXECUTE format(
        'DELETE FROM weather_%s WHERE temperature = %s AND day = ''%s'';',
        table_year,
        OLD.temperature,
        OLD.day
    );
    RETURN NULL;
  END;
  $delete_weather$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION update_weather() RETURNS TRIGGER AS
  $update_weather$
  DECLARE
    new_table_year INTEGER;
    old_table_year INTEGER;
  BEGIN
    SELECT date_part('year', OLD.day) INTO old_table_year;
    SELECT date_part('year', NEW.day) INTO new_table_year;

    IF (old_table_year = new_table_year) THEN
      RETURN NEW;
    ELSE

      RETURN NULL;
    END IF;
  END;
  $update_weather$ LANGUAGE 'plpgsql';
