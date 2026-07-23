import { neon, Pool, type PoolClient } from '@neondatabase/serverless';

// Deliberately not validated/thrown on here: Next.js evaluates route modules
// during the build's page-data-collection step, and a build shouldn't
// require production secrets just to load a file that's never invoked. An
// unset DATABASE_URL surfaces as a clear connection error the moment a
// route actually issues a query, which is the right time for it to fail.
// The placeholder must still be shaped like a real connection string —
// neon() validates the format eagerly at construction time, even though it
// doesn't actually connect until a query runs.
const connectionString = process.env.DATABASE_URL ?? 'postgresql://user:password@host.tld/dbname';

// HTTP-based driver for simple, single-statement request-time queries —
// no connection to hold open between invocations.
export const sql = neon(connectionString);

let pool: Pool | undefined;

function getPool(): Pool {
  if (!pool) {
    pool = new Pool({ connectionString });
  }
  return pool;
}

// For multi-statement operations that must commit or roll back together
// (e.g. inserting a swipe, updating tag_weights, and checking for a mutual match).
export async function withTransaction<T>(
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
