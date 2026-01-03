import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, PutCommand, DeleteCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import crypto from 'crypto';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const TABLE_NAME = process.env.CACHE_TABLE || process.env.DYNAMODB_TABLE || 'panda-user-cache';
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_KEY || process.env.SUPABASE_SERVICE_KEY;

const JWKS_TTL_MS = 10 * 60 * 1000;
let jwksCache = { keys: [], fetchedAt: 0 };

// Cache TTLs in seconds
const TTL = {
  USER_PROFILE: 5 * 60,      // 5 minutes
  USER_LIST: 10 * 60,        // 10 minutes (was 2 min - increased for better cache hits)
  RESERVED_USERNAMES: 60 * 60, // 1 hour
};

const DEFAULT_CORS_ORIGIN = 'http://localhost:5173';
const allowedOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

function resolveCorsOrigin(requestOrigin) {
  if (allowedOrigins.length === 0) {
    return DEFAULT_CORS_ORIGIN;
  }
  if (requestOrigin && allowedOrigins.includes(requestOrigin)) {
    return requestOrigin;
  }
  return allowedOrigins[0];
}

function buildCorsHeaders(requestOrigin) {
  return {
    'Access-Control-Allow-Origin': resolveCorsOrigin(requestOrigin),
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Content-Type': 'application/json',
  };
}

// Response helper
const response = (statusCode, body, requestOrigin) => ({
  statusCode,
  headers: buildCorsHeaders(requestOrigin),
  body: JSON.stringify(body),
});

function base64UrlDecode(value) {
  const padded = value.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(value.length / 4) * 4, '=');
  return Buffer.from(padded, 'base64');
}

function getSupabaseIssuer() {
  if (!SUPABASE_URL) return null;
  return `${SUPABASE_URL.replace(/\/$/, '')}/auth/v1`;
}

