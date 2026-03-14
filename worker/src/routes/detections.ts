import { Env, Detection, ManualRedaction, CreateDetectionBody, UpdateDetectionBody, CreateManualRedactionBody } from '../types';
import { json, error, generateId, now } from '../utils';
import { authenticate, isAuthContext } from '../middleware/auth';

export async function handleListDetections(request: Request, env: Env, fileId: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  // Verify file exists
  const file = await env.DB.prepare('SELECT id FROM files WHERE id = ?')
    .bind(fileId)
    .first();

  if (!file) {
    return error('File not found', 404);
  }

  const detections = await env.DB.prepare('SELECT * FROM detections WHERE file_id = ? ORDER BY created_at ASC')
    .bind(fileId)
    .all<Detection>();

  const manualRedactions = await env.DB.prepare('SELECT * FROM manual_redactions WHERE file_id = ? ORDER BY created_at ASC')
    .bind(fileId)
    .all<ManualRedaction>();

  return json({
    detections: detections.results,
    manual_redactions: manualRedactions.results,
  });
}

export async function handleCreateDetections(request: Request, env: Env, fileId: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  // Verify file exists
  const file = await env.DB.prepare('SELECT id, request_id FROM files WHERE id = ?')
    .bind(fileId)
    .first<{ id: string; request_id: string }>();

  if (!file) {
    return error('File not found', 404);
  }

  try {
    const body: { detections: CreateDetectionBody[] } = await request.json();

    if (!body.detections || !Array.isArray(body.detections)) {
      return error('detections array is required');
    }

    const timestamp = now();
    const insertedIds: string[] = [];

    for (const detection of body.detections) {
      const id = generateId();
      insertedIds.push(id);

      await env.DB.prepare(
        `INSERT INTO detections (id, file_id, detection_type, bbox_x, bbox_y, bbox_width, bbox_height, page_number, text_start, text_end, text_content, confidence, status, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      )
        .bind(
          id,
          fileId,
          detection.detection_type,
          detection.bbox_x ?? null,
          detection.bbox_y ?? null,
          detection.bbox_width ?? null,
          detection.bbox_height ?? null,
          detection.page_number ?? null,
          detection.text_start ?? null,
          detection.text_end ?? null,
          detection.text_content ?? null,
          detection.confidence ?? null,
          'pending',
          timestamp
        )
        .run();
    }

    // Update file status
    await env.DB.prepare("UPDATE files SET status = 'detected', updated_at = ? WHERE id = ?")
      .bind(timestamp, fileId)
      .run();

    // Update request timestamp (status stays at in_progress until completed)
    await env.DB.prepare("UPDATE requests SET updated_at = ? WHERE id = ?")
      .bind(timestamp, file.request_id)
      .run();

    // Audit log
    await env.DB.prepare(
      'INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, details, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
    )
      .bind(generateId(), auth.user.id, 'detect', 'file', fileId, JSON.stringify({ count: body.detections.length }), timestamp)
      .run();

    const detections = await env.DB.prepare('SELECT * FROM detections WHERE file_id = ? ORDER BY created_at ASC')
      .bind(fileId)
      .all<Detection>();

    return json({ detections: detections.results }, 201);
  } catch (e) {
    return error('Invalid request body');
  }
}

export async function handleClearDetections(request: Request, env: Env, fileId: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  // Verify file exists
  const file = await env.DB.prepare('SELECT id FROM files WHERE id = ?')
    .bind(fileId)
    .first();

  if (!file) {
    return error('File not found', 404);
  }

  // Delete all detections for this file
  await env.DB.prepare('DELETE FROM detections WHERE file_id = ?')
    .bind(fileId)
    .run();

  // Audit log
  await env.DB.prepare(
    'INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, created_at) VALUES (?, ?, ?, ?, ?, ?)'
  )
    .bind(generateId(), auth.user.id, 'clear_detections', 'file', fileId, now())
    .run();

  return json({ success: true });
}

interface UpdateDetectionRequest {
  status?: 'approved' | 'rejected';
  bbox_x?: number;
  bbox_y?: number;
  bbox_width?: number;
  bbox_height?: number;
}

export async function handleUpdateDetection(request: Request, env: Env, id: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  const detection = await env.DB.prepare('SELECT * FROM detections WHERE id = ?')
    .bind(id)
    .first<Detection>();

  if (!detection) {
    return error('Detection not found', 404);
  }

  try {
    const body: UpdateDetectionRequest = await request.json();
    const timestamp = now();

    // Handle status update
    if (body.status) {
      if (!['approved', 'rejected'].includes(body.status)) {
        return error('status must be "approved" or "rejected"');
      }

      await env.DB.prepare('UPDATE detections SET status = ?, reviewed_by = ?, reviewed_at = ? WHERE id = ?')
        .bind(body.status, auth.user.id, timestamp, id)
        .run();

      // Audit log
      await env.DB.prepare(
        'INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, details, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
      )
        .bind(generateId(), auth.user.id, 'review_detection', 'detection', id, JSON.stringify({ status: body.status }), timestamp)
        .run();
    }

    // Handle bounding box update
    if (body.bbox_x !== undefined && body.bbox_y !== undefined &&
        body.bbox_width !== undefined && body.bbox_height !== undefined) {
      await env.DB.prepare('UPDATE detections SET bbox_x = ?, bbox_y = ?, bbox_width = ?, bbox_height = ? WHERE id = ?')
        .bind(body.bbox_x, body.bbox_y, body.bbox_width, body.bbox_height, id)
        .run();

      // Audit log
      await env.DB.prepare(
        'INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, details, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
      )
        .bind(generateId(), auth.user.id, 'move_detection', 'detection', id, JSON.stringify({ bbox_x: body.bbox_x, bbox_y: body.bbox_y, bbox_width: body.bbox_width, bbox_height: body.bbox_height }), timestamp)
        .run();
    }

    const updated = await env.DB.prepare('SELECT * FROM detections WHERE id = ?')
      .bind(id)
      .first<Detection>();

    return json({ detection: updated });
  } catch (e) {
    return error('Invalid request body');
  }
}

export async function handleCreateManualRedaction(request: Request, env: Env, fileId: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  // Verify file exists
  const file = await env.DB.prepare('SELECT id FROM files WHERE id = ?')
    .bind(fileId)
    .first();

  if (!file) {
    return error('File not found', 404);
  }

  try {
    const body: CreateManualRedactionBody = await request.json();

    if (!body.redaction_type || body.bbox_x === undefined || body.bbox_y === undefined ||
        body.bbox_width === undefined || body.bbox_height === undefined) {
      return error('redaction_type, bbox_x, bbox_y, bbox_width, and bbox_height are required');
    }

    const id = generateId();
    const timestamp = now();

    await env.DB.prepare(
      `INSERT INTO manual_redactions (id, file_id, redaction_type, bbox_x, bbox_y, bbox_width, bbox_height, page_number, created_by, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
      .bind(id, fileId, body.redaction_type, body.bbox_x, body.bbox_y, body.bbox_width, body.bbox_height, body.page_number ?? null, auth.user.id, timestamp)
      .run();

    // Audit log
    await env.DB.prepare(
      'INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, details, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
    )
      .bind(generateId(), auth.user.id, 'add_manual_redaction', 'manual_redaction', id, JSON.stringify(body), timestamp)
      .run();

    const redaction = await env.DB.prepare('SELECT * FROM manual_redactions WHERE id = ?')
      .bind(id)
      .first<ManualRedaction>();

    return json({ manual_redaction: redaction }, 201);
  } catch (e) {
    return error('Invalid request body');
  }
}

export async function handleUpdateManualRedaction(request: Request, env: Env, id: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  const redaction = await env.DB.prepare('SELECT * FROM manual_redactions WHERE id = ?')
    .bind(id)
    .first<ManualRedaction>();

  if (!redaction) {
    return error('Manual redaction not found', 404);
  }

  try {
    const body: { bbox_x?: number; bbox_y?: number; bbox_width?: number; bbox_height?: number } = await request.json();

    if (body.bbox_x !== undefined && body.bbox_y !== undefined &&
        body.bbox_width !== undefined && body.bbox_height !== undefined) {
      await env.DB.prepare('UPDATE manual_redactions SET bbox_x = ?, bbox_y = ?, bbox_width = ?, bbox_height = ? WHERE id = ?')
        .bind(body.bbox_x, body.bbox_y, body.bbox_width, body.bbox_height, id)
        .run();

      // Audit log
      await env.DB.prepare(
        'INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, details, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
      )
        .bind(generateId(), auth.user.id, 'move_manual_redaction', 'manual_redaction', id, JSON.stringify(body), now())
        .run();
    }

    const updated = await env.DB.prepare('SELECT * FROM manual_redactions WHERE id = ?')
      .bind(id)
      .first<ManualRedaction>();

    return json({ manual_redaction: updated });
  } catch (e) {
    return error('Invalid request body');
  }
}

export async function handleDeleteManualRedaction(request: Request, env: Env, id: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  const redaction = await env.DB.prepare('SELECT * FROM manual_redactions WHERE id = ?')
    .bind(id)
    .first<ManualRedaction>();

  if (!redaction) {
    return error('Manual redaction not found', 404);
  }

  await env.DB.prepare('DELETE FROM manual_redactions WHERE id = ?').bind(id).run();

  // Audit log
  await env.DB.prepare(
    'INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, created_at) VALUES (?, ?, ?, ?, ?, ?)'
  )
    .bind(generateId(), auth.user.id, 'delete_manual_redaction', 'manual_redaction', id, now())
    .run();

  return json({ success: true });
}
