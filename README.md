# Redact-1: Police Records Redaction System

A mobile-first iOS app for redacting sensitive information from images and PDFs for FOIA/public records requests.

## Quick Start

### 1. Create Xcode Project

Open Xcode and create a new iOS App:
1. File → New → Project → iOS → App
2. Product Name: `Redact1`
3. Organization Identifier: `com.aifirst`
4. Interface: SwiftUI
5. Language: Swift
6. Save in the `redact-1-ios` directory

Then drag the contents of the `Redact1/` folder into your Xcode project.

### 2. Add ViewInspector for Testing

Add to your project's Swift Package dependencies:
```
https://github.com/nalexn/ViewInspector
```

### 3. Create Test User

The worker is already deployed. Create a test user:

```bash
curl -X POST https://redact-1-worker.joelstevick.workers.dev/api/users \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@example.com", "password": "password123", "name": "Admin User"}'
```

### 4. Run the App

Build and run in Xcode on a simulator or device.

## Architecture

```
┌─────────────────────────────────────────┐
│        iOS App (SwiftUI)                │
│  ┌─────────────┐  ┌─────────────────┐   │
│  │   Views     │  │ Apple Vision    │   │
│  └─────────────┘  │ (face/plate/OCR)│   │
│                   └─────────────────┘   │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│       Cloudflare Worker (TypeScript)     │
│  https://redact-1-worker.joelstevick.   │
│               workers.dev                │
└─────────────────────────────────────────┘
          │                 │
          ▼                 ▼
     ┌─────────┐       ┌──────────┐
     │   D1    │       │    R2    │
     │ Database│       │  Storage │
     └─────────┘       └──────────┘
```

## Features

### Workflow
- Create FOIA/records requests
- Upload images (JPG, PNG) and PDFs
- Auto-detect faces, license plates, PII (SSN, phone, email, DOB)
- Review and approve/reject detections
- Add manual redactions
- Export redacted files with audit report

### Detection (On-Device)
- **Faces**: Apple Vision `VNDetectFaceRectanglesRequest`
- **License Plates**: Apple Vision text recognition
- **PII**: Regex patterns on OCR results
  - SSN: `\d{3}-\d{2}-\d{4}`
  - Phone: Various formats
  - Email: Standard pattern
  - Date of Birth: MM/DD/YYYY patterns

### Redaction
- Solid black boxes (legal standard)
- Applied to approved detections + manual redactions

## Project Structure

```
redact-1-ios/
├── Redact1/
│   ├── Models/
│   │   ├── User.swift
│   │   ├── Request.swift
│   │   ├── EvidenceFile.swift
│   │   └── Detection.swift
│   ├── Views/
│   │   ├── LoginView.swift
│   │   ├── RequestListView.swift
│   │   ├── RequestDetailView.swift
│   │   ├── ImageReviewView.swift
│   │   ├── PDFReviewView.swift
│   │   └── ...
│   ├── Services/
│   │   ├── APIService.swift
│   │   ├── AuthService.swift
│   │   ├── VisionService.swift
│   │   └── RedactionService.swift
│   └── Assets.xcassets/
│
├── worker/
│   ├── src/
│   │   ├── index.ts
│   │   └── routes/
│   ├── schema.sql
│   ├── wrangler.toml
│   └── package.json
│
├── PLAN.md
├── CLAUDE.md
└── README.md
```

## API Endpoints

Base URL: `https://redact-1-worker.joelstevick.workers.dev`

### Auth
- `POST /api/auth/login` - Login
- `POST /api/auth/logout` - Logout
- `GET /api/auth/me` - Current user

### Requests
- `GET /api/requests` - List requests
- `POST /api/requests` - Create request
- `GET /api/requests/:id` - Get request
- `PUT /api/requests/:id` - Update request
- `DELETE /api/requests/:id` - Delete request

### Files
- `GET /api/requests/:id/files` - List files
- `POST /api/requests/:id/files` - Upload file
- `GET /api/files/:id/original` - Get original file
- `GET /api/files/:id/redacted` - Get redacted file
- `POST /api/files/:id/redacted` - Upload redacted file

### Detections
- `GET /api/files/:id/detections` - List detections
- `POST /api/files/:id/detections` - Create detections
- `PUT /api/detections/:id` - Update detection status

## Development

### Worker
```bash
cd worker
npm install
npm run dev  # Local development
npm run deploy  # Deploy to Cloudflare
```

### Database Migrations
```bash
cd worker
npm run db:migrate  # Apply schema changes
```

## License

Proprietary - AiFirst Development
