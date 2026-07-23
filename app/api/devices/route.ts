import { requireAuth } from '@/lib/auth';
import { sql } from '@/lib/db';
import { ApiError, errorResponse, json, readJsonBody } from '@/lib/http';

export const runtime = 'nodejs';

interface RegisterDeviceBody {
  token?: string;
  environment?: string;
  timezone?: string;
}

const VALID_ENVIRONMENTS = new Set(['sandbox', 'production']);

export async function POST(req: Request): Promise<Response> {
  try {
    const { userId } = await requireAuth(req);
    const body = await readJsonBody<RegisterDeviceBody>(req);

    if (!body.token) {
      throw new ApiError(400, 'token is required');
    }
    if (!body.environment || !VALID_ENVIRONMENTS.has(body.environment)) {
      throw new ApiError(400, "environment must be 'sandbox' or 'production'");
    }

    await sql`
      INSERT INTO device_tokens (user_id, token, environment, timezone, updated_at)
      VALUES (${userId}, ${body.token}, ${body.environment}, ${body.timezone ?? 'UTC'}, now())
      ON CONFLICT (user_id, token)
      DO UPDATE SET environment = EXCLUDED.environment, timezone = EXCLUDED.timezone, updated_at = now()
    `;

    return json({ registered: true });
  } catch (err) {
    return errorResponse(err);
  }
}
