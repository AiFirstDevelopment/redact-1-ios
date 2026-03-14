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
    delete: vi.fn().mockResolvedValue(undefined),
  },
};

const mockFile = {
  id: 'file-123',
  request_id: 'req-123',
  filename: 'test.pdf',
  file_type: 'pdf',
  mime_type: 'application/pdf',
  file_size: 1024,
  original_r2_key: 'originals/req-123/file-123/test.pdf',
  redacted_r2_key: null,
  status: 'uploaded',
  uploaded_by: 'user-123',
  created_at: 1234567890,
  updated_at: 1234567890,
};

describe('Files Routes', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('GET /api/requests/:id/files', () => {
    it('should return 404 for non-existent request', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/requests/nonexistent/files', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleListFiles } = await import('./files');
      const response = await handleListFiles(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('Request not found');
    });

    it('should list files for a request', async () => {
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
            all: vi.fn().mockResolvedValue({ results: [mockFile] }),
          }),
        };
      });

      const request = new Request('http://localhost/api/requests/req-123/files', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleListFiles } = await import('./files');
      const response = await handleListFiles(request, mockEnv as any, 'req-123');
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.files).toHaveLength(1);
      expect(data.files[0].filename).toBe('test.pdf');
    });
  });

  describe('POST /api/requests/:id/files', () => {
    it('should return 404 for non-existent request', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const formData = new FormData();
      formData.append('file', new Blob(['test'], { type: 'image/png' }), 'test.png');

      const request = new Request('http://localhost/api/requests/nonexistent/files', {
        method: 'POST',
        headers: { Authorization: 'Bearer token' },
        body: formData,
      });

      const { handleUploadFile } = await import('./files');
      const response = await handleUploadFile(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('Request not found');
    });

    it('should reject unsupported file types', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue({ id: 'req-123' }),
        }),
      });

      const formData = new FormData();
      formData.append('file', new Blob(['test'], { type: 'text/plain' }), 'test.txt');

      const request = new Request('http://localhost/api/requests/req-123/files', {
        method: 'POST',
        headers: { Authorization: 'Bearer token' },
        body: formData,
      });

      const { handleUploadFile } = await import('./files');
      const response = await handleUploadFile(request, mockEnv as any, 'req-123');
      const data = await response.json();

      expect(response.status).toBe(400);
      expect(data.error).toContain('Unsupported file type');
    });

    it('should upload image file successfully', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT id FROM requests')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue({ id: 'req-123' }),
            }),
          };
        }
        if (sql.includes('INSERT INTO files')) {
          return {
            bind: vi.fn().mockReturnValue({
              run: vi.fn().mockResolvedValue({}),
            }),
          };
        }
        if (sql.includes('UPDATE requests')) {
          return {
            bind: vi.fn().mockReturnValue({
              run: vi.fn().mockResolvedValue({}),
            }),
          };
        }
        if (sql.includes('INSERT INTO audit_logs')) {
          return {
            bind: vi.fn().mockReturnValue({
              run: vi.fn().mockResolvedValue({}),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            first: vi.fn().mockResolvedValue({ ...mockFile, file_type: 'image' }),
          }),
        };
      });

      const formData = new FormData();
      formData.append('file', new Blob(['test'], { type: 'image/png' }), 'test.png');

      const request = new Request('http://localhost/api/requests/req-123/files', {
        method: 'POST',
        headers: { Authorization: 'Bearer token' },
        body: formData,
      });

      const { handleUploadFile } = await import('./files');
      const response = await handleUploadFile(request, mockEnv as any, 'req-123');

      expect(response.status).toBe(201);
      expect(mockEnv.FILES_BUCKET.put).toHaveBeenCalled();
    });
  });

  describe('GET /api/files/:id', () => {
    it('should return 404 for non-existent file', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/files/nonexistent', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleGetFile } = await import('./files');
      const response = await handleGetFile(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('File not found');
    });

    it('should return file by id', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(mockFile),
        }),
      });

      const request = new Request('http://localhost/api/files/file-123', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleGetFile } = await import('./files');
      const response = await handleGetFile(request, mockEnv as any, 'file-123');
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.file.id).toBe('file-123');
    });
  });

  describe('DELETE /api/files/:id', () => {
    it('should return 404 for non-existent file', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/files/nonexistent', {
        method: 'DELETE',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleDeleteFile } = await import('./files');
      const response = await handleDeleteFile(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('File not found');
    });

    it('should delete file and related records', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT * FROM files')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue(mockFile),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            run: vi.fn().mockResolvedValue({}),
          }),
        };
      });

      const request = new Request('http://localhost/api/files/file-123', {
        method: 'DELETE',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleDeleteFile } = await import('./files');
      const response = await handleDeleteFile(request, mockEnv as any, 'file-123');
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.success).toBe(true);
      // Soft delete - no R2 bucket deletion, just sets deleted_at
    });
  });

  describe('GET /api/files/:id/original', () => {
    it('should return 404 for non-existent file', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/files/nonexistent/original', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleGetOriginalUrl } = await import('./files');
      const response = await handleGetOriginalUrl(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('File not found');
    });

    it('should return file content from R2', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue({
            original_r2_key: 'originals/test.pdf',
            mime_type: 'application/pdf',
          }),
        }),
      });

      mockEnv.FILES_BUCKET.get.mockResolvedValue({
        body: new ReadableStream(),
      });

      const request = new Request('http://localhost/api/files/file-123/original', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleGetOriginalUrl } = await import('./files');
      const response = await handleGetOriginalUrl(request, mockEnv as any, 'file-123');

      expect(response.status).toBe(200);
      expect(response.headers.get('Content-Type')).toBe('application/pdf');
    });
  });

  describe('GET /api/files/:id/redacted', () => {
    it('should return 404 if no redacted version', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue({
            redacted_r2_key: null,
            mime_type: 'application/pdf',
          }),
        }),
      });

      const request = new Request('http://localhost/api/files/file-123/redacted', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleGetRedactedUrl } = await import('./files');
      const response = await handleGetRedactedUrl(request, mockEnv as any, 'file-123');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('Redacted version not available');
    });
  });

  describe('POST /api/files/:id/redacted', () => {
    it('should return 404 for non-existent file', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const formData = new FormData();
      formData.append('file', new Blob(['test']), 'redacted.pdf');

      const request = new Request('http://localhost/api/files/nonexistent/redacted', {
        method: 'POST',
        headers: { Authorization: 'Bearer token' },
        body: formData,
      });

      const { handleUploadRedacted } = await import('./files');
      const response = await handleUploadRedacted(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('File not found');
    });

    it('should upload redacted file successfully', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT * FROM files')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue(mockFile),
            }),
          };
        }
        if (sql.includes('UPDATE files')) {
          return {
            bind: vi.fn().mockReturnValue({
              run: vi.fn().mockResolvedValue({}),
            }),
          };
        }
        if (sql.includes('INSERT INTO audit_logs')) {
          return {
            bind: vi.fn().mockReturnValue({
              run: vi.fn().mockResolvedValue({}),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            first: vi.fn().mockResolvedValue({
              ...mockFile,
              redacted_r2_key: 'redacted/test.pdf',
              status: 'reviewed',
            }),
          }),
        };
      });

      const formData = new FormData();
      formData.append('file', new Blob(['test']), 'redacted.pdf');

      const request = new Request('http://localhost/api/files/file-123/redacted', {
        method: 'POST',
        headers: { Authorization: 'Bearer token' },
        body: formData,
      });

      const { handleUploadRedacted } = await import('./files');
      const response = await handleUploadRedacted(request, mockEnv as any, 'file-123');

      expect(response.status).toBe(200);
      expect(mockEnv.FILES_BUCKET.put).toHaveBeenCalled();
    });
  });
});
