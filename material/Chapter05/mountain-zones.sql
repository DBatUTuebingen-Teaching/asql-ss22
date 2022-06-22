DROP TABLE IF EXISTS mountains;
CREATE TABLE mountains (
  x   integer NOT NULL PRIMARY KEY,
  alt integer NOT NULL
);

-- Height of mountain range at location x
-- (missing x value: no altiude change has occurred)
--
INSERT INTO mountains VALUES
  (   0,    0),
  ( 100,  100),
  ( 200,  300),
  ( 300,  400),
  ( 400,  200),
  ( 500,  100),
  ( 600,    0),
  (1000, -100),
  (1100,    0),
  (1200,  200),
  (1300,  400),
  (1400,  600),
  (1500,  500),
  (1600,  700),
  (1700,  800),
  (1800,  900),
  (1900,  700),
  (2000,  500),
  (2100,  400),
  (2300,  300),
  (2400,  100),
  (2500,    0),
  (2600, -100),
  (2700, -200),
  (2800, -100),
  (3000,    0);


-- Classify mountain range: vegetation zones and low-/highlands
--
SELECT m.x,
       m.alt,
       NTILE(4) OVER altitude AS zone,
       CASE
         WHEN PERCENT_RANK() OVER altitude BETWEEN 0.60 AND 0.80 THEN 'highlands'
         WHEN PERCENT_RANK() OVER altitude < 0.20 THEN 'lowlands'
         ELSE '-'
       END AS region
FROM   mountains AS m
WINDOW altitude AS (ORDER BY m.alt)
ORDER BY m.x;

