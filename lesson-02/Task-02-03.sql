CREATE TABLE weather
(
  temperature INT  NOT NULL,
  day         DATE NOT NULL DEFAULT now()
);

CREATE TABLE weather_1981
(
  CHECK (day BETWEEN '1981-01-01' AND '1981-12-31')
) INHERITS (weather);

CREATE TABLE weather_1982
(
  CHECK (day BETWEEN '1982-01-01' AND '1982-12-31')
) INHERITS (weather);


CREATE OR REPLACE FUNCTION averageTemperature(year INTEGER)
  RETURNS TABLE
          (
            avg NUMERIC
          ) AS
$$
BEGIN
  RETURN QUERY EXECUTE format('SELECT AVG(temperature) FROM weather_%s', year);
END;
$$ LANGUAGE 'plpgsql';

INSERT INTO weather_1981 (temperature, day)
VALUES (-4 , '1981-02-03'),
       (-10, '1981-02-04');

SELECT averageTemperature(1981); -- -7 OK

CREATE OR REPLACE FUNCTION averageTemperature(year_from INTEGER, year_to INTEGER)
  RETURNS NUMERIC AS
$$
DECLARE
  summa NUMERIC = 0;
  av   NUMERIC;
BEGIN
  FOR year IN year_from..year_to
    LOOP
      SELECT averageTemperature(year) INTO av;
      summa = summa + av;
    END LOOP;
  RETURN summa / (year_to - year_from + 1);
END;
$$ LANGUAGE 'plpgsql';

INSERT INTO weather_1982 VALUES (-10, '1982-03-04');

SELECT averageTemperature(1981, 1982); -- -8.5 OK

-------------------------------------------------

