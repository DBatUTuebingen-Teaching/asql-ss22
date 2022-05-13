-- User-defined Python procedure: read BLOB from file

CREATE EXTENSION IF NOT EXISTS plpython3u;

DROP FUNCTION IF EXISTS read_blob(text) CASCADE;
CREATE FUNCTION read_blob(blob text) RETURNS bytea AS
$$
  try:
    file = open(blob, 'rb')
    return file.read()
  except:
    pass
  # could not read file, return NULL
  return None
$$ LANGUAGE plpython3u;

-----------------------------------------------------------------------
-- Store and play GLaDOS voice lines from Portal 1 & 2

DROP TYPE IF EXISTS edition CASCADE;
CREATE TYPE edition AS ENUM ('Portal 1', 'Portal 2');

DROP TABLE IF EXISTS glados;
CREATE TABLE glados (id     int PRIMARY KEY, -- key
                     voice  bytea,           -- BLOB data
                     line   text,            -- ⎱ meta data,
                     portal edition);        -- ⎰ properties


\set blob_path '/Users/grust/AdvancedSQL/slides/Week03/live/GLaDOS/'

INSERT INTO glados(id, line, portal, voice)
  SELECT quotes.id, quotes.line, quotes.portal :: edition,
         read_blob(:'blob_path' || quotes.wav) AS voice
  FROM
    (VALUES (1, '... you will be missed',       'Portal 1', 'will-be-missed.wav'),
            (2, 'Two plus two is...ten',        'Portal 1', 'base-four.wav'),
            (3, 'The facility is ...',          'Portal 2', 'facility-operational.wav'),
            (4, 'Don''t press that button ...', 'Portal 2', 'press-button.wav')) AS quotes(id,line,portal,wav);


-- Dump table contents, encode (prefix of) BLOB for table output
SELECT g.id, g.line, g.portal,
       left(encode(g.voice, 'base64'), 20) AS voice
FROM   glados AS g;

-- Extract selected GLaDOS voice line, play the resulting audio file
-- (on macOS/SoX) via
--
--   $ play -q /tmp/GlaDOS-says.wav
--
COPY (
  SELECT translate(encode(g.voice, 'base64'), E'\n', '')
  FROM   glados AS g
  WHERE  g.id = 3
) TO PROGRAM 'base64 -d > /tmp/GlaDOS-says.wav';
