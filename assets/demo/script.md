# Redact-1 Demo Script

Welcome to Redact-1, a mobile application for police records redaction. This script will guide you through the complete workflow.

---

## Getting Started with TestFlight

You will receive an email invitation to download the app via TestFlight.

1. **Check your email** for an invitation from TestFlight
2. **Tap "View in TestFlight"** in the email
3. **If prompted**, download the TestFlight app from the App Store
4. **Open TestFlight** and tap "Accept" for Redact-1
5. **Tap "Install"** to download the app
6. **Open Redact-1** from your home screen

---

## Initial Setup (Onboarding)

When you first open the app, you'll see the onboarding screen.

1. **Enter the department code:** `DEFAULT`
2. **Tap "Connect"**

This connects the app to the demo server.

---

## Test Accounts

| Email | Password | Role |
|-------|----------|------|
| supervisor@test.com | test123 | Supervisor |
| clerk@test.com | test123 | Clerk |

---

## Demo Flow

### Part 1: Supervisor Creates and Assigns a Request

#### Login as Supervisor

1. **Open the app** on your iPhone
2. **Enter credentials:**
   - Email: `supervisor@test.com`
   - Password: `test123`
3. **Tap "Sign In"**

You'll see the main screen with four tabs:
- **Requests** - Active records requests
- **Archived** - Completed/archived requests
- **Users** - User management
- **Settings** - Account settings

#### Create a New Request

1. **Tap the "+" button** in the top right corner
2. **Fill in the request details:**
   - Title: "Body Cam Footage - Traffic Stop"
   - Request Number: (auto-generated, or enter custom)
   - Date: Today's date
   - Notes: "Requesting party: City Attorney's Office"
3. **Tap "Create"**

The request is now created with status "New".

#### Assign the Request to a Clerk

1. **Tap on the new request** to open it
2. **Tap "Reassign Request"** in the Request Details section
3. **Select "Test Clerk"** from the list
4. **Tap "Save"**

The request is now assigned to the clerk for processing.

#### Sign Out

1. **Tap the Settings tab**
2. **Tap "Sign Out"**

---

### Part 2: Clerk Processes the Request

#### Login as Clerk

1. **Enter credentials:**
   - Email: `clerk@test.com`
   - Password: `test123`
2. **Tap "Sign In"**

You'll see the request that was assigned to you.

#### Upload a PDF

1. **Tap on the assigned request** to open it
2. **In the File section, tap "Upload PDF"**
3. **Select a PDF** from your device
   - Use `sample_redaction_test.pdf` if available
4. **Wait for upload to complete**

The PDF is now attached to the request.

#### Review and Add Redactions

1. **Tap on the uploaded PDF** to open the editor
2. **Wait for auto-detection** - The app automatically detects:
   - Faces in photos
   - License plates
   - Social Security Numbers
   - Phone numbers
   - Email addresses
   - Dates of birth

3. **Review detected items** - Orange boxes show detected PII

4. **Add manual redactions:**
   - **Long press and drag** anywhere on the page to draw a purple redaction box
   - Release to complete the redaction

5. **Navigate pages:**
   - Swipe left/right on the page indicator at the top
   - Or tap the chevron arrows

6. **Delete a redaction (if needed):**
   - Tap on a purple (manual) redaction box
   - Tap "Delete" when prompted

7. **Tap the green checkmark** to save your changes

#### Preview Redacted Document

1. **Go back to the request detail screen**
2. **Tap "Preview Redacted"** in the Actions section
3. **Review the redacted document**
   - All orange and purple boxes are now solid black
   - Swipe to navigate between pages
4. **Tap "Done"** to close the preview

#### Share the Redacted Document

1. **Tap "Share Redacted"** in the Actions section
2. **Tap "Share"** to start the export
3. **Wait for processing** - The app applies all redactions
4. **Tap "Share Files"** to open the share sheet
5. **Choose your destination:**
   - AirDrop
   - Email
   - Save to Files
   - etc.

#### Update Request Status

1. **On the request detail screen, tap the status badge**
2. **Select "Completed"**

---

### Part 3: Supervisor Reviews and Archives

#### Login as Supervisor

1. **Sign out from the clerk account**
2. **Login with supervisor credentials:**
   - Email: `supervisor@test.com`
   - Password: `test123`

#### Review the Completed Request

1. **Tap on the completed request**
2. **Tap "Preview Redacted"** to verify the redactions

#### Archive the Request

1. **Tap "Archive Request"** in the Actions section
2. **Confirm by tapping "Archive"**
3. **You'll be returned to the request list**

#### View Archived Requests

1. **Tap the "Archived" tab**
2. **Tap any archived request** to view details
3. **Preview the redacted document** if needed

#### Unarchive a Request (if needed)

1. **In the Archived tab, swipe left** on any request
2. **Tap "Unarchive"**
3. **Or open the request and tap "Unarchive Request"**

---

### Part 4: User Management (Supervisor Only)

1. **Tap the "Users" tab**
2. **View all users** in the system
3. **Tap "+" to create a new user:**
   - Enter name, email, password
   - Select role (Clerk or Supervisor)
4. **Tap any user** to view details
5. **Swipe left to delete** a user

---

## Role Capabilities Summary

| Feature | Clerk | Supervisor |
|---------|:-----:|:----------:|
| View assigned requests | Yes | Yes |
| Create requests | Yes | Yes |
| Upload/redact files | Yes | Yes |
| Preview redacted | Yes | Yes |
| Share redacted | Yes | Yes |
| Change status | Yes | Yes |
| Reassign requests | No | Yes |
| Archive requests | No | Yes |
| View archived | No | Yes |
| Unarchive requests | No | Yes |
| Manage users | No | Yes |

---

## Sample Files

The `assets/sample/` folder contains test files you can use:

- **sample_redaction_test.pdf** - Multi-page PDF with sample PII data
- **people-in-mall.png** - Image with faces for detection testing

---

## Tips

- **Auto-detection**: The app automatically runs face/text detection the first time you view a PDF
- **Drawing redactions**: Long press (0.3 seconds) then drag to draw
- **Page navigation**: Swipe on the page indicator capsule, or tap the chevrons
- **Quick delete**: Tap any manual (purple) redaction to get the delete option
- **Saving**: Always tap the green checkmark to save your changes before leaving

---

## Troubleshooting

**PDF won't load?**
- Check your internet connection
- Try uploading a different PDF

**Detections not appearing?**
- Wait for the "Detecting..." spinner to complete
- Some documents may have no detectable PII

**Share not working?**
- Ensure there's at least one redaction (detected or manual)
- The Share button is disabled if no redactions exist

**TestFlight issues?**
- Make sure you're using the email address the invitation was sent to
- Check your spam folder for the TestFlight invitation
- Contact support if the invitation has expired
