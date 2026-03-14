import { Env, LoginRequest, User } from '../types';
import { verifyPassword, createJWT, json, error, generateId, hashPassword, now } from '../utils';
import { authenticate, isAuthContext } from '../middleware/auth';

export async function handleLogin(request: Request, env: Env): Promise<Response> {
  try {
    const body: LoginRequest & { identifier?: string; identifierType?: string } = await request.json();

    // Support both email field and identifier field
    const identifier = body.identifier || body.email;
    const identifierType = body.identifierType || 'email';

    if (!identifier || !body.password) {
      return error('Identifier and password are required');
    }

    let user: User | null = null;

    if (identifierType === 'badgeNumber') {
      user = await env.DB.prepare('SELECT * FROM users WHERE badge_number = ?')
        .bind(identifier)
        .first<User>();
    } else if (identifierType === 'employeeId') {
      user = await env.DB.prepare('SELECT * FROM users WHERE employee_id = ?')
        .bind(identifier)
        .first<User>();
    } else {
      // Default to email
      user = await env.DB.prepare('SELECT * FROM users WHERE email = ?')
        .bind(identifier)
        .first<User>();
    }

    if (!user) {
      return error('Invalid credentials', 401);
    }

    const valid = await verifyPassword(body.password, user.password_hash);
    if (!valid) {
      return error('Invalid credentials', 401);
    }

    const token = await createJWT(
      { sub: user.id, email: user.email, name: user.name },
      env.JWT_SECRET
    );

    // Log the login
    await env.DB.prepare(
      'INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, created_at) VALUES (?, ?, ?, ?, ?, ?)'
    )
      .bind(generateId(), user.id, 'login', 'user', user.id, now())
      .run();

    return json({
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        badge_number: user.badge_number,
        role: user.role || 'officer',
        created_at: user.created_at,
        updated_at: user.updated_at,
      },
    });
  } catch (e) {
    return error('Invalid request body');
  }
}

// Helper to check if user is admin
async function isAdmin(userId: string, env: Env): Promise<boolean> {
  const user = await env.DB.prepare('SELECT role FROM users WHERE id = ?')
    .bind(userId)
    .first<{ role: string }>();
  return user?.role === 'admin';
}

export async function handleLogout(request: Request, env: Env): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  // Log the logout
  await env.DB.prepare(
    'INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, created_at) VALUES (?, ?, ?, ?, ?, ?)'
  )
    .bind(generateId(), auth.user.id, 'logout', 'user', auth.user.id, now())
    .run();

  return json({ success: true });
}

export async function handleMe(request: Request, env: Env): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  const user = await env.DB.prepare('SELECT id, email, name, badge_number, role, created_at, updated_at FROM users WHERE id = ?')
    .bind(auth.user.id)
    .first();

  if (!user) {
    return error('User not found', 404);
  }

  return json({ user });
}

// List all users (requires admin)
export async function handleListUsers(request: Request, env: Env): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  if (!await isAdmin(auth.user.id, env)) {
    return error('Admin access required', 403);
  }

  const users = await env.DB.prepare(
    'SELECT id, email, name, badge_number, role, created_at, updated_at FROM users ORDER BY name ASC'
  ).all();

  return json({ users: users.results || [] });
}

// Create user (requires admin)
export async function handleCreateUser(request: Request, env: Env): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  if (!await isAdmin(auth.user.id, env)) {
    return error('Admin access required', 403);
  }

  try {
    const body: { email: string; password: string; name: string; badge_number?: string; role?: string } = await request.json();

    if (!body.email || !body.password || !body.name) {
      return error('Email, password, and name are required');
    }

    // Validate role
    const role = body.role === 'admin' ? 'admin' : 'officer';

    // Check if user already exists
    const existing = await env.DB.prepare('SELECT id FROM users WHERE email = ?')
      .bind(body.email)
      .first();

    if (existing) {
      return error('User with this email already exists');
    }

    const id = generateId();
    const passwordHash = await hashPassword(body.password);
    const timestamp = now();

    await env.DB.prepare(
      'INSERT INTO users (id, email, name, badge_number, role, password_hash, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    )
      .bind(id, body.email, body.name, body.badge_number || null, role, passwordHash, timestamp, timestamp)
      .run();

    // Log the user creation
    await env.DB.prepare(
      'INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, created_at) VALUES (?, ?, ?, ?, ?, ?)'
    )
      .bind(generateId(), auth.user.id, 'create_user', 'user', id, timestamp)
      .run();

    return json({
      user: {
        id,
        email: body.email,
        name: body.name,
        badge_number: body.badge_number || null,
        role,
        created_at: timestamp,
        updated_at: timestamp,
      },
    }, 201);
  } catch (e) {
    return error('Invalid request body');
  }
}

