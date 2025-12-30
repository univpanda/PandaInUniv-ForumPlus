import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, PutCommand, DeleteCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const TABLE_NAME = process.env.CACHE_TABLE || process.env.DYNAMODB_TABLE || 'panda-user-cache';
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_KEY || process.env.SUPABASE_SERVICE_KEY;

// Cache TTLs in seconds
const TTL = {
  USER_PROFILE: 5 * 60,      // 5 minutes
  USER_LIST: 10 * 60,        // 10 minutes (was 2 min - increased for better cache hits)
  RESERVED_USERNAMES: 60 * 60, // 1 hour
};

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Content-Type': 'application/json',
};

// Response helper
const response = (statusCode, body) => ({
  statusCode,
  headers: corsHeaders,
  body: JSON.stringify(body),
});

// Verify Supabase JWT (basic validation)
async function verifyToken(authHeader) {
  if (!authHeader?.startsWith('Bearer ')) {
    return null;
  }

  const token = authHeader.slice(7);

  try {
    // Decode JWT payload (base64)
    const parts = token.split('.');
    if (parts.length !== 3) return null;

    const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString());

    // Check expiry
    if (payload.exp && payload.exp < Date.now() / 1000) {
      return null;
    }

    return payload;
  } catch {
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
  // Handle CORS preflight
  if (event.requestContext?.http?.method === 'OPTIONS') {
    return response(200, {});
  }

  const method = event.requestContext?.http?.method || 'GET';
  const path = event.rawPath || '/';

  try {
    // Parse path
    const pathParts = path.split('/').filter(Boolean);

    // Health check
    if (path === '/' || path === '/health') {
      return response(200, { status: 'ok', timestamp: new Date().toISOString() });
    }

    // Verify auth for protected endpoints
    const authHeader = event.headers?.authorization || event.headers?.Authorization;
    const token = await verifyToken(authHeader);

    // GET /user/:userId
    if (method === 'GET' && pathParts[0] === 'user' && pathParts[1]) {
      const userId = pathParts[1];

      // Optional: verify token.sub matches userId for non-admin
      const profile = await getUserProfile(userId);

      if (!profile) {
        return response(404, { error: 'User not found' });
      }

      return response(200, profile);
    }

    // GET /users (admin only) - supports pagination via query params
    if (method === 'GET' && pathParts[0] === 'users') {
      if (!token) {
        return response(401, { error: 'Unauthorized' });
      }

      // Check for pagination query params
      const queryParams = event.queryStringParameters || {};
      const limit = queryParams.limit ? parseInt(queryParams.limit, 10) : null;
      const offset = queryParams.offset ? parseInt(queryParams.offset, 10) : null;
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
          return response(403, { error: 'Admin access required' });
        }

        // If cache hit, return immediately (saves ~200ms)
        if (cachedUsers) {
          return response(200, cachedUsers);
        }

        // Cache miss - fetch from Supabase
        const userToken = authHeader?.slice(7); // Remove 'Bearer ' prefix
        const result = await fetchPaginatedUsersFromSupabase(limit, offset, search, userToken);
        return response(200, result);
      }

      // Non-paginated request (legacy) - sequential fetch
      const adminProfile = await getUserProfile(token.sub);
      if (adminProfile?.role !== 'admin') {
        return response(403, { error: 'Admin access required' });
      }

      const result = await getAllUsers();
      return response(200, result);
    }

    // DELETE /cache/user/:userId
    if (method === 'DELETE' && pathParts[0] === 'cache' && pathParts[1] === 'user' && pathParts[2]) {
      if (!token) {
        return response(401, { error: 'Unauthorized' });
      }

      const result = await invalidateUserCache(pathParts[2]);
      return response(200, result);
    }

    // DELETE /cache/users
    if (method === 'DELETE' && pathParts[0] === 'cache' && pathParts[1] === 'users') {
      if (!token) {
        return response(401, { error: 'Unauthorized' });
      }

      const result = await invalidateUsersCache();
      return response(200, result);
    }

    return response(404, { error: 'Not found' });

  } catch (error) {
    console.error('Handler error:', error);
    return response(500, { error: 'Internal server error' });
  }
};
