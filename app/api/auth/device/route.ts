import { signAccessToken } from '@/lib/auth';
import { sql } from '@/lib/db';
import { ApiError, errorResponse, json, readJsonBody } from '@/lib/http';

export const runtime = 'nodejs';

// Stand-in for POST /auth/apple while Sign in with Apple is disabled
// client-side (see the migration adding users.device_id). Identifies users
// by UIDevice.identifierForVendor instead of an Apple identity token — no
// server-side verification is possible for a client-supplied device ID (unlike
// Apple's signed identity token), so this trades that guarantee for not
// requiring an entitlement. Acceptable for now since nothing sensitive is
// gated on identity beyond "same device, same account."
interface DeviceAuthBody {
  device_id?: string;
}

export async function POST(req: Request): Promise<Response> {
  try {
    const body = await readJsonBody<DeviceAuthBody>(req);
    if (!body.device_id) {
      throw new ApiError(400, 'device_id is required');
    }

    const existing = await sql`SELECT id FROM users WHERE device_id = ${body.device_id}`;

    let userId: string;
    let isNewUser: boolean;

    if (existing.length > 0) {
      userId = existing[0]!.id as string;
      isNewUser = false;
    } else {
      const inserted = await sql`
        INSERT INTO users (device_id) VALUES (${body.device_id}) RETURNING id
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
