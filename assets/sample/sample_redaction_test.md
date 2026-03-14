# Redaction Test Document

This document contains sample data for testing the Redact1 application's detection and redaction capabilities.

---

## Sample Image (Face Detection)

The following image contains faces that should be automatically detected for redaction:

![People in Mall](people-in-mall.png)

**Expected Detections:** Faces of individuals in the image

---

## Sample Text Document (PII Detection)

The following text contains various types of personally identifiable information (PII) that should be detected and redacted:

---

### SPRINGFIELD POLICE DEPARTMENT
### INCIDENT REPORT - CONFIDENTIAL

**Case Number:** SPD-2024-00847
**Date of Report:** 03/14/2024

---

#### REPORTING OFFICER INFORMATION

| Field | Value |
|-------|-------|
| Officer | John Martinez |
| Badge Number | 4521 |
| Email | j.martinez@springfield-pd.gov |

---

#### WITNESS STATEMENT

On March 12, 2024, I interviewed the witness at their residence located at **1847 Oak Street, Apartment 3B, Springfield, IL 62701**.

The witness provided the following personal information for follow-up contact:

| Field | Value | Detection Type |
|-------|-------|----------------|
| Name | Sarah Elizabeth Johnson | - |
| Date of Birth | 04/15/1985 | `dob` |
| Social Security Number | 123-45-6789 | `ssn` |
| Phone Number | (217) 555-0142 | `phone` |
| Alternate Phone | 217.555.0198 | `phone` |
| Email Address | sarah.johnson@email.com | `email` |

The witness stated they observed a white sedan with license plate **ABC-1234** leaving the parking lot at approximately 10:45 PM on the night in question.

---

#### SUSPECT INFORMATION

Based on witness statements and preliminary investigation:

| Field | Value | Detection Type |
|-------|-------|----------------|
| Name | Michael Robert Thompson | - |
| DOB | 11/22/1978 | `dob` |
| SSN | 987-65-4321 | `ssn` |
| Last Known Address | 2234 Maple Avenue, Unit 12, Springfield, IL 62704 | `address` |
| Contact Phone | (217) 555-7823 | `phone` |
| Email | m.thompson1978@fastmail.com | `email` |

**Vehicle registered to suspect:**
- Make/Model: 2019 Honda Accord, White
- License Plate: **XYZ-9876** (Detection Type: `plate`)

---

#### ADDITIONAL CONTACTS

**Victim's Emergency Contact:**

| Field | Value | Detection Type |
|-------|-------|----------------|
| Name | Robert Johnson | - |
| Relationship | Father | - |
| Phone | 217-555-3344 | `phone` |
| Address | 892 Pine Road, Springfield, IL 62702 | `address` |
| DOB | 07/03/1958 | `dob` |

**Insurance Information:**

| Field | Value | Detection Type |
|-------|-------|----------------|
| Policy Holder SSN | 456-78-9012 | `ssn` |
| Agent Email | claims@insureco.com | `email` |
| Agent Phone | (800) 555-1234 | `phone` |

---

#### NOTES

Follow-up interview scheduled for 03/18/2024.
Evidence photos taken - see attached files for facial images and vehicle plates.
All PII in this document should be redacted before public release per FOIA guidelines.

---

**Report prepared by:**
Officer J. Martinez
Badge #4521
j.martinez@springfield-pd.gov
Date: 03/14/2024

---

## Detection Types Summary

| Type | Description | Example Pattern |
|------|-------------|-----------------|
| `face` | Human faces in images | Detected via Vision framework |
| `plate` | Vehicle license plates | ABC-1234, XYZ-9876 |
| `ssn` | Social Security Numbers | 123-45-6789 |
| `phone` | Phone numbers | (217) 555-0142, 217.555.0198 |
| `email` | Email addresses | name@domain.com |
| `address` | Physical addresses | 1234 Street Name, City, ST 12345 |
| `dob` | Dates of birth | MM/DD/YYYY format |

---

<style>
  @media print {
    body { font-size: 11pt; }
    table { page-break-inside: avoid; }
    h2, h3, h4 { page-break-after: avoid; }
    img { max-width: 100%; height: auto; page-break-inside: avoid; }
  }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
  table { border-collapse: collapse; width: 100%; margin: 1em 0; }
  th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
  th { background-color: #f5f5f5; }
  code { background-color: #f0f0f0; padding: 2px 6px; border-radius: 3px; }
  img { max-width: 100%; border: 1px solid #ddd; border-radius: 4px; }
</style>
