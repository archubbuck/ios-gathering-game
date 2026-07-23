import 'dotenv/config';
import runner from 'node-pg-migrate';

// Thin wrapper around node-pg-migrate's programmatic API so `npm run
// migrate` / `migrate:up` / `migrate:down` (and migrate.yml's CI job) don't
// need node-pg-migrate's CLI flags spelled out everywhere. Always targets
// the direct/session connection (DATABASE_URL_UNPOOLED) — same rationale as
// scripts/lib/db.ts — never the pooled DATABASE_URL migrations run against
// elsewhere in this repo.
const direction = process.argv[2] === 'down' ? 'down' : 'up';

const databaseUrl = process.env.DATABASE_URL_UNPOOLED;
if (!databaseUrl) {
  console.error('DATABASE_URL_UNPOOLED environment variable is not set.');
  process.exit(1);
}

try {
  const migrations = await runner({
    databaseUrl,
    dir: 'migrations',
    direction,
    migrationsTable: 'pgmigrations',
  });
  console.log(
    migrations.length > 0
      ? `Ran ${migrations.length} migration(s) ${direction}.`
      : `No pending migrations to run ${direction}.`,
  );
} catch (err) {
  console.error(err);
  process.exit(1);
}
