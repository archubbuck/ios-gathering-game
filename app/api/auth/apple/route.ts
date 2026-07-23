import { verifyAppleIdentityToken } from '@/lib/apple';
import { signAccessToken } from '@/lib/auth';
import { sql } from '@/lib/db';
import { ApiError, errorResponse, json, readJsonBody } from '@/lib/http';

export const runtime = 'nodejs';

interface AppleAuthBody {
  identity_token?: string;
}

export async function POST(req: Request): Promise<Response> {
  try {
    const body = await readJsonBody<AppleAuthBody>(req);
    if (!body.identity_token) {
      throw new ApiError(400, 'identity_token is required');
    }

    const identity = await verifyAppleIdentityToken(body.identity_token);

    const existing = await sql`SELECT id FROM users WHERE apple_id_sub = ${identity.sub}`;

    let userId: string;
    let isNewUser: boolean;

    if (existing.length > 0) {
      userId = existing[0]!.id as string;
      isNewUser = false;
    } else {
      const inserted = await sql`
        INSERT INTO users (apple_id_sub) VALUES (${identity.sub}) RETURNING id
      `;
      userId = inserted[0]!.id as string;
      isNewUser = true;
      await sql`INSERT INTO notification_preferences (user_id) VALUES (${userId})`;
    }

    const accessToken = await signAccessToken({ userId });

    return json({ access_token: accessToken, user_id: userId, is_new_user: isNewUser });
  } catch (err) {
    return errorResponse(err);
  }
}
