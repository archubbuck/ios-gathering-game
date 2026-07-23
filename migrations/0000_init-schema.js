/* eslint-disable camelcase */

exports.shorthands = undefined;

exports.up = (pgm) => {
  pgm.createExtension('pgcrypto', { ifNotExists: true });

  pgm.sql(`
    -- Users (Sign in with Apple primary, device-ID fallback)
    CREATE TABLE users (
      id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      apple_id_sub  TEXT UNIQUE,
      device_id     TEXT UNIQUE,
      display_name  TEXT,
      created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    -- Push notification device tokens (one per user+device combo)
    CREATE TABLE device_tokens (
      user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      token       TEXT NOT NULL,
      environment TEXT NOT NULL CHECK (environment IN ('sandbox','production')),
      timezone    TEXT NOT NULL DEFAULT 'UTC',
      updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (user_id, token)
    );

    -- Per-user notification preferences
    CREATE TABLE notification_preferences (
      user_id               UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      weekly_digest_enabled BOOLEAN NOT NULL DEFAULT true,
      mutual_match_enabled  BOOLEAN NOT NULL DEFAULT true,
      updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    -- Analytics events (raw event log)
    CREATE TABLE analytics_events (
      id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id     UUID REFERENCES users(id),
      event_type  TEXT NOT NULL,
      payload     JSONB NOT NULL DEFAULT '{}',
      occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE INDEX idx_analytics_events_occurred_at ON analytics_events (occurred_at);

    -- Reference example: Items CRUD
    CREATE TABLE items (
      id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      title       TEXT NOT NULL,
      body        TEXT NOT NULL DEFAULT '',
      created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE INDEX idx_items_user_id ON items (user_id);
  `);
};

exports.down = (pgm) => {
  pgm.sql(`
    DROP TABLE IF EXISTS items;
    DROP TABLE IF EXISTS analytics_events;
    DROP TABLE IF EXISTS notification_preferences;
    DROP TABLE IF EXISTS device_tokens;
    DROP TABLE IF EXISTS users;
  `);
};