async function getJwks() {
  if (!SUPABASE_URL) {
    throw new Error('SUPABASE_URL is not configured');
  }

  const now = Date.now();
  if (jwksCache.keys.length > 0 && now - jwksCache.fetchedAt < JWKS_TTL_MS) {
    return jwksCache;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5000);

  try {
    const res = await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/auth/v1/keys`, {
      signal: controller.signal,
    });
    if (!res.ok) {
      const err = new Error(`Failed to fetch JWKS: ${res.status}`);
      err.code = 'JWKS_FETCH_FAILED';
      throw err;
    }
    const data = await res.json();
    if (!data?.keys) {
      const err = new Error('Invalid JWKS response');
      err.code = 'JWKS_FETCH_FAILED';
      throw err;
    }
    jwksCache = { keys: data.keys, fetchedAt: now };
    return jwksCache;
  } finally {
    clearTimeout(timeout);
  }
}

function jwkToKeyObject(jwk) {
  try {
    return crypto.createPublicKey({ key: jwk, format: 'jwk' });
  } catch {
    const cert = jwk?.x5c?.[0];
    if (!cert) {
      throw new Error('No usable key material for JWT verification');
    }
    const wrapped = cert.match(/.{1,64}/g)?.join('\n') || cert;
    const pem = `-----BEGIN CERTIFICATE-----\n${wrapped}\n-----END CERTIFICATE-----\n`;
    return crypto.createPublicKey(pem);
  }
}

// Verify Supabase JWT (signature + basic claims)
async function verifyToken(authHeader) {
  if (!authHeader?.startsWith('Bearer ')) {
    return null;
  }

  const token = authHeader.slice(7);

  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;

    const header = JSON.parse(base64UrlDecode(parts[0]).toString());
    const payload = JSON.parse(base64UrlDecode(parts[1]).toString());
    const signature = base64UrlDecode(parts[2]);
    const signingInput = `${parts[0]}.${parts[1]}`;

    // Check expiry
    if (payload.exp && payload.exp < Date.now() / 1000) {
      return null;
    }

    const expectedIssuer = getSupabaseIssuer();
    if (expectedIssuer && payload.iss !== expectedIssuer) {
      return null;
    }

    const expectedAud = 'authenticated';
    const aud = payload.aud;
    const audMatches = Array.isArray(aud) ? aud.includes(expectedAud) : aud === expectedAud;
    if (!audMatches) {
      return null;
    }

    const jwks = await getJwks();
    let jwk = jwks.keys.find((key) => key.kid === header.kid);
    if (!jwk) {
      jwksCache = { keys: [], fetchedAt: 0 };
      const refreshed = await getJwks();
      jwk = refreshed.keys.find((key) => key.kid === header.kid);
    }
    if (!jwk) return null;

    const keyObject = jwkToKeyObject(jwk);
    const isValid = crypto.verify('RSA-SHA256', Buffer.from(signingInput), keyObject, signature);
    if (!isValid) return null;

    return payload;
  } catch (error) {
    if (error?.code === 'JWKS_FETCH_FAILED') {
      throw error;
    }
    return null;
  }
}

// Get from cache
async function getFromCache(pk, sk) {
  try {
    const result = await docClient.send(new GetCommand({
      TableName: TABLE_NAME,
      Key: { pk, sk },
    }));

    if (!result.Item) return null;

    // Check if expired (TTL is in seconds, compare with current time)
    if (result.Item.ttl && result.Item.ttl < Math.floor(Date.now() / 1000)) {
      return null;
    }

    return result.Item.data;
  } catch (error) {
    console.error('Cache get error:', error);
    return null;
  }
}

// Put to cache
async function putToCache(pk, sk, data, ttlSeconds) {
  try {
    await docClient.send(new PutCommand({
      TableName: TABLE_NAME,
      Item: {
        pk,
        sk,
        data,
        ttl: Math.floor(Date.now() / 1000) + ttlSeconds,
        updatedAt: new Date().toISOString(),
      },
    }));
  } catch (error) {
    console.error('Cache put error:', error);
  }
}

// Delete from cache
async function deleteFromCache(pk, sk) {
  try {
    await docClient.send(new DeleteCommand({
      TableName: TABLE_NAME,
      Key: { pk, sk },
    }));
  } catch (error) {
    console.error('Cache delete error:', error);
  }
}

// Fetch from Supabase
async function fetchFromSupabase(table, query, options = {}) {
  const url = `${SUPABASE_URL}/rest/v1/${table}?${query}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      'apikey': SUPABASE_SERVICE_KEY,
      'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
      ...options.headers,
    },
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Supabase error: ${res.status} - ${text}`);
  }

  return res.json();
}

// Call Supabase RPC
async function callSupabaseRpc(functionName, params = {}, userToken = null) {
  const url = `${SUPABASE_URL}/rest/v1/rpc/${functionName}`;
  // Use user token if provided (for RLS-protected functions), otherwise use service key
  const authToken = userToken || SUPABASE_SERVICE_KEY;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_SERVICE_KEY,
      'Authorization': `Bearer ${authToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(params),
  });

  if (!res.ok) {
    const errorText = await res.text();
    console.error(`Supabase RPC error: ${res.status} - ${errorText}`);
    throw new Error(`Supabase RPC error: ${res.status}`);
  }

  return res.json();
}

// GET /user/:userId - Get user profile (role, is_blocked)
async function getUserProfile(userId) {
  const pk = `user:${userId}`;
  const sk = 'profile';

  // Try cache first
  const cached = await getFromCache(pk, sk);
  if (cached) {
    return { ...cached, _cached: true };
  }

  // Fetch from Supabase
  const data = await fetchFromSupabase(
    'user_profiles',
    `id=eq.${userId}&select=id,role,is_blocked,username,avatar_url,is_private`
  );

  if (!data || data.length === 0) {
    return null;
  }

  const profile = data[0];

  // Cache it
  await putToCache(pk, sk, profile, TTL.USER_PROFILE);

  return { ...profile, _cached: false };
}

// GET /public/user/:userId - Get public user profile (no auth)
async function getPublicUserProfile(userId) {
  const pk = `user:${userId}`;
  const sk = 'public-profile';

  const cached = await getFromCache(pk, sk);
  if (cached) {
    return { ...cached, _cached: true };
  }

  const data = await fetchFromSupabase(
    'user_profiles',
    `id=eq.${userId}&select=id,username,avatar_url,avatar_path,is_private`
  );

  if (!data || data.length === 0) {
    return null;
  }

  const profile = data[0];

  await putToCache(pk, sk, profile, TTL.USER_PROFILE);

  return { ...profile, _cached: false };
}
// GET /users - Get all users with stats (admin only)
async function getAllUsers() {
  const pk = 'admin';
  const sk = 'users';

  // Try cache first
  const cached = await getFromCache(pk, sk);
  if (cached) {
    return { users: cached, _cached: true };
  }

  // Fetch from Supabase RPC
  const users = await callSupabaseRpc('get_users_with_stats');

  // Cache it
  await putToCache(pk, sk, users, TTL.USER_LIST);

  return { users, _cached: false };
}