// Get single user (requires authentication)
export async function handleGetUser(request: Request, env: Env, userId: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  const user = await env.DB.prepare(
    'SELECT id, email, name, badge_number, role, created_at, updated_at FROM users WHERE id = ?'
  )
    .bind(userId)
    .first();

  if (!user) {
    return error('User not found', 404);
  }

  return json({ user });
}

// Update user (requires self or admin)
export async function handleUpdateUser(request: Request, env: Env, userId: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  const isSelf = auth.user.id === userId;
  const admin = await isAdmin(auth.user.id, env);

  if (!isSelf && !admin) {
    return error('You can only edit your own profile', 403);
  }

  try {
    const body: { name?: string; email?: string; password?: string; role?: string } = await request.json();

    const existing = await env.DB.prepare('SELECT * FROM users WHERE id = ?')
      .bind(userId)
      .first<User>();

    if (!existing) {
      return error('User not found', 404);
    }

    // Check if new email conflicts with another user
    if (body.email && body.email !== existing.email) {
      const emailConflict = await env.DB.prepare('SELECT id FROM users WHERE email = ? AND id != ?')
        .bind(body.email, userId)
        .first();
      if (emailConflict) {
        return error('Email already in use by another user');
      }
    }

    const timestamp = now();
    const newName = body.name || existing.name;
    const newEmail = body.email || existing.email;
    const newPasswordHash = body.password ? await hashPassword(body.password) : existing.password_hash;
    // Only admin can change roles
    const newRole = (admin && body.role) ? (body.role === 'admin' ? 'admin' : 'officer') : existing.role;

    await env.DB.prepare(
      'UPDATE users SET name = ?, email = ?, password_hash = ?, role = ?, updated_at = ? WHERE id = ?'
    )
      .bind(newName, newEmail, newPasswordHash, newRole, timestamp, userId)
      .run();

    // Log the update
    await env.DB.prepare(
      'INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, created_at) VALUES (?, ?, ?, ?, ?, ?)'
    )
      .bind(generateId(), auth.user.id, 'update_user', 'user', userId, timestamp)
      .run();

    return json({
      user: {
        id: userId,
        email: newEmail,
        name: newName,
        badge_number: existing.badge_number,
        role: newRole,
        created_at: existing.created_at,
        updated_at: timestamp,
      },
    });
  } catch (e) {
    return error('Invalid request body');
  }
}

// Delete user (requires admin)
export async function handleDeleteUser(request: Request, env: Env, userId: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  if (!await isAdmin(auth.user.id, env)) {
    return error('Admin access required', 403);
  }

  // Prevent self-deletion
  if (auth.user.id === userId) {
    return error('Cannot delete your own account');
  }

  const existing = await env.DB.prepare('SELECT id FROM users WHERE id = ?')
    .bind(userId)
    .first();

  if (!existing) {
    return error('User not found', 404);
  }

  await env.DB.prepare('DELETE FROM users WHERE id = ?')
    .bind(userId)
    .run();

  // Log the deletion
  await env.DB.prepare(
    'INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, created_at) VALUES (?, ?, ?, ?, ?, ?)'
  )
    .bind(generateId(), auth.user.id, 'delete_user', 'user', userId, now())
    .run();

  return json({ success: true });
}

// Get user's audit log (requires authentication)
export async function handleGetUserAudit(request: Request, env: Env, userId: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  const existing = await env.DB.prepare('SELECT id FROM users WHERE id = ?')
    .bind(userId)
    .first();

  if (!existing) {
    return error('User not found', 404);
  }

  const logs = await env.DB.prepare(
    `SELECT id, action, entity_type, entity_id, details, created_at
     FROM audit_logs
     WHERE user_id = ?
     ORDER BY created_at DESC
     LIMIT 100`
  )
    .bind(userId)
    .all();

  return json({ audit_logs: logs.results || [] });
}

// Get user's requests (requires authentication)
export async function handleGetUserRequests(request: Request, env: Env, userId: string): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!isAuthContext(auth)) return auth;

  const existing = await env.DB.prepare('SELECT id FROM users WHERE id = ?')
    .bind(userId)
    .first();

  if (!existing) {
    return error('User not found', 404);
  }

  const requests = await env.DB.prepare(
    `SELECT id, request_number, title, request_date, notes, status, created_by, created_at, updated_at
     FROM requests
     WHERE created_by = ?
     ORDER BY updated_at DESC`
  )
    .bind(userId)
    .all();

  return json({ requests: requests.results || [] });
}
