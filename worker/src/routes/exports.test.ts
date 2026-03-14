import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock authentication middleware
vi.mock('../middleware/auth', () => ({
  authenticate: vi.fn().mockResolvedValue({
    user: { id: 'user-123', email: 'test@test.com', name: 'Test User' },
  }),
  isAuthContext: vi.fn().mockReturnValue(true),
}));

const mockEnv = {
  DB: {
    prepare: vi.fn(),
  },
  FILES_BUCKET: {
    put: vi.fn().mockResolvedValue(undefined),
    get: vi.fn(),
  },
};

const mockExport = {
  id: 'exp-123',
  request_id: 'req-123',
  r2_key: 'exports/req-123/exp-123.zip',
  filename: 'FOIA-2024-001_redacted_2024-01-15.zip',
  file_count: 2,
  exported_by: 'user-123',
  created_at: 1234567890,
};

const mockFile = {
  id: 'file-123',
  request_id: 'req-123',
  filename: 'test.pdf',
  file_type: 'pdf',
  mime_type: 'application/pdf',
  status: 'reviewed',
};

const mockRequest = {
  id: 'req-123',
  request_number: 'FOIA-2024-001',
  title: 'Test Request',
};

describe('Exports Routes', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('GET /api/requests/:id/exports', () => {
    it('should return 404 for non-existent request', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/requests/nonexistent/exports', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleListExports } = await import('./exports');
      const response = await handleListExports(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('Request not found');
    });

    it('should list exports for a request', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT id FROM requests')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue({ id: 'req-123' }),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            all: vi.fn().mockResolvedValue({ results: [mockExport] }),
          }),
        };
      });

      const request = new Request('http://localhost/api/requests/req-123/exports', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleListExports } = await import('./exports');
      const response = await handleListExports(request, mockEnv as any, 'req-123');
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.exports).toHaveLength(1);
      expect(data.exports[0].filename).toContain('FOIA-2024-001');
    });
  });

  describe('POST /api/requests/:id/export', () => {
    it('should return 404 for non-existent request', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/requests/nonexistent/export', {
        method: 'POST',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleCreateExport } = await import('./exports');
      const response = await handleCreateExport(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('Request not found');
    });

    it('should require reviewed files', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT * FROM requests')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue(mockRequest),
            }),
          };
        }
        if (sql.includes('SELECT * FROM files')) {
          return {
            bind: vi.fn().mockReturnValue({
              all: vi.fn().mockResolvedValue({ results: [] }),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            first: vi.fn().mockResolvedValue(null),
          }),
        };
      });

      const request = new Request('http://localhost/api/requests/req-123/export', {
        method: 'POST',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleCreateExport } = await import('./exports');
      const response = await handleCreateExport(request, mockEnv as any, 'req-123');
      const data = await response.json();

      expect(response.status).toBe(400);
      expect(data.error).toBe('No reviewed files to export');
    });

    it('should create export successfully', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT * FROM requests WHERE id')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue(mockRequest),
            }),
          };
        }
        if (sql.includes("SELECT * FROM files WHERE request_id = ? AND status = 'reviewed'")) {
          return {
            bind: vi.fn().mockReturnValue({
              all: vi.fn().mockResolvedValue({ results: [mockFile] }),
            }),
          };
        }
        if (sql.includes('SELECT * FROM audit_logs')) {
          return {
            bind: vi.fn().mockReturnValue({
              all: vi.fn().mockResolvedValue({ results: [] }),
            }),
          };
        }
        if (sql.includes("SELECT * FROM detections WHERE file_id = ? AND status = 'approved'")) {
          return {
            bind: vi.fn().mockReturnValue({
              all: vi.fn().mockResolvedValue({ results: [] }),
            }),
          };
        }
        if (sql.includes('SELECT * FROM manual_redactions')) {
          return {
            bind: vi.fn().mockReturnValue({
              all: vi.fn().mockResolvedValue({ results: [] }),
            }),
          };
        }
        if (sql.includes('INSERT') || sql.includes('UPDATE')) {
          return {
            bind: vi.fn().mockReturnValue({
              run: vi.fn().mockResolvedValue({}),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            all: vi.fn().mockResolvedValue({ results: [] }),
          }),
        };
      });

      const request = new Request('http://localhost/api/requests/req-123/export', {
        method: 'POST',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleCreateExport } = await import('./exports');
      const response = await handleCreateExport(request, mockEnv as any, 'req-123');

      expect(response.status).toBe(201);
      expect(mockEnv.FILES_BUCKET.put).toHaveBeenCalled();
    });
  });

  describe('GET /api/exports/:id', () => {
    it('should return 404 for non-existent export', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/exports/nonexistent', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleGetExport } = await import('./exports');
      const response = await handleGetExport(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('Export not found');
    });

    it('should return export with audit report', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(mockExport),
        }),
      });

      mockEnv.FILES_BUCKET.get.mockResolvedValue({
        text: vi.fn().mockResolvedValue(JSON.stringify({ request_number: 'FOIA-2024-001' })),
      });

      const request = new Request('http://localhost/api/exports/exp-123', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleGetExport } = await import('./exports');
      const response = await handleGetExport(request, mockEnv as any, 'exp-123');
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.export.id).toBe('exp-123');
      expect(data.audit_report).toBeDefined();
    });
  });

  describe('GET /api/requests/:id/audit-log', () => {
    it('should return 404 for non-existent request', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/requests/nonexistent/audit-log', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleGetAuditLog } = await import('./exports');
      const response = await handleGetAuditLog(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('Request not found');
    });

    it('should return audit logs for request', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT id FROM requests')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue({ id: 'req-123' }),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            all: vi.fn().mockResolvedValue({
              results: [
                {
                  id: 'log-1',
                  user_id: 'user-123',
                  user_name: 'Test User',
                  action: 'upload',
                  entity_type: 'file',
                  entity_id: 'file-123',
                  created_at: 1234567890,
                },
              ],
            }),
          }),
        };
      });

      const request = new Request('http://localhost/api/requests/req-123/audit-log', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleGetAuditLog } = await import('./exports');
      const response = await handleGetAuditLog(request, mockEnv as any, 'req-123');
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.audit_logs).toHaveLength(1);
    });
  });

  describe('GET /api/files/:id/audit-log', () => {
    it('should return 404 for non-existent file', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/files/nonexistent/audit-log', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleGetFileAuditLog } = await import('./exports');
      const response = await handleGetFileAuditLog(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('File not found');
    });

    it('should return audit logs for file', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT id FROM files')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue({ id: 'file-123' }),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            all: vi.fn().mockResolvedValue({
              results: [
                {
                  id: 'log-1',
                  user_id: 'user-123',
                  user_name: 'Test User',
                  action: 'detect',
                  entity_type: 'file',
                  entity_id: 'file-123',
                  created_at: 1234567890,
                },
              ],
            }),
          }),
        };
      });

      const request = new Request('http://localhost/api/files/file-123/audit-log', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleGetFileAuditLog } = await import('./exports');
      const response = await handleGetFileAuditLog(request, mockEnv as any, 'file-123');
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.audit_logs).toHaveLength(1);
    });
  });
});