// Check cache only for paginated users (no Supabase fallback)
async function checkPaginatedUsersCache(limit, offset, search) {
  const pk = 'admin';
  const sk = `users:page:${limit}:${offset}:${search || ''}`;
  const cached = await getFromCache(pk, sk);
  return cached ? { ...cached, _cached: true } : null;
}

// GET /users/paginated - Get paginated users with stats (admin only)
// Note: This is called only on cache miss after parallel check
async function fetchPaginatedUsersFromSupabase(limit, offset, search, userToken) {
  const pk = 'admin';
  const sk = `users:page:${limit}:${offset}:${search || ''}`;

  // Fetch from Supabase RPC (pass user token for auth.uid() check)
  const users = await callSupabaseRpc('get_users_paginated', {
    p_limit: limit,
    p_offset: offset,
    p_search: search || null,
  }, userToken);

  // Extract total_count from first row (it's the same for all rows)
  const totalCount = users.length > 0 ? Number(users[0].total_count) : 0;

  // Remove total_count from each row (it's redundant)
  const cleanedUsers = users.map(({ total_count, ...user }) => user);

  const result = { users: cleanedUsers, totalCount };

  // Cache it
  await putToCache(pk, sk, result, TTL.USER_LIST);

  return { ...result, _cached: false };
}

// Legacy function for backwards compatibility
async function getPaginatedUsers(limit, offset, search, userToken) {
  const cached = await checkPaginatedUsersCache(limit, offset, search);
  if (cached) return cached;
  return fetchPaginatedUsersFromSupabase(limit, offset, search, userToken);
}

// DELETE /cache/user/:userId - Invalidate user cache
async function invalidateUserCache(userId) {
  await deleteFromCache(`user:${userId}`, 'profile');
  // Also invalidate admin users list since user data changed
  await invalidateAllUsersCacheEntries();
  return { success: true, invalidated: userId };
}

// DELETE /cache/users - Invalidate all users cache
async function invalidateUsersCache() {
  await invalidateAllUsersCacheEntries();
  return { success: true, invalidated: 'all-users' };
}

// Helper to invalidate all users cache entries (including paginated)
async function invalidateAllUsersCacheEntries() {
  try {
    // Delete the non-paginated users cache
    await deleteFromCache('admin', 'users');

    // Query and delete all paginated cache entries
    const result = await docClient.send(new QueryCommand({
      TableName: TABLE_NAME,
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :skPrefix)',
      ExpressionAttributeValues: {
        ':pk': 'admin',
        ':skPrefix': 'users:page:',
      },
    }));

    // Delete all matching entries
    if (result.Items && result.Items.length > 0) {
      await Promise.all(
        result.Items.map(item => deleteFromCache(item.pk, item.sk))
      );
    }
  } catch (error) {
    console.error('Error invalidating users cache entries:', error);
  }
}

