// Environment bindings
export interface Env {
  DB: D1Database;
  FILES_BUCKET: R2Bucket;
  ENVIRONMENT: string;
  JWT_SECRET: string;
}

// Database models
export interface User {
  id: string;
  email: string;
  name: string;
  badge_number: string | null;
  role: 'officer' | 'admin';
  password_hash: string;
  created_at: number;
  updated_at: number;
}

export interface Request {
  id: string;
  request_number: string;
  title: string;
  request_date: number;
  notes: string | null;
  status: 'new' | 'processing' | 'review' | 'exported';
  created_by: string;
  created_at: number;
  updated_at: number;
}

export interface EvidenceFile {
  id: string;
  request_id: string;
  filename: string;
  file_type: 'image' | 'pdf';
  mime_type: string;
  file_size: number;
  original_r2_key: string;
  redacted_r2_key: string | null;
  status: 'uploaded' | 'processing' | 'detected' | 'reviewed' | 'exported';
  uploaded_by: string;
  created_at: number;
  updated_at: number;
}

export interface Detection {
  id: string;
  file_id: string;
  detection_type: 'face' | 'plate' | 'ssn' | 'phone' | 'email' | 'address' | 'dob';
  bbox_x: number | null;
  bbox_y: number | null;
  bbox_width: number | null;
  bbox_height: number | null;
  page_number: number | null;
  text_start: number | null;
  text_end: number | null;
  text_content: string | null;
  confidence: number | null;
  status: 'pending' | 'approved' | 'rejected';
  reviewed_by: string | null;
  reviewed_at: number | null;
  created_at: number;
}

export interface ManualRedaction {
  id: string;
  file_id: string;
  redaction_type: string;
  bbox_x: number | null;
  bbox_y: number | null;
  bbox_width: number | null;
  bbox_height: number | null;
  page_number: number | null;
  created_by: string;
  created_at: number;
}

export interface Export {
  id: string;
  request_id: string;
  r2_key: string;
  filename: string;
  file_count: number;
  exported_by: string;
  created_at: number;
}

export interface AuditLog {
  id: string;
  user_id: string | null;
  action: string;
  entity_type: string;
  entity_id: string;
  details: string | null;
  created_at: number;
}

// API request/response types
export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse {
  token: string;
  user: Omit<User, 'password_hash'>;
}

export interface CreateRequestBody {
  request_number: string;
  title: string;
  request_date: number;
  notes?: string;
}

export interface UpdateRequestBody {
  title?: string;
  notes?: string;
  status?: Request['status'];
  created_by?: string;
}

export interface CreateDetectionBody {
  detection_type: Detection['detection_type'];
  bbox_x?: number;
  bbox_y?: number;
  bbox_width?: number;
  bbox_height?: number;
  page_number?: number;
  text_start?: number;
  text_end?: number;
  text_content?: string;
  confidence?: number;
}

export interface UpdateDetectionBody {
  status: 'approved' | 'rejected';
}

export interface CreateManualRedactionBody {
  redaction_type: string;
  bbox_x: number;
  bbox_y: number;
  bbox_width: number;
  bbox_height: number;
  page_number?: number;
}

// JWT payload
export interface JWTPayload {
  sub: string; // user id
  email: string;
  name: string;
  iat: number;
  exp: number;
}

// Authenticated request context
export interface AuthContext {
  user: {
    id: string;
    email: string;
    name: string;
  };
}
