import { requireAuth } from '@/lib/auth';
import { errorResponse, json, readJsonBody } from '@/lib/http';
import { createItem, getItems, type ItemInput } from '@/lib/items';

export const runtime = 'nodejs';

export async function GET(req: Request): Promise<Response> {
  try {
    const { userId } = await requireAuth(req);
    const items = await getItems(userId);
    return json({ items });
  } catch (err) {
    return errorResponse(err);
  }
}

export async function POST(req: Request): Promise<Response> {
  try {
    const { userId } = await requireAuth(req);
    const body = await readJsonBody<ItemInput>(req);
    if (!body.title) {
      return json({ error: 'title is required' }, 400);
    }
    const item = await createItem(userId, body);
    return json(item, 201);
  } catch (err) {
    return errorResponse(err);
  }
}
