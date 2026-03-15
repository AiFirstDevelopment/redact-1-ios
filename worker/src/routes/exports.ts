import { Env, Export, EvidenceFile, Detection, ManualRedaction, AuditLog } from '../types';
import { json, error, generateId, now } from '../utils';
import { authenticate, isAuthContext } from '../middleware/auth';

export async function handleListExports(request: Request, env: Env, requestId: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  // Verify request exists
  const req = await env.DB.prepare('SELECT id FROM requests WHERE id = ?')
    .bind(requestId)
    .first();

  if (!req) {
    return error('Request not found', 404);
  }

  const exports = await env.DB.prepare('SELECT * FROM exports WHERE request_id = ? ORDER BY created_at DESC')
    .bind(requestId)
    .all<Export>();

  return json({ exports: exports.results });
}

export async function handleCreateExport(request: Request, env: Env, requestId: string): Promise<Response> {
  try {
    const auth = await authenticate(request, env);
    if (!isAuthContext(auth)) return auth;

    // Verify request exists and get details
    const req = await env.DB.prepare('SELECT * FROM requests WHERE id = ?')
      .bind(requestId)
      .first<{ id: string; request_number: string; title: string }>();

    if (!req) {
      return error('Request not found', 404);
    }

    // Get all files for this request (exclude soft-deleted)
    const files = await env.DB.prepare('SELECT * FROM files WHERE request_id = ? AND deleted_at IS NULL')
      .bind(requestId)
      .all<EvidenceFile>();

    if (files.results.length === 0) {
      return error('No files to export');
    }

    const id = generateId();
    const timestamp = now();
    const filename = `${req.request_number}_redacted_${new Date(timestamp * 1000).toISOString().split('T')[0]}.zip`;
    const r2Key = `exports/${requestId}/${id}.zip`;

  // Generate audit report as JSON (iOS will create PDF)
  const auditLogs = await env.DB.prepare(
    'SELECT * FROM audit_logs WHERE entity_id = ? OR entity_id IN (SELECT id FROM files WHERE request_id = ?) ORDER BY created_at ASC'
  )
    .bind(requestId, requestId)
    .all<AuditLog>();

  // Get detection/redaction summaries for each file
  const fileSummaries = [];
  for (const file of files.results) {
    const detections = await env.DB.prepare('SELECT * FROM detections WHERE file_id = ?')
      .bind(file.id)
      .all<Detection>();

    const manualRedactions = await env.DB.prepare('SELECT * FROM manual_redactions WHERE file_id = ?')
      .bind(file.id)
      .all<ManualRedaction>();

    fileSummaries.push({
      filename: file.filename,
      file_type: file.file_type,
      detections: detections.results.length,
      manual_redactions: manualRedactions.results.length,
      detection_types: [...new Set(detections.results.map((d) => d.detection_type))],
    });
  }

  const auditReport = {
    request_number: req.request_number,
    title: req.title,
    exported_at: new Date(timestamp * 1000).toISOString(),
    exported_by: auth.user.name,
    file_count: files.results.length,
    files: fileSummaries,
    audit_trail: auditLogs.results.map((log) => ({
      action: log.action,
      entity_type: log.entity_type,
      timestamp: new Date(log.created_at * 1000).toISOString(),
      details: log.details ? JSON.parse(log.details) : null,
    })),
  };

  // Store audit report as JSON in R2
  const auditReportKey = `exports/${requestId}/${id}_audit.json`;
  await env.FILES_BUCKET.put(auditReportKey, JSON.stringify(auditReport, null, 2), {
    httpMetadata: { contentType: 'application/json' },
  });

  // Create export record (actual ZIP creation done client-side)
  await env.DB.prepare(
    'INSERT INTO exports (id, request_id, r2_key, filename, file_count, exported_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
  )
    .bind(id, requestId, r2Key, filename, files.results.length, auth.user.id, timestamp)
    .run();

  // Update request status to completed
  await env.DB.prepare("UPDATE requests SET status = 'completed', updated_at = ? WHERE id = ?")
    .bind(timestamp, requestId)
    .run();

  // Audit log
  await env.DB.prepare(
    'INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, details, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
  )
    .bind(generateId(), auth.user.id, 'export', 'request', requestId, JSON.stringify({ file_count: files.results.length }), timestamp)
    .run();

    return json({
      export: {
        id,
        request_id: requestId,
        filename,
        file_count: files.results.length,
        created_at: timestamp,
      },
      audit_report: auditReport,
      files: files.results.map((f) => ({
        id: f.id,
        filename: f.filename,
        file_type: f.file_type,
      })),
    }, 201);
  } catch (e) {
    console.error('handleCreateExport error:', e);
    return error('Failed to create export: ' + (e instanceof Error ? e.message : String(e)));
  }
}

export async function handleGetExport(request: Request, env: Env, id: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  const exp = await env.DB.prepare('SELECT * FROM exports WHERE id = ?')
    .bind(id)
    .first<Export>();

  if (!exp) {
    return error('Export not found', 404);
  }

  // Get the audit report
  const auditReportKey = `exports/${exp.request_id}/${id}_audit.json`;
  const auditObject = await env.FILES_BUCKET.get(auditReportKey);

  let auditReport = null;
  if (auditObject) {
    auditReport = JSON.parse(await auditObject.text());
  }

  return json({
    export: exp,
    audit_report: auditReport,
  });
}

export async function handleGetAuditLog(request: Request, env: Env, requestId: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  // Verify request exists
  const req = await env.DB.prepare('SELECT id FROM requests WHERE id = ?')
    .bind(requestId)
    .first();

  if (!req) {
    return error('Request not found', 404);
  }

  // Get all audit logs for this request and its files
  const logs = await env.DB.prepare(
    `SELECT al.*, u.name as user_name
     FROM audit_logs al
     LEFT JOIN users u ON al.user_id = u.id
     WHERE al.entity_id = ?
        OR al.entity_id IN (SELECT id FROM files WHERE request_id = ?)
        OR al.entity_id IN (SELECT id FROM detections WHERE file_id IN (SELECT id FROM files WHERE request_id = ?))
     ORDER BY al.created_at DESC`
  )
    .bind(requestId, requestId, requestId)
    .all();

  return json({ audit_logs: logs.results });
}

export async function handleGetFileAuditLog(request: Request, env: Env, fileId: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  // Verify file exists
  const file = await env.DB.prepare('SELECT id FROM files WHERE id = ?')
    .bind(fileId)
    .first();

  if (!file) {
    return error('File not found', 404);
  }

  const logs = await env.DB.prepare(
    `SELECT al.*, u.name as user_name
     FROM audit_logs al
     LEFT JOIN users u ON al.user_id = u.id
     WHERE al.entity_id = ?
        OR al.entity_id IN (SELECT id FROM detections WHERE file_id = ?)
        OR al.entity_id IN (SELECT id FROM manual_redactions WHERE file_id = ?)
     ORDER BY al.created_at DESC`
  )
    .bind(fileId, fileId, fileId)
    .all();

  return json({ audit_logs: logs.results });
}
