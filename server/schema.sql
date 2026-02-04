-- Grow D1 Schema (mirrors Flutter SQLite v11)
-- Run: npx wrangler d1 execute grow-db --file=schema.sql

CREATE TABLE IF NOT EXISTS locations (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  environment_type INTEGER NOT NULL DEFAULT 0,
  latitude REAL,
  longitude REAL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS plots (
  id TEXT PRIMARY KEY,
  location_id TEXT NOT NULL,
  name TEXT NOT NULL,
  cover_type INTEGER NOT NULL DEFAULT 0,
  soil_type INTEGER NOT NULL DEFAULT 0,
  memo TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS crops (
  id TEXT PRIMARY KEY,
  cultivation_name TEXT NOT NULL DEFAULT '',
  name TEXT NOT NULL DEFAULT '',
  variety TEXT NOT NULL DEFAULT '',
  plot_id TEXT,
  parent_crop_id TEXT,
  memo TEXT NOT NULL DEFAULT '',
  start_date TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (plot_id) REFERENCES plots(id) ON DELETE SET NULL,
  FOREIGN KEY (parent_crop_id) REFERENCES crops(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS records (
  id TEXT PRIMARY KEY,
  crop_id TEXT,
  location_id TEXT,
  plot_id TEXT,
  activity_type INTEGER NOT NULL,
  date TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (crop_id) REFERENCES crops(id) ON DELETE CASCADE,
  FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE,
  FOREIGN KEY (plot_id) REFERENCES plots(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS record_photos (
  id TEXT PRIMARY KEY,
  record_id TEXT NOT NULL,
  file_path TEXT NOT NULL,
  r2_key TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (record_id) REFERENCES records(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS observations (
  id TEXT PRIMARY KEY,
  location_id TEXT,
  plot_id TEXT,
  category INTEGER NOT NULL DEFAULT 0,
  date TEXT NOT NULL,
  memo TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE,
  FOREIGN KEY (plot_id) REFERENCES plots(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS observation_entries (
  id TEXT PRIMARY KEY,
  observation_id TEXT NOT NULL,
  key TEXT NOT NULL,
  value REAL NOT NULL,
  unit TEXT NOT NULL DEFAULT '',
  updated_at TEXT NOT NULL,
  FOREIGN KEY (observation_id) REFERENCES observations(id) ON DELETE CASCADE
);

-- Deleted records tracking for sync
CREATE TABLE IF NOT EXISTS deleted_records (
  id TEXT NOT NULL,
  table_name TEXT NOT NULL,
  deleted_at TEXT NOT NULL,
  PRIMARY KEY (id, table_name)
);

-- Index for sync queries
CREATE INDEX IF NOT EXISTS idx_locations_updated ON locations(updated_at);
CREATE INDEX IF NOT EXISTS idx_plots_updated ON plots(updated_at);
CREATE INDEX IF NOT EXISTS idx_crops_updated ON crops(updated_at);
CREATE INDEX IF NOT EXISTS idx_records_updated ON records(updated_at);
CREATE INDEX IF NOT EXISTS idx_record_photos_updated ON record_photos(updated_at);
CREATE INDEX IF NOT EXISTS idx_observations_updated ON observations(updated_at);
CREATE INDEX IF NOT EXISTS idx_observation_entries_updated ON observation_entries(updated_at);
CREATE INDEX IF NOT EXISTS idx_deleted_records_deleted ON deleted_records(deleted_at);
