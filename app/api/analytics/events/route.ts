import { requireAuth } from '@/lib/auth';
import { sql } from '@/lib/db';
import { ApiError, errorResponse, json, readJsonBody } from '@/lib/http';

export const runtime = 'nodejs';

interface AnalyticsEvent {
  event_type?: string;
  deck_id?: string;
  payload?: Record<string, unknown>;
  occurred_at?: string;
}

interface AnalyticsEventsBody {
  events?: AnalyticsEvent[];
}

export async function POST(req: Request): Promise<Response> {
  try {
    const { userId } = await requireAuth(req);
    const body = await readJsonBody<AnalyticsEventsBody>(req);

    if (!Array.isArray(body.events)) {
      throw new ApiError(400, 'events must be an array');
    }

    const validEvents = body.events.filter(
      (event): event is Required<Pick<AnalyticsEvent, 'event_type'>> & AnalyticsEvent =>
        typeof event.event_type === 'string',
    );

    // Fire-and-forget from the client's perspective (§3.19) — invalid entries
    // are simply skipped rather than failing the whole batch.
    await Promise.all(
      validEvents.map((event) =>
        sql`
          INSERT INTO analytics_events (user_id, deck_id, event_type, payload, occurred_at)
          VALUES (
            ${userId}, ${event.deck_id ?? null}, ${event.event_type},
            ${JSON.stringify(event.payload ?? {})}, ${event.occurred_at ?? new Date().toISOString()}
          )
        `,
      ),
    );

    return json({ accepted: validEvents.length }, 202);
  } catch (err) {
    return errorResponse(err);
  }
}
