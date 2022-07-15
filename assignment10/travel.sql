DROP TABLE IF EXISTS cities CASCADE;
DROP TABLE IF EXISTS roads CASCADE;

-- Each city has a name as its primary key and an indicator, whether a city provides refueling.
-- If "fuel" is 1, the city provides a refueling station. Otherwise, it does not.
CREATE TABLE cities (
  city text PRIMARY KEY,
  fuel int NOT NULL,
  CONSTRAINT fueling_station CHECK (fuel = 0 OR fuel = 1)
);

-- The roads connect two cities from the city "here" to the city "there" with a distance of "dist".
-- Each distance unit costs one unit of fuel when traveled.
CREATE TABLE roads (
  here  text REFERENCES cities(city),
  dist  int CHECK(dist > 0),
  there text REFERENCES cities(city),
  PRIMARY KEY(here, dist, there)
);

INSERT INTO cities VALUES
  ('Saarbruecken'    , 1),
  ('Kaiserslautern'  , 0),
  ('Darmstadt'       , 1),
  ('Wuerzburg'       , 1),
  ('Mannheim'        , 0),
  ('Heidelberg'      , 1),
  ('Karlsruhe'       , 0),
  ('Freiburg'        , 1),
  ('Konstanz'        , 1),
  ('Tuebingen'       , 0),
  ('Stuttgart'       , 1),
  ('Friedrichshafen' , 0),
  ('Biberach'        , 1),
  ('Ulm'             , 1),
  ('Erlangen'        , 0),
  ('Nuernberg'       , 1),
  ('Augsburg'        , 0),
  ('Muenchen'        , 1),
  ('Rosenheim'       , 0),
  ('Landshut'        , 0),
  ('Passau'          , 0);

INSERT INTO roads VALUES
  ('Saarbruecken'    , 40 , 'Kaiserslautern'),
  ('Saarbruecken'    , 160, 'Freiburg'),
  ('Saarbruecken'    , 120, 'Karlsruhe'),
  ('Kaiserslautern'  , 60 , 'Darmstadt'),
  ('Kaiserslautern'  , 30 , 'Mannheim'),
  ('Mannheim'        , 30 , 'Darmstadt'),
  ('Mannheim'        , 20 , 'Heidelberg'),
  ('Darmstadt'       , 90 , 'Wuerzburg'),
  ('Heidelberg'      , 90 , 'Wuerzburg'),
  ('Heidelberg'      , 30 , 'Karlsruhe'),
  ('Wuerzburg'       , 70 , 'Erlangen'),
  ('Karlsruhe'       , 70 , 'Stuttgart'),
  ('Freiburg'        , 120, 'Karlsruhe'),
  ('Freiburg'        , 130, 'Tuebingen'),
  ('Freiburg'        , 100, 'Konstanz'),
  ('Konstanz'        , 30 , 'Friedrichshafen'),
  ('Tuebingen'       , 120, 'Konstanz'),
  ('Tuebingen'       , 30 , 'Stuttgart'),
  ('Stuttgart'       , 60 , 'Ulm'),
  ('Friedrichshafen' , 60 , 'Biberach'),
  ('Biberach'        , 40 , 'Ulm'),
  ('Ulm'             , 150, 'Erlangen'),
  ('Ulm'             , 40 , 'Augsburg'),
  ('Erlangen'        , 20 , 'Nuernberg'),
  ('Augsburg'        , 70 , 'Nuernberg'),
  ('Augsburg'        , 50 , 'Muenchen'),
  ('Nuernberg'       , 100, 'Landshut'),
  ('Nuernberg'       , 110, 'Muenchen'),
  ('Muenchen'        , 70 , 'Rosenheim'),
  ('Muenchen'        , 40 , 'Landshut'),
  ('Landshut'        , 90 , 'Passau'),
  ('Landshut'        , 80 , 'Passau'),
  ('Rosenheim'       , 110, 'Passau');