// Main handler
export const handler = async (event) => {
  const requestOrigin = event.headers?.origin || event.headers?.Origin;
  // Handle CORS preflight
  if (event.requestContext?.http?.method === 'OPTIONS') {
    return response(200, {}, requestOrigin);
  }

  const method = event.requestContext?.http?.method || 'GET';
  const path = event.rawPath || '/';

  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
      return response(500, { error: 'Server configuration error' }, requestOrigin);
    }

    // Parse path
    const pathParts = path.split('/').filter(Boolean);

    // Health check
    if (path === '/' || path === '/health') {
      return response(200, { status: 'ok', timestamp: new Date().toISOString() }, requestOrigin);
    }

    // Verify auth for protected endpoints
    const authHeader = event.headers?.authorization || event.headers?.Authorization;
    let token = null;
    try {
      token = await verifyToken(authHeader);
    } catch (error) {
      console.error('Auth verification failed:', error);
      return response(503, { error: 'Auth service unavailable' }, requestOrigin);
    }

    // GET /user/:userId
    if (method === 'GET' && pathParts[0] === 'user' && pathParts[1]) {
      if (!token) {
        return response(401, { error: 'Unauthorized' }, requestOrigin);
      }
      const userId = pathParts[1];

      // Allow self lookup; require admin for other users
      if (token.sub !== userId) {
        const requesterProfile = await getUserProfile(token.sub);
        if (requesterProfile?.role !== 'admin') {
          return response(403, { error: 'Forbidden' }, requestOrigin);
        }
      }

      const profile = await getUserProfile(userId);

      if (!profile) {
        return response(404, { error: 'User not found' }, requestOrigin);
      }

      return response(200, profile, requestOrigin);
    }

    // GET /public/user/:userId (no auth)
    if (method === 'GET' && pathParts[0] === 'public' && pathParts[1] === 'user' && pathParts[2]) {
      const userId = pathParts[2];

      const profile = await getPublicUserProfile(userId);

      if (!profile) {
        return response(404, { error: 'User not found' }, requestOrigin);
      }

      return response(200, profile, requestOrigin);
    }

    // GET /users (admin only) - supports pagination via query params
    if (method === 'GET' && pathParts[0] === 'users') {
      if (!token) {
        return response(401, { error: 'Unauthorized' }, requestOrigin);
      }

      // Check for pagination query params
      const queryParams = event.queryStringParameters || {};
      const parsedLimit = queryParams.limit ? parseInt(queryParams.limit, 10) : NaN;
      const parsedOffset = queryParams.offset ? parseInt(queryParams.offset, 10) : NaN;
      const limit = Number.isFinite(parsedLimit) ? parsedLimit : null;
      const offset = Number.isFinite(parsedOffset) ? parsedOffset : null;
      const search = queryParams.search || null;

      // If pagination params provided, use optimized parallel fetch
      if (limit !== null && offset !== null) {
        // OPTIMIZATION: Fetch admin profile and check users cache in parallel
        const [adminProfile, cachedUsers] = await Promise.all([
          getUserProfile(token.sub),
          checkPaginatedUsersCache(limit, offset, search),
        ]);

        // Verify admin role
        if (adminProfile?.role !== 'admin') {
          return response(403, { error: 'Admin access required' }, requestOrigin);
        }

        // If cache hit, return immediately (saves ~200ms)
        if (cachedUsers) {
          return response(200, cachedUsers, requestOrigin);
        }

        // Cache miss - fetch from Supabase
        const userToken = authHeader?.slice(7); // Remove 'Bearer ' prefix
        const result = await fetchPaginatedUsersFromSupabase(limit, offset, search, userToken);
        return response(200, result, requestOrigin);
      }

      // Non-paginated request (legacy) - sequential fetch
      const adminProfile = await getUserProfile(token.sub);
      if (adminProfile?.role !== 'admin') {
        return response(403, { error: 'Admin access required' }, requestOrigin);
      }

      const result = await getAllUsers();
      return response(200, result, requestOrigin);
    }

    // DELETE /cache/user/:userId
    if (method === 'DELETE' && pathParts[0] === 'cache' && pathParts[1] === 'user' && pathParts[2]) {
      if (!token) {
        return response(401, { error: 'Unauthorized' }, requestOrigin);
      }

      const targetUserId = pathParts[2];
      if (token.sub !== targetUserId) {
        const requesterProfile = await getUserProfile(token.sub);
        if (requesterProfile?.role !== 'admin') {
          return response(403, { error: 'Admin access required' }, requestOrigin);
        }
      }

      const result = await invalidateUserCache(targetUserId);
      return response(200, result, requestOrigin);
    }

    // DELETE /cache/users
    if (method === 'DELETE' && pathParts[0] === 'cache' && pathParts[1] === 'users') {
      if (!token) {
        return response(401, { error: 'Unauthorized' }, requestOrigin);
      }

      const requesterProfile = await getUserProfile(token.sub);
      if (requesterProfile?.role !== 'admin') {
        return response(403, { error: 'Admin access required' }, requestOrigin);
      }

      const result = await invalidateUsersCache();
      return response(200, result, requestOrigin);
    }

    return response(404, { error: 'Not found' }, requestOrigin);

  } catch (error) {
    console.error('Handler error:', error);
    return response(500, { error: 'Internal server error' }, requestOrigin);
  }
};
