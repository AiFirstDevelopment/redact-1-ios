import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock environment
const mockEnv = {
  DB: {
    prepare: vi.fn(),
  },
  JWT_SECRET: 'test-secret',
};

// Mock user data
const mockUser = {
  id: 'user-123',
  email: 'officer@pd.local',
  name: 'Officer Smith',
  password_hash: '$2a$10$hashedpassword',
  badge_number: '12345',
  employee_id: 'EMP-001',
  created_at: 1234567890,
  updated_at: 1234567890,
};

describe('Auth Routes', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('POST /api/auth/login', () => {
    it('should require identifier and password', async () => {
      const request = new Request('http://localhost/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      });

      // Import after mocks are set up
      const { handleLogin } = await import('./auth');
      const response = await handleLogin(request, mockEnv as any);
      const data = await response.json();

      expect(response.status).toBe(400);
      expect(data.error).toBe('Identifier and password are required');
    });

    it('should return 401 for invalid credentials', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const request = new Request('http://localhost/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'invalid@test.com', password: 'wrong' }),
      });

      const { handleLogin } = await import('./auth');
      const response = await handleLogin(request, mockEnv as any);

      expect(response.status).toBe(401);
    });

    it('should accept email identifier type', async () => {
      const request = new Request('http://localhost/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          identifier: 'officer@pd.local',
          password: 'test-password',
          identifierType: 'email',
        }),
      });

      // Verify the query uses email field
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const { handleLogin } = await import('./auth');
      await handleLogin(request, mockEnv as any);

      expect(mockEnv.DB.prepare).toHaveBeenCalledWith(
        expect.stringContaining('email')
      );
    });

    it('should accept badgeNumber identifier type', async () => {
      const request = new Request('http://localhost/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          identifier: '12345',
          password: 'test-password',
          identifierType: 'badgeNumber',
        }),
      });

      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const { handleLogin } = await import('./auth');
      await handleLogin(request, mockEnv as any);

      expect(mockEnv.DB.prepare).toHaveBeenCalledWith(
        expect.stringContaining('badge_number')
      );
    });

    it('should accept employeeId identifier type', async () => {
      const request = new Request('http://localhost/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          identifier: 'EMP-001',
          password: 'test-password',
          identifierType: 'employeeId',
        }),
      });

      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
        }),
      });

      const { handleLogin } = await import('./auth');
      await handleLogin(request, mockEnv as any);

      expect(mockEnv.DB.prepare).toHaveBeenCalledWith(
        expect.stringContaining('employee_id')
      );
    });
  });

  describe('POST /api/auth/logout', () => {
    it('should require authentication', async () => {
      const request = new Request('http://localhost/api/auth/logout', {
        method: 'POST',
      });

      const { handleLogout } = await import('./auth');
      const response = await handleLogout(request, mockEnv as any);

      expect(response.status).toBe(401);
    });
  });

  describe('GET /api/auth/me', () => {
    it('should require authentication', async () => {
      const request = new Request('http://localhost/api/auth/me', {
        method: 'GET',
      });

      const { handleMe } = await import('./auth');
      const response = await handleMe(request, mockEnv as any);

      expect(response.status).toBe(401);
    });
  });

  describe('POST /api/users', () => {
    it('should require email, password, and name', async () => {
      const request = new Request('http://localhost/api/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'test@test.com' }),
      });

      const { handleCreateUser } = await import('./auth');
      const response = await handleCreateUser(request, mockEnv as any);
      const data = await response.json();

      expect(response.status).toBe(400);
      expect(data.error).toBe('Email, password, and name are required');
    });

    it('should reject duplicate email', async () => {
      mockEnv.DB.prepare.mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue({ id: 'existing-user' }),
        }),
      });

      const request = new Request('http://localhost/api/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: 'existing@test.com',
          password: 'password',
          name: 'Test User',
        }),
      });

      const { handleCreateUser } = await import('./auth');
      const response = await handleCreateUser(request, mockEnv as any);
      const data = await response.json();

      expect(response.status).toBe(400);
      expect(data.error).toBe('User with this email already exists');
    });
  });
});
