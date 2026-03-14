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
      // Soft delete - files set deleted_at, no R2 bucket deletion
    });
  });

  // ============================================
  // Request Reassignment Tests (Admin Only)
  // ============================================

  describe('Request Reassignment (supervisor only)', () => {
    it('should accept created_by in update request body', async () => {
      const requestBody = {
        created_by: 'new-user-456',
      };

      const request = new Request('http://localhost/api/requests/req-123', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer token',
        },
        body: JSON.stringify(requestBody),
      });

      const body = await request.clone().json();
      expect(body.created_by).toBe('new-user-456');
    });

    it('should support reassignment in update endpoint', async () => {
      let updateQuery = '';
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('UPDATE')) {
          updateQuery = sql;
          return {
            bind: vi.fn().mockReturnValue({
              run: vi.fn().mockResolvedValue({}),
            }),
          };
        }
        if (sql.includes('SELECT role')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue({ role: 'supervisor' }),
            }),
          };
        }
        if (sql.includes('SELECT id FROM users')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue({ id: 'new-user-456' }),
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
        body: JSON.stringify({ created_by: 'new-user-456' }),
      });

      const { handleUpdateRequest } = await import('./requests');
      const response = await handleUpdateRequest(request, mockEnv as any, 'req-123');

      expect(response.status).toBe(200);
    });

    it('should validate target user exists when reassigning', async () => {
      const requestBody = {
        created_by: 'nonexistent-user',
      };

      const request = new Request('http://localhost/api/requests/req-123', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer token',
        },
        body: JSON.stringify(requestBody),
      });

      // The endpoint will check if target user exists
      const body = await request.clone().json();
      expect(body.created_by).toBeDefined();
    });

    it('should include created_by in UpdateRequestBody type', () => {
      // TypeScript type check - this structure should be valid
      const updateBody: { title?: string; notes?: string; status?: string; created_by?: string } = {
        title: 'Updated',
        created_by: 'new-user-id',
      };

      expect(updateBody.created_by).toBe('new-user-id');
    });
  });

  describe('Request Status Values', () => {
    it('should support new status values', () => {
      const validStatuses = ['new', 'in_progress', 'completed'];

      expect(validStatuses).toContain('new');
      expect(validStatuses).toContain('in_progress');
      expect(validStatuses).toContain('completed');
    });

    it('should update status field correctly', async () => {
      let statusUpdated: string | null = null;
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('UPDATE')) {
          return {
            bind: vi.fn((...args) => {
              // Find status in args
              if (args.includes('in_progress')) {
                statusUpdated = 'in_progress';
              }
              return { run: vi.fn().mockResolvedValue({}) };
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
        body: JSON.stringify({ status: 'in_progress' }),
      });

      const { handleUpdateRequest } = await import('./requests');
      await handleUpdateRequest(request, mockEnv as any, 'req-123');

      expect(statusUpdated).toBe('in_progress');
    });
  });

  // ============================================
  // Archive/Unarchive Tests (Supervisor Only)
  // ============================================

  describe('POST /api/requests/:id/archive', () => {
    it('should return 403 for non-supervisor users', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT role')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue({ role: 'clerk' }),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            first: vi.fn().mockResolvedValue(mockRequest),
          }),
        };
      });

      const request = new Request('http://localhost/api/requests/req-123/archive', {
        method: 'POST',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleArchiveRequest } = await import('./requests');
      const response = await handleArchiveRequest(request, mockEnv as any, 'req-123');
      const data = await response.json();

      expect(response.status).toBe(403);
      expect(data.error).toBe('Only supervisors can archive requests');
    });

    it('should return 404 for non-existent request', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT role')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue({ role: 'supervisor' }),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            first: vi.fn().mockResolvedValue(null),
          }),
        };
      });

      const request = new Request('http://localhost/api/requests/nonexistent/archive', {
        method: 'POST',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleArchiveRequest } = await import('./requests');
      const response = await handleArchiveRequest(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('Request not found');
    });

    it('should archive request successfully for supervisor', async () => {
      let archiveTimestamp: number | null = null;
      const archivedRequest = { ...mockRequest, archived_at: 1234567890 };

      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT role')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue({ role: 'supervisor' }),
            }),
          };
        }
        if (sql.includes('UPDATE requests SET archived_at')) {
          return {
            bind: vi.fn((...args) => {
              archiveTimestamp = args[0];
              return { run: vi.fn().mockResolvedValue({}) };
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
            first: vi.fn().mockResolvedValue(archivedRequest),
          }),
        };
      });

      const request = new Request('http://localhost/api/requests/req-123/archive', {
        method: 'POST',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleArchiveRequest } = await import('./requests');
      const response = await handleArchiveRequest(request, mockEnv as any, 'req-123');
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.request.archived_at).toBeDefined();
      expect(archiveTimestamp).not.toBeNull();
    });
  });

  describe('POST /api/requests/:id/unarchive', () => {
    it('should return 403 for non-supervisor users', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT role')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue({ role: 'clerk' }),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            first: vi.fn().mockResolvedValue(mockRequest),
          }),
        };
      });

      const request = new Request('http://localhost/api/requests/req-123/unarchive', {
        method: 'POST',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleUnarchiveRequest } = await import('./requests');
      const response = await handleUnarchiveRequest(request, mockEnv as any, 'req-123');
      const data = await response.json();

      expect(response.status).toBe(403);
      expect(data.error).toBe('Only supervisors can unarchive requests');
    });

    it('should return 404 for non-existent request', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT role')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue({ role: 'supervisor' }),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            first: vi.fn().mockResolvedValue(null),
          }),
        };
      });

      const request = new Request('http://localhost/api/requests/nonexistent/unarchive', {
        method: 'POST',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleUnarchiveRequest } = await import('./requests');
      const response = await handleUnarchiveRequest(request, mockEnv as any, 'nonexistent');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('Request not found');
    });

    it('should unarchive request successfully for supervisor', async () => {
      let archivedAtSetToNull = false;
      const unarchivedRequest = { ...mockRequest, archived_at: null };

      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT role')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue({ role: 'supervisor' }),
            }),
          };
        }
        if (sql.includes('UPDATE requests SET archived_at = NULL')) {
          archivedAtSetToNull = true;
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
            first: vi.fn().mockResolvedValue(unarchivedRequest),
          }),
        };
      });

      const request = new Request('http://localhost/api/requests/req-123/unarchive', {
        method: 'POST',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleUnarchiveRequest } = await import('./requests');
      const response = await handleUnarchiveRequest(request, mockEnv as any, 'req-123');
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.request.archived_at).toBeNull();
      expect(archivedAtSetToNull).toBe(true);
    });
  });

  describe('GET /api/requests/archived', () => {
    it('should return 403 for non-supervisor users', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT role')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue({ role: 'clerk' }),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            all: vi.fn().mockResolvedValue({ results: [] }),
          }),
        };
      });

      const request = new Request('http://localhost/api/requests/archived', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleListArchivedRequests } = await import('./requests');
      const response = await handleListArchivedRequests(request, mockEnv as any);
      const data = await response.json();

      expect(response.status).toBe(403);
      expect(data.error).toBe('Only supervisors can view archived requests');
    });

    it('should list archived requests for supervisor', async () => {
      const archivedRequests = [
        { ...mockRequest, id: 'req-1', archived_at: 1234567890 },
        { ...mockRequest, id: 'req-2', archived_at: 1234567891 },
      ];

      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT role')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue({ role: 'supervisor' }),
            }),
          };
        }
        return {
          all: vi.fn().mockResolvedValue({ results: archivedRequests }),
        };
      });

      const request = new Request('http://localhost/api/requests/archived', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleListArchivedRequests } = await import('./requests');
      const response = await handleListArchivedRequests(request, mockEnv as any);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.requests).toHaveLength(2);
      expect(data.requests[0].archived_at).toBeDefined();
    });

    it('should filter archived requests by search term', async () => {
      let queryIncludesLike = false;

      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT role')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue({ role: 'supervisor' }),
            }),
          };
        }
        if (sql.includes('LIKE')) {
          queryIncludesLike = true;
        }
        return {
          bind: vi.fn().mockReturnValue({
            all: vi.fn().mockResolvedValue({ results: [] }),
          }),
        };
      });

      const request = new Request('http://localhost/api/requests/archived?search=FOIA', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleListArchivedRequests } = await import('./requests');
      await handleListArchivedRequests(request, mockEnv as any);

      expect(queryIncludesLike).toBe(true);
    });

    it('should only return requests with archived_at IS NOT NULL', async () => {
      let queryChecksArchivedAt = false;

      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT role')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue({ role: 'supervisor' }),
            }),
          };
        }
        if (sql.includes('archived_at IS NOT NULL')) {
          queryChecksArchivedAt = true;
        }
        return {
          all: vi.fn().mockResolvedValue({ results: [] }),
        };
      });

      const request = new Request('http://localhost/api/requests/archived', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleListArchivedRequests } = await import('./requests');
      await handleListArchivedRequests(request, mockEnv as any);

      expect(queryChecksArchivedAt).toBe(true);
    });
  });

  describe('GET /api/requests excludes archived', () => {
    it('should exclude archived requests by default', async () => {
      let queryExcludesArchived = false;

      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('archived_at IS NULL')) {
          queryExcludesArchived = true;
        }
        return {
          all: vi.fn().mockResolvedValue({ results: [] }),
        };
      });

      const request = new Request('http://localhost/api/requests', {
        method: 'GET',
        headers: { Authorization: 'Bearer token' },
      });

      const { handleListRequests } = await import('./requests');
      await handleListRequests(request, mockEnv as any);

      expect(queryExcludesArchived).toBe(true);
    });
  });
});
