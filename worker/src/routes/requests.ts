import { Env, Request as RequestModel, CreateRequestBody, UpdateRequestBody } from '../types';
import { json, error, generateId, now } from '../utils';
import { authenticate, isAuthContext } from '../middleware/auth';

export async function handleListRequests(request: Request, env: Env): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  const url = new URL(request.url);
  const status = url.searchParams.get('status');
  const search = url.searchParams.get('search');

  let query = 'SELECT * FROM requests';
  const params: string[] = [];
  const conditions: string[] = [];

  if (status) {
    conditions.push('status = ?');
    params.push(status);
  }

  if (search) {
    conditions.push('(title LIKE ? OR request_number LIKE ?)');
    params.push(`%${search}%`, `%${search}%`);
  }

  if (conditions.length > 0) {
    query += ' WHERE ' + conditions.join(' AND ');
  }

  query += ' ORDER BY created_at DESC';

  const stmt = env.DB.prepare(query);
  const result = await (params.length > 0 ? stmt.bind(...params) : stmt).all<RequestModel>();

  return json({ requests: result.results });
}

export async function handleGetRequest(request: Request, env: Env, id: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  const req = await env.DB.prepare('SELECT * FROM requests WHERE id = ?')
    .bind(id)
    .first<RequestModel>();

  if (!req) {
    return error('Request not found', 404);
  }

  return json({ request: req });
}

export async function handleCreateRequest(request: Request, env: Env): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  try {
    const body: CreateRequestBody = await request.json();

    if (!body.request_number || !body.title || !body.request_date) {
      return error('request_number, title, and request_date are required');
    }

    // Check for duplicate request number
    const existing = await env.DB.prepare('SELECT id FROM requests WHERE request_number = ?')
      .bind(body.request_number)
      .first();

    if (existing) {
      return error('A request with this number already exists');
    }

    const id = generateId();
    const timestamp = now();

    await env.DB.prepare(
      `INSERT INTO requests (id, request_number, title, request_date, notes, status, created_by, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
      .bind(
        id,
        body.request_number,
        body.title,
        body.request_date,
        body.notes || null,
        'new',
        auth.user.id,
        timestamp,
        timestamp
      )
      .run();

    // Audit log
    await env.DB.prepare(
      'INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, created_at) VALUES (?, ?, ?, ?, ?, ?)'
    )
      .bind(generateId(), auth.user.id, 'create', 'request', id, timestamp)
      .run();

    const newRequest = await env.DB.prepare('SELECT * FROM requests WHERE id = ?')
      .bind(id)
      .first<RequestModel>();

    return json({ request: newRequest }, 201);
  } catch (e) {
    return error('Invalid request body');
  }
}

export async function handleUpdateRequest(request: Request, env: Env, id: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  const existing = await env.DB.prepare('SELECT * FROM requests WHERE id = ?')
    .bind(id)
    .first<RequestModel>();

  if (!existing) {
    return error('Request not found', 404);
  }

  try {
    const body: UpdateRequestBody = await request.json();
    const timestamp = now();

    const updates: string[] = ['updated_at = ?'];
    const params: (string | number)[] = [timestamp];

    if (body.title !== undefined) {
      updates.push('title = ?');
      params.push(body.title);
    }

    if (body.notes !== undefined) {
      updates.push('notes = ?');
      params.push(body.notes);
    }

    if (body.status !== undefined) {
      updates.push('status = ?');
      params.push(body.status);
    }

    params.push(id);

    await env.DB.prepare(`UPDATE requests SET ${updates.join(', ')} WHERE id = ?`)
      .bind(...params)
      .run();

    // Audit log
    await env.DB.prepare(
      'INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, details, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
    )
      .bind(generateId(), auth.user.id, 'update', 'request', id, JSON.stringify(body), timestamp)
      .run();

    const updated = await env.DB.prepare('SELECT * FROM requests WHERE id = ?')
      .bind(id)
      .first<RequestModel>();

    return json({ request: updated });
  } catch (e) {
    return error('Invalid request body');
  }
}

export async function handleDeleteRequest(request: Request, env: Env, id: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  const existing = await env.DB.prepare('SELECT * FROM requests WHERE id = ?')
    .bind(id)
    .first<RequestModel>();

  if (!existing) {
    return error('Request not found', 404);
  }

  // Delete associated files from R2
  const files = await env.DB.prepare('SELECT original_r2_key, redacted_r2_key FROM files WHERE request_id = ?')
    .bind(id)
    .all<{ original_r2_key: string; redacted_r2_key: string | null }>();

  for (const file of files.results) {
    await env.FILES_BUCKET.delete(file.original_r2_key);
    if (file.redacted_r2_key) {
      await env.FILES_BUCKET.delete(file.redacted_r2_key);
    }
  }

  // Delete in order to respect foreign keys
  await env.DB.prepare('DELETE FROM manual_redactions WHERE file_id IN (SELECT id FROM files WHERE request_id = ?)')
    .bind(id)
    .run();
  await env.DB.prepare('DELETE FROM detections WHERE file_id IN (SELECT id FROM files WHERE request_id = ?)')
    .bind(id)
    .run();
  await env.DB.prepare('DELETE FROM files WHERE request_id = ?').bind(id).run();
  await env.DB.prepare('DELETE FROM exports WHERE request_id = ?').bind(id).run();
  await env.DB.prepare('DELETE FROM requests WHERE id = ?').bind(id).run();

  // Audit log
  await env.DB.prepare(
    'INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, created_at) VALUES (?, ?, ?, ?, ?, ?)'
  )
    .bind(generateId(), auth.user.id, 'delete', 'request', id, now())
    .run();

  return json({ success: true });
}
