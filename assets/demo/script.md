# Redact-1 Demo Script

A mobile application for police records redaction.

---

## Getting Started

1. Check your email for a TestFlight invitation
2. Install the app via TestFlight
3. Open Redact-1 and enter department code: `SPRINGFIELD-PD`

---

## Test Accounts

| Email | Password | Role |
|-------|----------|------|
| supervisor@test.com | test123 | Supervisor |
| clerk@test.com | test123 | Clerk |

---

## Demo Flow

### 1. Supervisor: Create and Assign
Sign in as the supervisor, create a new request, and reassign it to the clerk.

### 2. Clerk: Process the Request
Sign in as the clerk, open the assigned request, upload a PDF, review the auto-detected redactions, add manual redactions as needed, and mark the request complete.

### 3. Supervisor: Review and Share
Sign back in as the supervisor, review the completed request, preview the redactions, share the redacted document, and archive the request.

---

## Role Capabilities

| Feature | Clerk | Supervisor |
|---------|:-----:|:----------:|
| Create/view requests | Yes | Yes |
| Upload and redact files | Yes | Yes |
| Preview/share redacted | Yes | Yes |
| Reassign requests | No | Yes |
| Archive/unarchive | No | Yes |
| Manage users | No | Yes |
