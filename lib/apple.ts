import { createRemoteJWKSet, jwtVerify } from 'jose';
import { ApiError } from './http';

const APPLE_ISSUER = 'https://appleid.apple.com';
const JWKS = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

export interface AppleIdentity {
  sub: string;
  email?: string;
}

// Verifies a Sign in with Apple identity_token against Apple's published JWKS.
export async function verifyAppleIdentityToken(identityToken: string): Promise<AppleIdentity> {
  const clientId = process.env.APPLE_CLIENT_ID;
  if (!clientId) {
    throw new Error('APPLE_CLIENT_ID environment variable is not set');
  }

  let payload;
  try {
    ({ payload } = await jwtVerify(identityToken, JWKS, {
      issuer: APPLE_ISSUER,
      audience: clientId,
    }));
  } catch {
    throw new ApiError(401, 'Invalid Apple identity token');
  }

  if (typeof payload.sub !== 'string') {
    throw new ApiError(401, 'Apple identity token is missing a subject claim');
  }

  return {
    sub: payload.sub,
    email: typeof payload.email === 'string' ? payload.email : undefined,
  };
}
