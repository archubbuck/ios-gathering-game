import 'dotenv/config';
import { Pool, type PoolClient } from 'pg';

// Ingestion scripts are short-lived CLI processes, not serverless request
// handlers, so they get their own dedicated pool against the direct/session
// connection string (same one migrations use) rather than importing
// lib/db.ts: that module's `sql` is an HTTP-per-statement client (too slow
// for hundreds of thousands of batched upserts) and its `Pool` is a
// module-level singleton with no `.end()` — correct for a long-lived
// serverless module, wrong for a process that must cleanly exit.
//
// Lazily constructed (mirrors lib/db.ts's getPool()) so a --dry-run script
// that never touches the database doesn't require DATABASE_URL_UNPOOLED to
// be set at all.
let pool: Pool | undefined;

function getPool(): Pool {
  if (!pool) {
    const connectionString = process.env.DATABASE_URL_UNPOOLED;
    if (!connectionString) {
      throw new Error('DATABASE_URL_UNPOOLED must be set to run ingestion scripts.');
    }
    pool = new Pool({ connectionString });
  }
  return pool;
}

export async function withScriptTransaction<T>(
  fn: (client: PoolClient) => Promise<T>,
): Promise<T> {
  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

// Runs a single statement outside any explicit transaction (each call
// auto-commits independently). Useful when a caller needs a sequence of
// independent, individually-skippable writes — e.g. resolve-attributes.ts
// applying one UPDATE per name where a single conflict should only skip
// that row, not abort a whole batch of otherwise-unrelated updates.
export async function query<T = unknown>(text: string, params?: unknown[]): Promise<{ rows: T[]; rowCount: number | null }> {
  const result = await getPool().query(text, params);
  return { rows: result.rows as T[], rowCount: result.rowCount };
}

export async function closePool(): Promise<void> {
  if (pool) await pool.end();
}
