import { SignJWT, jwtVerify } from 'jose';
import { ApiError } from './http';

const ACCESS_TOKEN_TTL_SECONDS = 90 * 24 * 60 * 60; // 90 days

function getSigningKey(): Uint8Array {
  const secret = process.env.JWT_SIGNING_SECRET;
  if (!secret) {
    throw new Error('JWT_SIGNING_SECRET environment variable is not set');
  }
  return new TextEncoder().encode(secret);
}

export interface AccessTokenClaims {
  userId: string;
}

export async function signAccessToken(claims: AccessTokenClaims): Promise<string> {
  return new SignJWT({})
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(claims.userId)
    .setIssuedAt()
    .setExpirationTime(`${ACCESS_TOKEN_TTL_SECONDS}s`)
    .sign(getSigningKey());
}

export interface AuthContext {
  userId: string;
}

// Extracts and verifies the JWT bearer token from the Authorization header.
// Add your own resource-level authorization checks (e.g. ownership) per route.
export async function requireAuth(req: Request): Promise<AuthContext> {
  const header = req.headers.get('authorization');
  if (!header?.startsWith('Bearer ')) {
    throw new ApiError(401, 'Missing bearer token');
  }
  const token = header.slice('Bearer '.length);

  try {
    const { payload } = await jwtVerify(token, getSigningKey());
    if (typeof payload.sub !== 'string') {
      throw new ApiError(401, 'Invalid access token');
    }
    return { userId: payload.sub };
  } catch (err) {
    if (err instanceof ApiError) throw err;
    throw new ApiError(401, 'Invalid or expired access token');
  }
}

