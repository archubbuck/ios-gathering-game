import { requireAuth } from '@/lib/auth';
import { errorResponse, json, readJsonBody } from '@/lib/http';
import { deleteItem, getItem, updateItem, type ItemInput } from '@/lib/items';

export const runtime = 'nodejs';

export async function GET(
  req: Request,
  { params }: { params: { itemId: string } },
): Promise<Response> {
  try {
    await requireAuth(req);
    const item = await getItem(params.itemId);
    return json(item);
  } catch (err) {
    return errorResponse(err);
  }
}

export async function PATCH(
  req: Request,
  { params }: { params: { itemId: string } },
): Promise<Response> {
  try {
    const { userId } = await requireAuth(req);
    const updates = await readJsonBody<Partial<ItemInput>>(req);
    const item = await updateItem(params.itemId, userId, updates);
    return json(item);
  } catch (err) {
    return errorResponse(err);
  }
}

export async function DELETE(
  req: Request,
  { params }: { params: { itemId: string } },
): Promise<Response> {
  try {
    const { userId } = await requireAuth(req);
    await deleteItem(params.itemId, userId);
    return json({ deleted: true });
  } catch (err) {
    return errorResponse(err);
  }
}
