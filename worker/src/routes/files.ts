import { Env, EvidenceFile } from '../types';
import { json, error, generateId, now } from '../utils';
import { authenticate, isAuthContext } from '../middleware/auth';

export async function handleListFiles(request: Request, env: Env, requestId: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  // Verify request exists
  const req = await env.DB.prepare('SELECT id FROM requests WHERE id = ?')
    .bind(requestId)
    .first();

  if (!req) {
    return error('Request not found', 404);
  }

  const files = await env.DB.prepare('SELECT * FROM files WHERE request_id = ? ORDER BY created_at DESC')
    .bind(requestId)
    .all<EvidenceFile>();

  return json({ files: files.results });
}

export async function handleUploadFile(request: Request, env: Env, requestId: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  // Verify request exists
  const req = await env.DB.prepare('SELECT id FROM requests WHERE id = ?')
    .bind(requestId)
    .first();

  if (!req) {
    return error('Request not found', 404);
  }

  try {
    const formData = await request.formData();
    const file = formData.get('file') as File | null;

    if (!file) {
      return error('No file provided');
    }

    // Determine file type
    let fileType: 'image' | 'pdf';
    if (file.type.startsWith('image/')) {
      fileType = 'image';
    } else if (file.type === 'application/pdf') {
      fileType = 'pdf';
    } else {
      return error('Unsupported file type. Only images and PDFs are allowed.');
    }

    const id = generateId();
    const r2Key = `originals/${requestId}/${id}/${file.name}`;
    const timestamp = now();

    // Upload to R2
    await env.FILES_BUCKET.put(r2Key, await file.arrayBuffer(), {
      httpMetadata: {
        contentType: file.type,
      },
    });

    // Create database record
    await env.DB.prepare(
      `INSERT INTO files (id, request_id, filename, file_type, mime_type, file_size, original_r2_key, status, uploaded_by, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
      .bind(id, requestId, file.name, fileType, file.type, file.size, r2Key, 'uploaded', auth.user.id, timestamp, timestamp)
      .run();

    // Update request status if it's new
    await env.DB.prepare("UPDATE requests SET status = 'processing', updated_at = ? WHERE id = ? AND status = 'new'")
      .bind(timestamp, requestId)
      .run();

    // Audit log
    await env.DB.prepare(
      'INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, details, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
    )
      .bind(generateId(), auth.user.id, 'upload', 'file', id, JSON.stringify({ filename: file.name, size: file.size }), timestamp)
      .run();

    const newFile = await env.DB.prepare('SELECT * FROM files WHERE id = ?')
      .bind(id)
      .first<EvidenceFile>();

    return json({ file: newFile }, 201);
  } catch (e) {
    return error('Failed to upload file');
  }
}

export async function handleGetFile(request: Request, env: Env, id: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  const file = await env.DB.prepare('SELECT * FROM files WHERE id = ?')
    .bind(id)
    .first<EvidenceFile>();

  if (!file) {
    return error('File not found', 404);
  }

  return json({ file });
}

export async function handleDeleteFile(request: Request, env: Env, id: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  const file = await env.DB.prepare('SELECT * FROM files WHERE id = ?')
    .bind(id)
    .first<EvidenceFile>();

  if (!file) {
    return error('File not found', 404);
  }

  // Delete from R2
  await env.FILES_BUCKET.delete(file.original_r2_key);
  if (file.redacted_r2_key) {
    await env.FILES_BUCKET.delete(file.redacted_r2_key);
  }

  // Delete related records
  await env.DB.prepare('DELETE FROM manual_redactions WHERE file_id = ?').bind(id).run();
  await env.DB.prepare('DELETE FROM detections WHERE file_id = ?').bind(id).run();
  await env.DB.prepare('DELETE FROM files WHERE id = ?').bind(id).run();

  // Audit log
  await env.DB.prepare(
    'INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, details, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
  )
    .bind(generateId(), auth.user.id, 'delete', 'file', id, JSON.stringify({ filename: file.filename }), now())
    .run();

  return json({ success: true });
}

export async function handleGetOriginalUrl(request: Request, env: Env, id: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  const file = await env.DB.prepare('SELECT original_r2_key, mime_type FROM files WHERE id = ?')
    .bind(id)
    .first<{ original_r2_key: string; mime_type: string }>();

  if (!file) {
    return error('File not found', 404);
  }

  // Get the object and return its content
  const object = await env.FILES_BUCKET.get(file.original_r2_key);
  if (!object) {
    return error('File not found in storage', 404);
  }

  return new Response(object.body, {
    headers: {
      'Content-Type': file.mime_type,
      'Cache-Control': 'private, max-age=3600',
    },
  });
}

export async function handleGetRedactedUrl(request: Request, env: Env, id: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  const file = await env.DB.prepare('SELECT redacted_r2_key, mime_type FROM files WHERE id = ?')
    .bind(id)
    .first<{ redacted_r2_key: string | null; mime_type: string }>();

  if (!file) {
    return error('File not found', 404);
  }

  if (!file.redacted_r2_key) {
    return error('Redacted version not available', 404);
  }

  const object = await env.FILES_BUCKET.get(file.redacted_r2_key);
  if (!object) {
    return error('Redacted file not found in storage', 404);
  }

  return new Response(object.body, {
    headers: {
      'Content-Type': file.mime_type,
      'Cache-Control': 'private, max-age=3600',
    },
  });
}

export async function handleUploadRedacted(request: Request, env: Env, id: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  const file = await env.DB.prepare('SELECT * FROM files WHERE id = ?')
    .bind(id)
    .first<EvidenceFile>();

  if (!file) {
    return error('File not found', 404);
  }

  try {
    const formData = await request.formData();
    const redactedFile = formData.get('file') as File | null;

    if (!redactedFile) {
      return error('No file provided');
    }

    const r2Key = `redacted/${file.request_id}/${id}/${file.filename}`;
    const timestamp = now();

    // Upload to R2
    await env.FILES_BUCKET.put(r2Key, await redactedFile.arrayBuffer(), {
      httpMetadata: {
        contentType: file.mime_type,
      },
    });

    // Update database
    await env.DB.prepare("UPDATE files SET redacted_r2_key = ?, status = 'reviewed', updated_at = ? WHERE id = ?")
      .bind(r2Key, timestamp, id)
      .run();

    // Audit log
    await env.DB.prepare(
      'INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, created_at) VALUES (?, ?, ?, ?, ?, ?)'
    )
      .bind(generateId(), auth.user.id, 'upload_redacted', 'file', id, timestamp)
      .run();

    const updated = await env.DB.prepare('SELECT * FROM files WHERE id = ?')
      .bind(id)
      .first<EvidenceFile>();

    return json({ file: updated });
  } catch (e) {
    return error('Failed to upload redacted file');
  }
}
