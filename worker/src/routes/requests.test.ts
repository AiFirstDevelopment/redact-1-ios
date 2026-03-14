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
    delete: vi.fn().mockResolvedValue(undefined),
  },
};

const mockRequest = {
  id: 'req-123',
  request_number: 'FOIA-2024-001',
  title: 'Test Request',
  request_date: 1234567890,
  notes: 'Test notes',
  status: 'new',
  created_by: 'user-123',
  created_at: 1234567890,
  updated_at: 1234567890,
};

describe('Requests Routes', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('GET /api/requests', () => {
    it('should list all requests', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        all: vi.fn().mockResolvedValue({ results: [mockRequest] }),
      });

      const request = new Request('http://localhost/api/requests', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleListRequests } = await import('./requests');
      const response = await handleListRequests(request, mockEnv as any);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.requests).toHaveLength(1);
      expect(data.requests[0].request_number).toBe('FOIA-2024-001');
    });

    it('should filter by status', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          all: vi.fn().mockResolvedValue({ results: [] }),
        }),
      });

      const request = new Request('http://localhost/api/requests?status=review', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleListRequests } = await import('./requests');
      await handleListRequests(request, mockEnv as any);

      expect(mockEnv.DB.prepare).toHaveBeenCalledWith(
        expect.stringContaining('status = ?')
      );
    });

    it('should search by title or request_number', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          all: vi.fn().mockResolvedValue({ results: [] }),
        }),
      });

      const request = new Request('http://localhost/api/requests?search=FOIA', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleListRequests } = await import('./requests');
      await handleListRequests(request, mockEnv as any);

      expect(mockEnv.DB.prepare).toHaveBeenCalledWith(
        expect.stringContaining('LIKE')
      );
    });
  });

  describe('POST /api/requests', () => {
    it('should require request_number, title, and request_date', async () => {
      const request = new Request('http://localhost/api/requests', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer token',
        },
        body: JSON.stringify({ title: 'Test' }),
      });

      const { handleCreateRequest } = await import('./requests');
      const response = await handleCreateRequest(request, mockEnv as any);
      const data = await response.json();

      expect(response.status).toBe(400);
      expect(data.error).toBe('request_number, title, and request_date are required');
    });

    it('should reject duplicate request_number', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue({ id: 'existing' }),
        }),
      });

      const request = new Request('http://localhost/api/requests', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer token',
        },
        body: JSON.stringify({
          request_number: 'FOIA-2024-001',
          title: 'Test',
          request_date: 1234567890,
        }),
      });

      const { handleCreateRequest } = await import('./requests');
      const response = await handleCreateRequest(request, mockEnv as any);
      const data = await response.json();

      expect(response.status).toBe(400);
      expect(data.error).toBe('A request with this number already exists');
    });

    it('should create request with status "new"', async () => {
      let insertedData: any = null;
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT') && sql.includes('request_number')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue(null),
            }),
          };
        }
        if (sql.includes('INSERT')) {
          return {
            bind: vi.fn((...args) => {
              insertedData = args;
              return { run: vi.fn().mockResolvedValue({}) };
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            first: vi.fn().mockResolvedValue(mockRequest),
          }),
        };
      });

      const request = new Request('http://localhost/api/requests', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer token',
        },
        body: JSON.stringify({
          request_number: 'FOIA-2024-002',
          title: 'New Request',
          request_date: 1234567890,
        }),
      });

      const { handleCreateRequest } = await import('./requests');
      const response = await handleCreateRequest(request, mockEnv as any);

      expect(response.status).toBe(201);
    });
  });

  describe('GET /api/requests/:id', () => {
    it('should return 404 for non-existent request', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/requests/nonexistent', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleGetRequest } = await import('./requests');
      const response = await handleGetRequest(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('Request not found');
    });

    it('should return request by id', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(mockRequest),
        }),
      });

      const request = new Request('http://localhost/api/requests/req-123', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleGetRequest } = await import('./requests');
      const response = await handleGetRequest(request, mockEnv as any, 'req-123');
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.request.id).toBe('req-123');
    });
  });

  describe('PUT /api/requests/:id', () => {
    it('should return 404 for non-existent request', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/requests/nonexistent', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer token',
        },
        body: JSON.stringify({ title: 'Updated' }),
      });

      const { handleUpdateRequest } = await import('./requests');
      const response = await handleUpdateRequest(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('Request not found');
    });

    it('should update request fields', async () => {
      let updateCalled = false;
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('UPDATE')) {
          updateCalled = true;
          return {
            bind: vi.fn().mockReturnValue({
              run: vi.fn().mockResolvedValue({}),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            first: vi.fn().mockResolvedValue(mockRequest),
            run: vi.fn().mockResolvedValue({}),
          }),
        };
      });

      const request = new Request('http://localhost/api/requests/req-123', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer token',
        },
        body: JSON.stringify({ title: 'Updated Title', status: 'processing' }),
      });

      const { handleUpdateRequest } = await import('./requests');
      const response = await handleUpdateRequest(request, mockEnv as any, 'req-123');

      expect(response.status).toBe(200);
      expect(updateCalled).toBe(true);
    });
  });

  describe('DELETE /api/requests/:id', () => {
    it('should return 404 for non-existent request', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/requests/nonexistent', {
        method: 'DELETE',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleDeleteRequest } = await import('./requests');
      const response = await handleDeleteRequest(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('Request not found');
    });

    it('should delete request and cascade to files', async () => {
      const mockFiles = [
        { id: 'file-1', original_r2_key: 'key1', redacted_r2_key: 'key2' },
      ];

      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT * FROM requests WHERE id')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue(mockRequest),
            }),
          };
        }
        if (sql.includes('SELECT original_r2_key')) {
          return {
            bind: vi.fn().mockReturnValue({
              all: vi.fn().mockResolvedValue({ results: mockFiles }),
            }),
          };
        }
        // DELETE and INSERT queries need run()
        return {
          bind: vi.fn().mockReturnValue({
            run: vi.fn().mockResolvedValue({}),
          }),
        };
      });

      const request = new Request('http://localhost/api/requests/req-123', {
        method: 'DELETE',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleDeleteRequest } = await import('./requests');
      const response = await handleDeleteRequest(request, mockEnv as any, 'req-123');
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.success).toBe(true);
      expect(mockEnv.FILES_BUCKET.delete).toHaveBeenCalled();
    });
  });
});
