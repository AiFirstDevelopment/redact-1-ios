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
};

const mockDetection = {
  id: 'det-123',
  file_id: 'file-123',
  detection_type: 'face',
  bbox_x: 100,
  bbox_y: 100,
  bbox_width: 50,
  bbox_height: 50,
  page_number: null,
  text_start: null,
  text_end: null,
  text_content: null,
  confidence: 0.95,
  status: 'pending',
  reviewed_by: null,
  reviewed_at: null,
  created_at: 1234567890,
};

const mockManualRedaction = {
  id: 'mr-123',
  file_id: 'file-123',
  redaction_type: 'custom',
  bbox_x: 200,
  bbox_y: 200,
  bbox_width: 100,
  bbox_height: 100,
  page_number: null,
  created_by: 'user-123',
  created_at: 1234567890,
};

describe('Detections Routes', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('GET /api/files/:id/detections', () => {
    it('should return 404 for non-existent file', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/files/nonexistent/detections', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleListDetections } = await import('./detections');
      const response = await handleListDetections(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('File not found');
    });

    it('should list detections and manual redactions', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT id FROM files')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue({ id: 'file-123' }),
            }),
          };
        }
        if (sql.includes('FROM detections')) {
          return {
            bind: vi.fn().mockReturnValue({
              all: vi.fn().mockResolvedValue({ results: [mockDetection] }),
            }),
          };
        }
        if (sql.includes('FROM manual_redactions')) {
          return {
            bind: vi.fn().mockReturnValue({
              all: vi.fn().mockResolvedValue({ results: [mockManualRedaction] }),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            all: vi.fn().mockResolvedValue({ results: [] }),
          }),
        };
      });

      const request = new Request('http://localhost/api/files/file-123/detections', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleListDetections } = await import('./detections');
      const response = await handleListDetections(request, mockEnv as any, 'file-123');
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.detections).toHaveLength(1);
      expect(data.manual_redactions).toHaveLength(1);
    });
  });

  describe('POST /api/files/:id/detections', () => {
    it('should return 404 for non-existent file', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/files/nonexistent/detections', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer token',
        },
        body: JSON.stringify({ detections: [] }),
      });

      const { handleCreateDetections } = await import('./detections');
      const response = await handleCreateDetections(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('File not found');
    });

    it('should require detections array', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue({ id: 'file-123', request_id: 'req-123' }),
        }),
      });

      const request = new Request('http://localhost/api/files/file-123/detections', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer token',
        },
        body: JSON.stringify({}),
      });

      const { handleCreateDetections } = await import('./detections');
      const response = await handleCreateDetections(request, mockEnv as any, 'file-123');
      const data = await response.json();

      expect(response.status).toBe(400);
      expect(data.error).toBe('detections array is required');
    });

    it('should create detections successfully', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT id, request_id FROM files')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue({ id: 'file-123', request_id: 'req-123' }),
            }),
          };
        }
        if (sql.includes('INSERT INTO detections') || sql.includes('UPDATE') || sql.includes('INSERT INTO audit_logs')) {
          return {
            bind: vi.fn().mockReturnValue({
              run: vi.fn().mockResolvedValue({}),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            all: vi.fn().mockResolvedValue({ results: [mockDetection] }),
          }),
        };
      });

      const request = new Request('http://localhost/api/files/file-123/detections', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer token',
        },
        body: JSON.stringify({
          detections: [
            {
              detection_type: 'face',
              bbox_x: 100,
              bbox_y: 100,
              bbox_width: 50,
              bbox_height: 50,
              confidence: 0.95,
            },
          ],
        }),
      });

      const { handleCreateDetections } = await import('./detections');
      const response = await handleCreateDetections(request, mockEnv as any, 'file-123');

      expect(response.status).toBe(201);
    });
  });

  describe('PUT /api/detections/:id', () => {
    it('should return 404 for non-existent detection', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/detections/nonexistent', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer token',
        },
        body: JSON.stringify({ status: 'approved' }),
      });

      const { handleUpdateDetection } = await import('./detections');
      const response = await handleUpdateDetection(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('Detection not found');
    });

    it('should require valid status', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(mockDetection),
        }),
      });

      const request = new Request('http://localhost/api/detections/det-123', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer token',
        },
        body: JSON.stringify({ status: 'invalid' }),
      });

      const { handleUpdateDetection } = await import('./detections');
      const response = await handleUpdateDetection(request, mockEnv as any, 'det-123');
      const data = await response.json();

      expect(response.status).toBe(400);
      expect(data.error).toContain('status must be');
    });

    it('should update detection status', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('UPDATE') || sql.includes('INSERT INTO audit_logs')) {
          return {
            bind: vi.fn().mockReturnValue({
              run: vi.fn().mockResolvedValue({}),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            first: vi.fn().mockResolvedValue({ ...mockDetection, status: 'approved' }),
          }),
        };
      });

      const request = new Request('http://localhost/api/detections/det-123', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer token',
        },
        body: JSON.stringify({ status: 'approved' }),
      });

      const { handleUpdateDetection } = await import('./detections');
      const response = await handleUpdateDetection(request, mockEnv as any, 'det-123');
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.detection.status).toBe('approved');
    });
  });

  describe('POST /api/files/:id/manual-redactions', () => {
    it('should return 404 for non-existent file', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/files/nonexistent/manual-redactions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer token',
        },
        body: JSON.stringify({
          redaction_type: 'custom',
          bbox_x: 100,
          bbox_y: 100,
          bbox_width: 50,
          bbox_height: 50,
        }),
      });

      const { handleCreateManualRedaction } = await import('./detections');
      const response = await handleCreateManualRedaction(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('File not found');
    });

    it('should require all bbox fields', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue({ id: 'file-123' }),
        }),
      });

      const request = new Request('http://localhost/api/files/file-123/manual-redactions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer token',
        },
        body: JSON.stringify({
          redaction_type: 'custom',
          bbox_x: 100,
        }),
      });

      const { handleCreateManualRedaction } = await import('./detections');
      const response = await handleCreateManualRedaction(request, mockEnv as any, 'file-123');
      const data = await response.json();

      expect(response.status).toBe(400);
      expect(data.error).toContain('bbox');
    });

    it('should create manual redaction successfully', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT id FROM files')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue({ id: 'file-123' }),
            }),
          };
        }
        if (sql.includes('INSERT')) {
          return {
            bind: vi.fn().mockReturnValue({
              run: vi.fn().mockResolvedValue({}),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            first: vi.fn().mockResolvedValue(mockManualRedaction),
          }),
        };
      });

      const request = new Request('http://localhost/api/files/file-123/manual-redactions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer token',
        },
        body: JSON.stringify({
          redaction_type: 'custom',
          bbox_x: 200,
          bbox_y: 200,
          bbox_width: 100,
          bbox_height: 100,
        }),
      });

      const { handleCreateManualRedaction } = await import('./detections');
      const response = await handleCreateManualRedaction(request, mockEnv as any, 'file-123');

      expect(response.status).toBe(201);
    });
  });

  describe('DELETE /api/manual-redactions/:id', () => {
    it('should return 404 for non-existent redaction', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/manual-redactions/nonexistent', {
        method: 'DELETE',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleDeleteManualRedaction } = await import('./detections');
      const response = await handleDeleteManualRedaction(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('Manual redaction not found');
    });

    it('should delete manual redaction', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT * FROM manual_redactions')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue(mockManualRedaction),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            run: vi.fn().mockResolvedValue({}),
          }),
        };
      });

      const request = new Request('http://localhost/api/manual-redactions/mr-123', {
        method: 'DELETE',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleDeleteManualRedaction } = await import('./detections');
      const response = await handleDeleteManualRedaction(request, mockEnv as any, 'mr-123');
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.success).toBe(true);
    });
  });
});
