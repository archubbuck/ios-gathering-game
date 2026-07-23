import { ApiError } from './http';

// Vercel Cron invokes with `Authorization: Bearer $CRON_SECRET` when
// CRON_SECRET is set on the project — this guards /api/internal/cron/*
// routes from being triggered by anyone else.
export function requireCronSecret(req: Request): void {
  const secret = process.env.CRON_SECRET;
  if (!secret) {
    throw new Error('CRON_SECRET environment variable is not set');
  }
  const header = req.headers.get('authorization');
  if (header !== `Bearer ${secret}`) {
    throw new ApiError(401, 'Unauthorized');
  }
}
