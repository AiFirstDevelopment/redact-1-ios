import { describe, it, expect, vi, beforeEach } from 'vitest';

const mockEnv = {
  DB: {
    prepare: vi.fn(),
  },
};

const mockAgency = {
  id: 'agency-123',
  code: 'DEMO',
  name: 'Demo Police Department',
  api_base_url: 'https://redact-1-worker.joelstevick.workers.dev',
  login_identifiers: '["email"]',
  primary_color: '#1a365d',
  support_email: 'support@demo-pd.local',
  support_phone: '555-123-4567',
  created_at: 1234567890,
  updated_at: 1234567890,
};

describe('Agencies Routes', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('GET /api/agencies/code/:code', () => {
    it('should return 404 for non-existent agency', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/agencies/code/INVALID', {
        method: 'GET',
      });

      const { handleGetAgencyByCode } = await import('./agencies');
      const response = await handleGetAgencyByCode(request, mockEnv as any, 'INVALID');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('Agency not found');
    });

    it('should return agency by code', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(mockAgency),
        }),
      });

      const request = new Request('http://localhost/api/agencies/code/DEMO', {
        method: 'GET',
      });

      const { handleGetAgencyByCode } = await import('./agencies');
      const response = await handleGetAgencyByCode(request, mockEnv as any, 'DEMO');
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.agency.code).toBe('DEMO');
      expect(data.agency.name).toBe('Demo Police Department');
      expect(data.agency.loginIdentifiers).toEqual(['email']);
    });

    it('should normalize code to uppercase', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(mockAgency),
        }),
      });

      const request = new Request('http://localhost/api/agencies/code/demo', {
        method: 'GET',
      });

      const { handleGetAgencyByCode } = await import('./agencies');
      await handleGetAgencyByCode(request, mockEnv as any, 'demo');

      expect(mockEnv.DB.prepare).toHaveBeenCalledWith('SELECT * FROM agencies WHERE code = ?');
    });
  });

  describe('GET /api/agencies/domain/:domain', () => {
    it('should return 404 for non-existent domain', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/agencies/domain/unknown.com', {
        method: 'GET',
      });

      const { handleGetAgencyByDomain } = await import('./agencies');
      const response = await handleGetAgencyByDomain(request, mockEnv as any, 'unknown.com');
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('Agency not found for this domain');
    });

    it('should find agency by domain', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(mockAgency),
        }),
      });

      const request = new Request('http://localhost/api/agencies/domain/demo-pd.local', {
        method: 'GET',
      });

      const { handleGetAgencyByDomain } = await import('./agencies');
      const response = await handleGetAgencyByDomain(request, mockEnv as any, 'demo-pd.local');
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.agency.code).toBe('DEMO');
    });
  });

  describe('POST /api/agencies', () => {
    it('should require code, name, and loginIdentifiers', async () => {
      const request = new Request('http://localhost/api/agencies', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code: 'TEST' }),
      });

      const { handleCreateAgency } = await import('./agencies');
      const response = await handleCreateAgency(request, mockEnv as any);
      const data = await response.json();

      expect(response.status).toBe(400);
      expect(data.error).toBe('code, name, and loginIdentifiers are required');
    });

    it('should reject duplicate agency code', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue({ id: 'existing' }),
        }),
      });

      const request = new Request('http://localhost/api/agencies', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          code: 'DEMO',
          name: 'Demo PD',
          loginIdentifiers: ['email'],
        }),
      });

      const { handleCreateAgency } = await import('./agencies');
      const response = await handleCreateAgency(request, mockEnv as any);
      const data = await response.json();

      expect(response.status).toBe(400);
      expect(data.error).toBe('Agency with this code already exists');
    });

    it('should create agency successfully', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT id FROM agencies')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue(null),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            run: vi.fn().mockResolvedValue({}),
          }),
        };
      });

      const request = new Request('http://localhost/api/agencies', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          code: 'NEW',
          name: 'New Police Department',
          loginIdentifiers: ['email'],
          primaryColor: '#000000',
        }),
      });

      const { handleCreateAgency } = await import('./agencies');
      const response = await handleCreateAgency(request, mockEnv as any);
      const data = await response.json();

      expect(response.status).toBe(201);
      expect(data.agency.code).toBe('NEW');
      expect(data.agency.name).toBe('New Police Department');
    });

    it('should use default API base URL', async () => {
      mockEnv.DB.prepare.mockImplementation((sql: string) => {
        if (sql.includes('SELECT id FROM agencies')) {
          return {
            bind: vi.fn().mockReturnValue({
              first: vi.fn().mockResolvedValue(null),
            }),
          };
        }
        return {
          bind: vi.fn().mockReturnValue({
            run: vi.fn().mockResolvedValue({}),
          }),
        };
      });

      const request = new Request('http://localhost/api/agencies', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          code: 'TEST',
          name: 'Test PD',
          loginIdentifiers: ['email'],
        }),
      });

      const { handleCreateAgency } = await import('./agencies');
      const response = await handleCreateAgency(request, mockEnv as any);
      const data = await response.json();

      expect(response.status).toBe(201);
      expect(data.agency.apiBaseUrl).toBe('https://redact-1-worker.joelstevick.workers.dev');
    });
  });

  describe('GET /api/agencies', () => {
    it('should list all agencies', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        all: vi.fn().mockResolvedValue({
          results: [mockAgency],
        }),
      });

      const request = new Request('http://localhost/api/agencies', {
        method: 'GET',
      });

      const { handleListAgencies } = await import('./agencies');
      const response = await handleListAgencies(request, mockEnv as any);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.agencies).toHaveLength(1);
      expect(data.agencies[0].code).toBe('DEMO');
    });

    it('should format agency response with camelCase fields', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        all: vi.fn().mockResolvedValue({
          results: [mockAgency],
        }),
      });

      const request = new Request('http://localhost/api/agencies', {
        method: 'GET',
      });

      const { handleListAgencies } = await import('./agencies');
      const response = await handleListAgencies(request, mockEnv as any);
      const data = await response.json();

      expect(data.agencies[0]).toHaveProperty('apiBaseUrl');
      expect(data.agencies[0]).toHaveProperty('loginIdentifiers');
      expect(data.agencies[0]).toHaveProperty('primaryColor');
      expect(data.agencies[0]).toHaveProperty('supportEmail');
      expect(data.agencies[0]).toHaveProperty('supportPhone');
    });
  });
});
