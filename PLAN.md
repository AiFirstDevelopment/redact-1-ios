# Redact-1: Police Records Redaction System

## Product Vision

**The Problem:** Current redaction tools (Axon, Mark43, CentralSquare) are desktop-first, slow, and buried inside complex enterprise suites. Records clerks spend hours clicking through multi-step processes.

**Our Approach:** A mobile-first, standalone redaction workflow that gets the job done in minutes, not hours.

| Competitors | Redact-1 |
|-------------|----------|
| Desktop-first | Mobile-first (iPad in the field) |
| Part of $150/officer/month suite | Standalone tool |
| Multi-day training | Productive in 15 minutes |
| Complex multi-step process | Upload → Auto-detect → Review → Export |
| Requires ecosystem buy-in | Works with any evidence source |

**Core Workflow:**
1. Create request (FOIA case number, notes)
2. Upload images/PDFs
3. Auto-detection runs on-device (faces, plates, PII)
4. Review: approve/reject detections, add manual redactions
5. Export redacted files + audit report

**The redaction features (faces, plates, SSN detection) are table stakes.** The win is the workflow speed and simplicity.

---

## Architecture Overview

Using the same Cloudflare stack as crossfire:
- **Cloudflare Worker** (TypeScript) - API backend
- **Cloudflare D1** - SQL database for metadata
- **Cloudflare R2** - File storage (originals + redacted outputs)
- **Cloudflare Pages** - Frontend (Vite + Capacitor for iOS)

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS App (Capacitor)                      │
│                    React/TypeScript + Vite                       │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Cloudflare Worker                           │
│         ┌─────────────┐            ┌─────────────┐              │
│         │  REST API   │            │  Auth/JWT   │              │
│         └─────────────┘            └─────────────┘              │
└─────────────────────────────────────────────────────────────────┘
                  │                        │
                  ▼                        ▼
             ┌─────────┐              ┌──────────┐
             │   D1    │              │    R2    │
             │ Database│              │  Storage │
             └─────────┘              └──────────┘
