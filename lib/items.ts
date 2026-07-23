import { sql, withTransaction } from './db';
import { ApiError } from './http';

export interface Item {
  id: string;
  user_id: string;
  title: string;
  body: string;
  created_at: string;
  updated_at: string;
}

export interface ItemInput {
  title: string;
  body?: string;
}

export async function getItems(userId: string): Promise<Item[]> {
  const rows = await sql`
    SELECT id, user_id, title, body, created_at, updated_at
    FROM items
    WHERE user_id = ${userId}
    ORDER BY created_at DESC
  `;
  return rows.map((row) => ({
    id: row.id as string,
    user_id: row.user_id as string,
    title: row.title as string,
    body: row.body as string,
    created_at: (row.created_at as Date).toISOString(),
    updated_at: (row.updated_at as Date).toISOString(),
  }));
}

export async function getItem(itemId: string): Promise<Item> {
  const rows = await sql`
    SELECT id, user_id, title, body, created_at, updated_at
    FROM items
    WHERE id = ${itemId}
  `;
  if (rows.length === 0) {
    throw new ApiError(404, 'Item not found');
  }
  const row = rows[0]!;
  return {
    id: row.id as string,
    user_id: row.user_id as string,
    title: row.title as string,
    body: row.body as string,
    created_at: (row.created_at as Date).toISOString(),
    updated_at: (row.updated_at as Date).toISOString(),
  };
}

export async function createItem(userId: string, input: ItemInput): Promise<Item> {
  const rows = await sql`
    INSERT INTO items (user_id, title, body)
    VALUES (${userId}, ${input.title}, ${input.body ?? ''})
    RETURNING id, user_id, title, body, created_at, updated_at
  `;
  const row = rows[0]!;
  return {
    id: row.id as string,
    user_id: row.user_id as string,
    title: row.title as string,
    body: row.body as string,
    created_at: (row.created_at as Date).toISOString(),
    updated_at: (row.updated_at as Date).toISOString(),
  };
}

export async function updateItem(
  itemId: string,
  userId: string,
  updates: Partial<ItemInput>,
): Promise<Item> {
  // Verify ownership
  const existing = await sql`SELECT user_id FROM items WHERE id = ${itemId}`;
  if (existing.length === 0) {
    throw new ApiError(404, 'Item not found');
  }
  if (existing[0]!.user_id !== userId) {
    throw new ApiError(403, 'You do not own this item');
  }

  const rows = await sql`
    UPDATE items
    SET
      title = COALESCE(${updates.title ?? null}, title),
      body = COALESCE(${updates.body ?? null}, body),
      updated_at = now()
    WHERE id = ${itemId}
    RETURNING id, user_id, title, body, created_at, updated_at
  `;
  const row = rows[0]!;
  return {
    id: row.id as string,
    user_id: row.user_id as string,
    title: row.title as string,
    body: row.body as string,
    created_at: (row.created_at as Date).toISOString(),
    updated_at: (row.updated_at as Date).toISOString(),
  };
}

export async function deleteItem(itemId: string, userId: string): Promise<void> {
  const result = await sql`
    DELETE FROM items
    WHERE id = ${itemId} AND user_id = ${userId}
  `;
  if (result.length === 0) {
    throw new ApiError(404, 'Item not found');
  }
}
