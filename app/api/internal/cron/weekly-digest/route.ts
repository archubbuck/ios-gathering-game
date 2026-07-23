import { requireCronSecret } from '@/lib/cron';
import { errorResponse, json } from '@/lib/http';

export const runtime = 'nodejs';

// Placeholder Vercel Cron job handler.
// Replace this with your own scheduled task logic.
// See vercel.json for the cron schedule configuration.
export async function GET(req: Request): Promise<Response> {
  try {
    requireCronSecret(req);
    console.log('Cron job executed successfully');
    return json({ ok: true });
  } catch (err) {
    return errorResponse(err);
  }
}
