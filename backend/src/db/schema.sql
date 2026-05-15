-- AI Phone Security — PostgreSQL schema

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

/* Users */
CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone       TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    name        TEXT,
    elderly_mode BOOLEAN NOT NULL DEFAULT FALSE,
    auto_block_threshold INTEGER NOT NULL DEFAULT 85,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at  TIMESTAMPTZ
);

/* Devices */
CREATE TABLE devices (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id   TEXT NOT NULL UNIQUE,
    platform    TEXT NOT NULL,      -- 'android' | 'ios'
    fcm_token   TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

/* Family relationships */
CREATE TABLE family_links (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    member_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    location_share BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, member_id)
);

/* Scam database — synced to device */
CREATE TABLE scam_phones (
    phone       TEXT PRIMARY KEY,
    category    TEXT NOT NULL,
    score       SMALLINT NOT NULL CHECK (score BETWEEN 0 AND 100),
    reason      TEXT,
    source      TEXT,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE scam_domains (
    domain      TEXT PRIMARY KEY,
    category    TEXT NOT NULL,
    score       SMALLINT NOT NULL CHECK (score BETWEEN 0 AND 100),
    reason      TEXT,
    source      TEXT,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

/* Safety events */
CREATE TABLE safety_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type        TEXT NOT NULL,      -- 'sos' | 'fall' | 'geofence' | 'low_battery'
    latitude    DOUBLE PRECISION,
    longitude   DOUBLE PRECISION,
    is_false_alarm BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

/* DB metadata */
CREATE TABLE db_meta (
    key         TEXT PRIMARY KEY,
    value       TEXT NOT NULL
);
INSERT INTO db_meta VALUES ('version', '0'), ('record_count', '0');

/* Indexes */
CREATE INDEX idx_safety_events_user ON safety_events(user_id, created_at DESC);
CREATE INDEX idx_scam_phones_score  ON scam_phones(score DESC);
CREATE INDEX idx_scam_domains_score ON scam_domains(score DESC);
