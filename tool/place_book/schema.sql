CREATE TABLE meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE places (
  id INTEGER PRIMARY KEY,
  osm_ref TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  alt_names TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL,
  lat REAL NOT NULL,
  lon REAL NOT NULL,
  town TEXT NOT NULL DEFAULT '',
  province TEXT NOT NULL DEFAULT '',
  weight INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX places_lat ON places(lat);

CREATE VIRTUAL TABLE places_fts USING fts5(
  name,
  alt_names,
  town,
  province,
  content = 'places',
  content_rowid = 'id',
  tokenize = 'unicode61 remove_diacritics 2',
  prefix = '2 3'
);
