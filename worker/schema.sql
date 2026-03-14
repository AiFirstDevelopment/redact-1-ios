-- Agencies
CREATE TABLE IF NOT EXISTS agencies (
  id TEXT PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  api_base_url TEXT NOT NULL,
  login_identifiers TEXT NOT NULL, -- JSON array: ["email", "employeeId"]
  primary_color TEXT,
  support_email TEXT,
  support_phone TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Users
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  deleted_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Records Requests (Cases)
CREATE TABLE IF NOT EXISTS requests (
  id TEXT PRIMARY KEY,
  request_number TEXT UNIQUE NOT NULL,
  title TEXT NOT NULL,
  request_date INTEGER NOT NULL,
  notes TEXT,
  status TEXT NOT NULL CHECK (status IN ('new', 'in_progress', 'completed')),
  created_by TEXT NOT NULL REFERENCES users(id),
  archived_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Evidence Files
CREATE TABLE IF NOT EXISTS files (
  id TEXT PRIMARY KEY,
  request_id TEXT NOT NULL REFERENCES requests(id),
  filename TEXT NOT NULL,
  file_type TEXT NOT NULL CHECK (file_type IN ('image', 'pdf')),
  mime_type TEXT NOT NULL,
  file_size INTEGER NOT NULL,
  original_r2_key TEXT NOT NULL,
  redacted_r2_key TEXT,
  status TEXT NOT NULL CHECK (status IN ('uploaded', 'processing', 'detected', 'reviewed', 'exported')),
  uploaded_by TEXT NOT NULL REFERENCES users(id),
  deleted_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Detections (auto-detected sensitive regions)
CREATE TABLE IF NOT EXISTS detections (
  id TEXT PRIMARY KEY,
  file_id TEXT NOT NULL REFERENCES files(id),
  detection_type TEXT NOT NULL CHECK (detection_type IN ('face', 'plate', 'ssn', 'phone', 'email', 'address', 'dob')),
  bbox_x REAL,
  bbox_y REAL,
  bbox_width REAL,
  bbox_height REAL,
  page_number INTEGER,
  text_start INTEGER,
  text_end INTEGER,
  text_content TEXT,
  confidence REAL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by TEXT REFERENCES users(id),
  reviewed_at INTEGER,
  created_at INTEGER NOT NULL
);

-- Manual Redactions (user-added)
CREATE TABLE IF NOT EXISTS manual_redactions (
  id TEXT PRIMARY KEY,
  file_id TEXT NOT NULL REFERENCES files(id),
  redaction_type TEXT NOT NULL,
  bbox_x REAL,
  bbox_y REAL,
  bbox_width REAL,
  bbox_height REAL,
  page_number INTEGER,
  created_by TEXT NOT NULL REFERENCES users(id),
  created_at INTEGER NOT NULL
);

-- Export Bundles
CREATE TABLE IF NOT EXISTS exports (
  id TEXT PRIMARY KEY,
  request_id TEXT NOT NULL REFERENCES requests(id),
  r2_key TEXT NOT NULL,
  filename TEXT NOT NULL,
  file_count INTEGER NOT NULL,
  exported_by TEXT NOT NULL REFERENCES users(id),
  created_at INTEGER NOT NULL
);

-- Audit Log
CREATE TABLE IF NOT EXISTS audit_logs (
  id TEXT PRIMARY KEY,
  user_id TEXT REFERENCES users(id),
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  details TEXT,
  created_at INTEGER NOT NULL
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_files_request ON files(request_id);
CREATE INDEX IF NOT EXISTS idx_detections_file ON detections(file_id);
CREATE INDEX IF NOT EXISTS idx_manual_redactions_file ON manual_redactions(file_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
