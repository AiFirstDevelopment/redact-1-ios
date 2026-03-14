import { Env } from './types';
import { error, json } from './utils';
import { handleLogin, handleLogout, handleMe, handleCreateUser, handleListUsers, handleGetUser, handleUpdateUser, handleDeleteUser, handleGetUserAudit } from './routes/auth';
import {
  handleListRequests,
  handleGetRequest,
  handleCreateRequest,
  handleUpdateRequest,
  handleDeleteRequest,
} from './routes/requests';
import {
  handleListFiles,
  handleUploadFile,
  handleGetFile,
  handleDeleteFile,
  handleGetOriginalUrl,
  handleGetRedactedUrl,
  handleUploadRedacted,
} from './routes/files';
import {
  handleListDetections,
  handleCreateDetections,
  handleUpdateDetection,
  handleCreateManualRedaction,
  handleDeleteManualRedaction,
} from './routes/detections';
import {
  handleListExports,
  handleCreateExport,
  handleGetExport,
  handleGetAuditLog,
  handleGetFileAuditLog,
} from './routes/exports';
import {
  handleGetAgencyByCode,
  handleGetAgencyByDomain,
  handleCreateAgency,
  handleListAgencies,
} from './routes/agencies';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    // Handle preflight
    if (method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Wrap response with CORS headers
    const addCors = (response: Response): Response => {
      const newHeaders = new Headers(response.headers);
      Object.entries(corsHeaders).forEach(([key, value]) => {
        newHeaders.set(key, value);
      });
      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: newHeaders,
      });
    };

    try {
      let response: Response;

      // Auth routes
      if (path === '/api/auth/login' && method === 'POST') {
        response = await handleLogin(request, env);
      } else if (path === '/api/auth/logout' && method === 'POST') {
        response = await handleLogout(request, env);
      } else if (path === '/api/auth/me' && method === 'GET') {
        response = await handleMe(request, env);
      }
      // User routes
      else if (path === '/api/users' && method === 'GET') {
        response = await handleListUsers(request, env);
      } else if (path === '/api/users' && method === 'POST') {
        response = await handleCreateUser(request, env);
      } else if (path.match(/^\/api\/users\/[^/]+$/) && method === 'GET') {
        const id = path.split('/')[3];
        response = await handleGetUser(request, env, id);
      } else if (path.match(/^\/api\/users\/[^/]+$/) && method === 'PUT') {
        const id = path.split('/')[3];
        response = await handleUpdateUser(request, env, id);
      } else if (path.match(/^\/api\/users\/[^/]+$/) && method === 'DELETE') {
        const id = path.split('/')[3];
        response = await handleDeleteUser(request, env, id);
      } else if (path.match(/^\/api\/users\/[^/]+\/audit$/) && method === 'GET') {
        const id = path.split('/')[3];
        response = await handleGetUserAudit(request, env, id);
      }
      // Requests routes
      else if (path === '/api/requests' && method === 'GET') {
        response = await handleListRequests(request, env);
      } else if (path === '/api/requests' && method === 'POST') {
        response = await handleCreateRequest(request, env);
      } else if (path.match(/^\/api\/requests\/[^/]+$/) && method === 'GET') {
        const id = path.split('/')[3];
        response = await handleGetRequest(request, env, id);
      } else if (path.match(/^\/api\/requests\/[^/]+$/) && method === 'PUT') {
        const id = path.split('/')[3];
        response = await handleUpdateRequest(request, env, id);
      } else if (path.match(/^\/api\/requests\/[^/]+$/) && method === 'DELETE') {
        const id = path.split('/')[3];
        response = await handleDeleteRequest(request, env, id);
      }
      // Files routes
      else if (path.match(/^\/api\/requests\/[^/]+\/files$/) && method === 'GET') {
        const requestId = path.split('/')[3];
        response = await handleListFiles(request, env, requestId);
      } else if (path.match(/^\/api\/requests\/[^/]+\/files$/) && method === 'POST') {
        const requestId = path.split('/')[3];
        response = await handleUploadFile(request, env, requestId);
      } else if (path.match(/^\/api\/files\/[^/]+$/) && method === 'GET') {
        const id = path.split('/')[3];
        response = await handleGetFile(request, env, id);
      } else if (path.match(/^\/api\/files\/[^/]+$/) && method === 'DELETE') {
        const id = path.split('/')[3];
        response = await handleDeleteFile(request, env, id);
      } else if (path.match(/^\/api\/files\/[^/]+\/original$/) && method === 'GET') {
        const id = path.split('/')[3];
        response = await handleGetOriginalUrl(request, env, id);
      } else if (path.match(/^\/api\/files\/[^/]+\/redacted$/) && method === 'GET') {
        const id = path.split('/')[3];
        response = await handleGetRedactedUrl(request, env, id);
      } else if (path.match(/^\/api\/files\/[^/]+\/redacted$/) && method === 'POST') {
        const id = path.split('/')[3];
        response = await handleUploadRedacted(request, env, id);
      }
      // Detections routes
      else if (path.match(/^\/api\/files\/[^/]+\/detections$/) && method === 'GET') {
        const fileId = path.split('/')[3];
        response = await handleListDetections(request, env, fileId);
      } else if (path.match(/^\/api\/files\/[^/]+\/detections$/) && method === 'POST') {
        const fileId = path.split('/')[3];
        response = await handleCreateDetections(request, env, fileId);
      } else if (path.match(/^\/api\/detections\/[^/]+$/) && method === 'PUT') {
        const id = path.split('/')[3];
        response = await handleUpdateDetection(request, env, id);
      } else if (path.match(/^\/api\/files\/[^/]+\/manual-redactions$/) && method === 'POST') {
        const fileId = path.split('/')[3];
        response = await handleCreateManualRedaction(request, env, fileId);
      } else if (path.match(/^\/api\/manual-redactions\/[^/]+$/) && method === 'DELETE') {
        const id = path.split('/')[3];
        response = await handleDeleteManualRedaction(request, env, id);
      }
      // Exports routes
      else if (path.match(/^\/api\/requests\/[^/]+\/exports$/) && method === 'GET') {
        const requestId = path.split('/')[3];
        response = await handleListExports(request, env, requestId);
      } else if (path.match(/^\/api\/requests\/[^/]+\/export$/) && method === 'POST') {
        const requestId = path.split('/')[3];
        response = await handleCreateExport(request, env, requestId);
      } else if (path.match(/^\/api\/exports\/[^/]+$/) && method === 'GET') {
        const id = path.split('/')[3];
        response = await handleGetExport(request, env, id);
      }
      // Audit routes
      else if (path.match(/^\/api\/requests\/[^/]+\/audit$/) && method === 'GET') {
        const requestId = path.split('/')[3];
        response = await handleGetAuditLog(request, env, requestId);
      } else if (path.match(/^\/api\/files\/[^/]+\/audit$/) && method === 'GET') {
        const fileId = path.split('/')[3];
        response = await handleGetFileAuditLog(request, env, fileId);
      }
      // Agencies routes
      else if (path === '/api/agencies' && method === 'GET') {
        response = await handleListAgencies(request, env);
      } else if (path === '/api/agencies' && method === 'POST') {
        response = await handleCreateAgency(request, env);
      } else if (path.match(/^\/api\/agencies\/code\/[^/]+$/) && method === 'GET') {
        const code = path.split('/')[4];
        response = await handleGetAgencyByCode(request, env, code);
      } else if (path.match(/^\/api\/agencies\/domain\/[^/]+$/) && method === 'GET') {
        const domain = path.split('/')[4];
        response = await handleGetAgencyByDomain(request, env, domain);
      }
      // Health check
      else if (path === '/api/health' && method === 'GET') {
        response = json({ status: 'ok', timestamp: Date.now() });
      }
      // 404
      else {
        response = error('Not found', 404);
      }

      return addCors(response);
    } catch (e) {
      console.error('Unhandled error:', e);
      return addCors(error('Internal server error', 500));
    }
  },
};
