import { Env, AuthContext } from '../types';
import { verifyJWT, error } from '../utils';

export async function authenticate(
  request: Request,
  env: Env
): Promise<AuthContext | Response> {
  const authHeader = request.headers.get('Authorization');

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return error('Missing or invalid Authorization header', 401);
  }

  const token = authHeader.slice(7);
  const payload = await verifyJWT(token, env.JWT_SECRET);

  if (!payload) {
    return error('Invalid or expired token', 401);
  }

  return {
    user: {
      id: payload.sub,
      email: payload.email,
      name: payload.name,
    },
  };
}

export function isAuthContext(result: AuthContext | Response): result is AuthContext {
  return 'user' in result;
}