```

---

## MVP Scope

### Workflow Features (Differentiators)
- **Fast case creation** - Title, request number, done
- **Drag-and-drop upload** - Multiple files at once, progress indicator
- **Instant auto-detection** - Runs on-device, no waiting for server
- **One-tap review** - Approve/reject each detection with a tap
- **Manual redaction** - Draw boxes for anything missed
- **One-click export** - ZIP with redacted files + audit PDF

### Redaction Features (Table Stakes)

| File Type | What We Detect | How |
|-----------|----------------|-----|
| Images | Faces | Apple Vision `VNDetectFaceRectanglesRequest` |
| Images | License plates | Apple Vision text recognition |
| Images | Text with PII | Apple Vision OCR → regex |
| PDFs | SSN, phone, email, DOB, addresses | Text extraction → regex |
| PDFs (scanned) | Same as above | Apple Vision OCR → regex |

All redactions render as **solid black boxes** (legal standard).

### What's Deferred
- Video redaction
- Configurable detection patterns
- Multi-user concurrent editing

---

## Database Schema (D1)

```sql
-- Users
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Records Requests (Cases)
CREATE TABLE requests (
  id TEXT PRIMARY KEY,
  request_number TEXT UNIQUE NOT NULL,
  title TEXT NOT NULL,
  request_date INTEGER NOT NULL,
  notes TEXT,
  status TEXT NOT NULL CHECK (status IN ('new', 'processing', 'review', 'exported')),
  created_by TEXT NOT NULL REFERENCES users(id),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Evidence Files
CREATE TABLE files (
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
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Detections (auto-detected sensitive regions)
CREATE TABLE detections (
  id TEXT PRIMARY KEY,
  file_id TEXT NOT NULL REFERENCES files(id),
  detection_type TEXT NOT NULL CHECK (detection_type IN ('face', 'plate', 'ssn', 'phone', 'email', 'address', 'dob')),
  -- For images: bounding box (normalized 0-1)
  bbox_x REAL,
  bbox_y REAL,
  bbox_width REAL,
  bbox_height REAL,
  -- For PDFs: page and text range
  page_number INTEGER,
  text_start INTEGER,
  text_end INTEGER,
  text_content TEXT,
  -- Metadata
  confidence REAL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by TEXT REFERENCES users(id),
  reviewed_at INTEGER,
  created_at INTEGER NOT NULL
);

-- Manual Redactions (user-added)
CREATE TABLE manual_redactions (
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
CREATE TABLE exports (
  id TEXT PRIMARY KEY,
  request_id TEXT NOT NULL REFERENCES requests(id),
  r2_key TEXT NOT NULL,
  filename TEXT NOT NULL,
  file_count INTEGER NOT NULL,
  exported_by TEXT NOT NULL REFERENCES users(id),
  created_at INTEGER NOT NULL
);

-- Audit Log
CREATE TABLE audit_logs (
  id TEXT PRIMARY KEY,
  user_id TEXT REFERENCES users(id),
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  details TEXT, -- JSON
  created_at INTEGER NOT NULL
);

CREATE INDEX idx_files_request ON files(request_id);
CREATE INDEX idx_detections_file ON detections(file_id);
CREATE INDEX idx_manual_redactions_file ON manual_redactions(file_id);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
```

---

## R2 Storage Structure

```
redact-1-files/
├── originals/
│   └── {request_id}/
│       └── {file_id}/{filename}
├── redacted/
│   └── {request_id}/
│       └── {file_id}/{filename}
├── exports/
│   └── {request_id}/
│       └── {export_id}.zip
└── thumbnails/
    └── {file_id}/
        └── thumb.jpg
```

---

## API Endpoints

### Auth
```
POST /api/auth/login          - Login, returns JWT
POST /api/auth/logout         - Invalidate session
GET  /api/auth/me             - Get current user
```

### Users
```
GET    /api/users             - List users
POST   /api/users             - Create user
PUT    /api/users/:id         - Update user
DELETE /api/users/:id         - Delete user
```

### Requests
```
GET    /api/requests          - List requests (with filters)
POST   /api/requests          - Create request
GET    /api/requests/:id      - Get request details
PUT    /api/requests/:id      - Update request
DELETE /api/requests/:id      - Delete request
```

### Files
```
GET    /api/requests/:id/files           - List files for request
POST   /api/requests/:id/files           - Upload file(s)
GET    /api/files/:id                    - Get file metadata
DELETE /api/files/:id                    - Delete file
GET    /api/files/:id/original           - Get signed URL for original
GET    /api/files/:id/redacted           - Get signed URL for redacted
```

### Detections
```
GET    /api/files/:id/detections         - List detections for file
POST   /api/files/:id/detections         - Save detections (from client)
PUT    /api/detections/:id               - Update detection (approve/reject)
POST   /api/files/:id/manual-redactions  - Add manual redaction
DELETE /api/manual-redactions/:id        - Remove manual redaction
```

### Export
```
POST   /api/requests/:id/export          - Generate export bundle
GET    /api/requests/:id/exports         - List exports
GET    /api/exports/:id/download         - Download export ZIP
```

### Audit
```
GET    /api/requests/:id/audit           - Get audit log for request
GET    /api/files/:id/audit              - Get audit log for file
```

---

## Frontend Pages

1. **Login** (`/login`)
2. **Dashboard** (`/`) - Request list with filters
3. **Create Request** (`/requests/new`)
4. **Request Detail** (`/requests/:id`) - Files list, status, actions
5. **File Upload** (`/requests/:id/upload`)
6. **Review Image** (`/files/:id/review`) - Side-by-side view, detection toggles, manual redaction
7. **Review PDF** (`/files/:id/review-pdf`) - Page-by-page view, text highlights
8. **Export** (`/requests/:id/export`) - Generate and download
9. **Audit Trail** (`/requests/:id/audit`)
10. **Users** (`/users`) - User management

---

## Detection Flow

All detection happens **on-device** using Apple Vision framework. No external APIs.

### Image Detection (iOS)
```
1. User uploads image
2. Image stored in R2, metadata in D1
3. Client downloads image for processing
4. Apple Vision runs:
   - VNDetectFaceRectanglesRequest → face bounding boxes
   - VNRecognizeTextRequest → text regions
5. Client runs regex on detected text for PII
6. Detections sent to API and stored in D1
7. User reviews in Review UI
```

### PDF Detection (iOS)
```
1. User uploads PDF
2. PDF stored in R2, metadata in D1
3. Client downloads PDF for processing
4. For each page:
   - Extract text (if text-based PDF)
   - Or run VNRecognizeTextRequest (if scanned)
5. Run regex patterns on text for PII
6. Detections sent to API with page/position info
7. User reviews in Review UI
```

### Regex Patterns
```typescript
const patterns = {
  ssn: /\b\d{3}-\d{2}-\d{4}\b/g,
  phone: /\b(\(\d{3}\)\s?|\d{3}[-.])\d{3}[-.]?\d{4}\b/g,
  email: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g,
  dob: /\b(0[1-9]|1[0-2])[\/\-](0[1-9]|[12]\d|3[01])[\/\-](19|20)\d{2}\b/g,
};
```

---

## Project Structure

```
redact-1-ios/
├── worker/
│   ├── src/
│   │   ├── index.ts              # Main worker entry
│   │   ├── routes/
│   │   │   ├── auth.ts
│   │   │   ├── requests.ts
│   │   │   ├── files.ts
│   │   │   ├── detections.ts
│   │   │   ├── exports.ts
│   │   │   └── users.ts
│   │   ├── services/
│   │   │   ├── pdf.ts            # PDF redaction rendering
│   │   │   ├── image.ts          # Image redaction rendering
│   │   │   └── export.ts         # ZIP generation
│   │   ├── middleware/
│   │   │   └── auth.ts
│   │   ├── types.ts
│   │   └── utils.ts
│   ├── schema.sql
│   ├── wrangler.toml
│   ├── package.json
│   └── tsconfig.json
│
├── frontend/
│   ├── src/
│   │   ├── main.ts
│   │   ├── App.tsx
│   │   ├── pages/
│   │   │   ├── Login.tsx
│   │   │   ├── Dashboard.tsx
│   │   │   ├── RequestDetail.tsx
│   │   │   ├── FileReviewImage.tsx
│   │   │   ├── FileReviewPdf.tsx
│   │   │   └── ...
│   │   ├── components/
│   │   │   ├── RedactionCanvas.tsx
│   │   │   ├── DetectionList.tsx
│   │   │   ├── FileUpload.tsx
│   │   │   └── ...
│   │   ├── services/
│   │   │   ├── api.ts
│   │   │   ├── vision.ts         # iOS Vision integration via Capacitor plugin
│   │   │   └── auth.ts
│   │   └── types.ts
│   ├── ios/                       # Capacitor iOS
│   ├── index.html
│   ├── vite.config.ts
│   ├── capacitor.config.ts
│   └── package.json
│
├── shared/
│   └── types.ts                   # Shared types
│
├── PLAN.md
└── package.json
```

---

## Implementation Order

### Phase 1: Foundation (Week 1)
- [ ] Set up monorepo structure
- [ ] Create D1 database and schema
- [ ] Create R2 bucket
- [ ] Implement auth (login, JWT, middleware)
- [ ] Basic frontend shell with routing

### Phase 2: Request Management (Week 2)
- [ ] Requests CRUD API
- [ ] Dashboard page (list, filter, search)
- [ ] Create/edit request pages
- [ ] Request detail page

### Phase 3: File Upload (Week 2-3)
- [ ] File upload API (R2)
- [ ] Upload UI with progress
- [ ] File list in request detail
- [ ] Thumbnail generation

### Phase 4: Detection - Images (Week 3-4)
- [ ] Capacitor plugin for Apple Vision
- [ ] Face detection integration
- [ ] Text/OCR detection integration
- [ ] PII regex matching
- [ ] Detection storage API
- [ ] Detection overlay on images

### Phase 5: Detection - PDFs (Week 4)
- [ ] PDF text extraction
- [ ] Scanned PDF OCR via Vision
- [ ] PII regex matching
- [ ] Detection storage for PDFs

### Phase 6: Review UI (Week 5)
- [ ] Side-by-side original/redacted view
- [ ] Detection approve/reject toggles
- [ ] Manual redaction drawing (canvas)
- [ ] Save review state

### Phase 7: Export (Week 6)
- [ ] Apply redactions to images (solid black boxes)
- [ ] Apply redactions to PDFs (solid black boxes)
- [ ] Generate audit report
- [ ] ZIP bundle generation
- [ ] Export download

### Phase 8: Polish (Week 7)
- [ ] User management UI
- [ ] Audit log UI
- [ ] Error handling
- [ ] iOS Capacitor build and test

---

## Cloudflare Resources

Using same account as crossfire:

```bash
# D1 Database
npx wrangler d1 create redact-1-db

# R2 Bucket
npx wrangler r2 bucket create redact-1-files
```

### wrangler.toml
```toml
name = "redact-1-worker"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[[d1_databases]]
binding = "DB"
database_name = "redact-1-db"
database_id = "..." # After creation

[[r2_buckets]]
binding = "FILES_BUCKET"
bucket_name = "redact-1-files"

[vars]
ENVIRONMENT = "development"
JWT_SECRET = "..." # Set via wrangler secret
```

---

## Security Considerations

1. **Auth**: JWT with short expiry
2. **File Access**: Signed URLs with expiry for R2 objects
3. **CORS**: Restrict to known origins
4. **Input Validation**: Validate all inputs, especially file uploads
5. **Audit Trail**: Log all sensitive actions
6. **File Isolation**: Each request's files in separate R2 prefix

---

## Next Steps

1. Confirm this plan
2. Set up Cloudflare resources (D1, R2)
3. Scaffold project structure
4. Begin Phase 1 implementation
