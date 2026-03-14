import { Env } from '../types';
import { json, error, generateId, now } from '../utils';

interface Agency {
  id: string;
  code: string;
  name: string;
  api_base_url: string;
  login_identifiers: string;
  primary_color: string | null;
  support_email: string | null;
  support_phone: string | null;
  created_at: number;
  updated_at: number;
}

interface AgencyResponse {
  code: string;
  name: string;
  apiBaseUrl: string;
  loginIdentifiers: string[];
  primaryColor: string | null;
  supportEmail: string | null;
  supportPhone: string | null;
}

function formatAgency(agency: Agency): AgencyResponse {
  return {
    code: agency.code,
    name: agency.name,
    apiBaseUrl: agency.api_base_url,
    loginIdentifiers: JSON.parse(agency.login_identifiers),
    primaryColor: agency.primary_color,
    supportEmail: agency.support_email,
    supportPhone: agency.support_phone,
  };
}

export async function handleGetAgencyByCode(request: Request, env: Env, code: string): Promise<Response> {
  const normalizedCode = code.toUpperCase();

  const agency = await env.DB.prepare('SELECT * FROM agencies WHERE code = ?')
    .bind(normalizedCode)
    .first<Agency>();

  if (!agency) {
    return error('Agency not found', 404);
  }

  return json({ agency: formatAgency(agency) });
}

export async function handleGetAgencyByDomain(request: Request, env: Env, domain: string): Promise<Response> {
  // Look up agency by support email domain
  const normalizedDomain = domain.toLowerCase();

  const agency = await env.DB.prepare(
    "SELECT * FROM agencies WHERE support_email LIKE '%' || ? OR code LIKE ?"
  )
    .bind(`@${normalizedDomain}`, `%${normalizedDomain.split('.')[0].toUpperCase()}%`)
    .first<Agency>();

  if (!agency) {
    return error('Agency not found for this domain', 404);
  }

  return json({ agency: formatAgency(agency) });
}

// Admin endpoint to create agencies
export async function handleCreateAgency(request: Request, env: Env): Promise<Response> {
  try {
    const body: {
      code: string;
      name: string;
      apiBaseUrl?: string;
      loginIdentifiers: string[];
      primaryColor?: string;
      supportEmail?: string;
      supportPhone?: string;
    } = await request.json();

    if (!body.code || !body.name || !body.loginIdentifiers) {
      return error('code, name, and loginIdentifiers are required');
    }

    const normalizedCode = body.code.toUpperCase();

    // Check if agency already exists
    const existing = await env.DB.prepare('SELECT id FROM agencies WHERE code = ?')
      .bind(normalizedCode)
      .first();

    if (existing) {
      return error('Agency with this code already exists');
    }

    const id = generateId();
    const timestamp = now();
    const apiBaseUrl = body.apiBaseUrl || 'https://redact-1-worker.joelstevick.workers.dev';

    await env.DB.prepare(
      `INSERT INTO agencies (id, code, name, api_base_url, login_identifiers, primary_color, support_email, support_phone, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
      .bind(
        id,
        normalizedCode,
        body.name,
        apiBaseUrl,
        JSON.stringify(body.loginIdentifiers),
        body.primaryColor || null,
        body.supportEmail || null,
        body.supportPhone || null,
        timestamp,
        timestamp
      )
      .run();

    return json({
      agency: {
        code: normalizedCode,
        name: body.name,
        apiBaseUrl,
        loginIdentifiers: body.loginIdentifiers,
        primaryColor: body.primaryColor || null,
        supportEmail: body.supportEmail || null,
        supportPhone: body.supportPhone || null,
      },
    }, 201);
  } catch (e) {
    return error('Invalid request body');
  }
}

export async function handleListAgencies(request: Request, env: Env): Promise<Response> {
  const result = await env.DB.prepare('SELECT * FROM agencies ORDER BY name')
    .all<Agency>();

  const agencies = result.results.map(formatAgency);

  return json({ agencies });
}
