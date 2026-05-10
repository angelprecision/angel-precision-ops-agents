-- ============================================================
-- Angel Precision Ops — Complete Supabase Schema
-- Run in Supabase SQL editor. All statements are idempotent.
-- ============================================================

-- ── LEADS (alter existing table) ─────────────────────────────
ALTER TABLE leads
  ADD COLUMN IF NOT EXISTS estimated_seriousness    text    DEFAULT 'unknown',
  ADD COLUMN IF NOT EXISTS time_to_close_estimate   text    DEFAULT 'unknown',
  ADD COLUMN IF NOT EXISTS last_engagement_score    integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS booked_call_at           timestamptz,
  ADD COLUMN IF NOT EXISTS last_engagement_at       timestamptz;

-- Temperature bucket for pipeline view
ALTER TABLE leads
  ADD COLUMN IF NOT EXISTS temperature text DEFAULT 'cold'
    CHECK (temperature IN ('hot', 'warm', 'cold', 'dead'));

ALTER TABLE leads
  ADD COLUMN IF NOT EXISTS next_action  text,
  ADD COLUMN IF NOT EXISTS notes        text;

-- ── PROOF VAULT ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS proof_vault (
  id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  artifact_type        text        NOT NULL,
  title                text        NOT NULL,
  description          text,
  platform_use         text,
  file_url             text,
  related_trade_id     text,
  related_client_id    uuid        REFERENCES clients(id) ON DELETE SET NULL,
  sensitivity          text        DEFAULT 'internal'
                                   CHECK (sensitivity IN ('internal','sales','public')),
  approved_for_content boolean     DEFAULT false,
  approved_for_sales   boolean     DEFAULT false,
  created_at           timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS proof_vault_created_at_idx
  ON proof_vault(created_at DESC);
CREATE INDEX IF NOT EXISTS proof_vault_sensitivity_idx
  ON proof_vault(sensitivity);

-- ── INCIDENTS ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS incidents (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  title             text        NOT NULL,
  severity          text        DEFAULT 'INFO'
                                CHECK (severity IN ('INFO','WARNING','CRITICAL','EMERGENCY')),
  status            text        DEFAULT 'open'
                                CHECK (status IN ('open','investigating','resolved','closed')),
  source            text,
  incident_type     text,
  summary           text,
  root_cause        text,
  fix_applied       text,
  prevention_layer  text,
  lesson_learned    text,
  content_angle     text,
  related_event_ids jsonb,
  opened_at         timestamptz DEFAULT now(),
  resolved_at       timestamptz
);

CREATE INDEX IF NOT EXISTS incidents_status_idx   ON incidents(status);
CREATE INDEX IF NOT EXISTS incidents_severity_idx ON incidents(severity);
CREATE INDEX IF NOT EXISTS incidents_opened_at_idx ON incidents(opened_at DESC);

-- ── ALERT ROUTES ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS alert_routes (
  id                      uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  severity                text    NOT NULL
                                  CHECK (severity IN ('INFO','WARNING','CRITICAL','EMERGENCY')),
  channel                 text    NOT NULL,
  destination             text,
  cooldown_minutes        integer DEFAULT 15,
  escalation_after_minutes integer DEFAULT 30,
  enabled                 boolean DEFAULT true,
  created_at              timestamptz DEFAULT now()
);

INSERT INTO alert_routes
  (severity, channel, destination, cooldown_minutes, escalation_after_minutes)
VALUES
  ('INFO',      'log_only',           'daily_report',        0,  0),
  ('WARNING',   'discord',            'ops-alerts',         15, 30),
  ('CRITICAL',  'discord+email',      'ops-alerts+founder', 10, 20),
  ('EMERGENCY', 'discord+email+sms',  'all',                 5, 10)
ON CONFLICT DO NOTHING;

-- ── SUPPRESSED ALERTS (escalations tab) ──────────────────────
CREATE TABLE IF NOT EXISTS suppressed_alerts (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  fingerprint   text        NOT NULL UNIQUE,
  severity      text,
  count         integer     DEFAULT 1,
  last_seen_at  timestamptz DEFAULT now(),
  escalated     boolean     DEFAULT false,
  expires_at    timestamptz
);

CREATE INDEX IF NOT EXISTS suppressed_alerts_fp_idx
  ON suppressed_alerts(fingerprint);

-- ── SYSTEM HEALTH EVENTS (bot ops tab) ───────────────────────
CREATE TABLE IF NOT EXISTS system_health_events (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  occurred_at  timestamptz DEFAULT now(),
  severity     text        DEFAULT 'INFO'
                           CHECK (severity IN ('INFO','WARNING','CRITICAL','EMERGENCY')),
  source       text,              -- e.g. 'ap_scanner', 'ap_queue', 'ap_broker'
  event_type   text,              -- e.g. 'zero_signals', 'fill_monitor_restart'
  message      text,
  payload      jsonb,
  resolved     boolean     DEFAULT false
);

CREATE INDEX IF NOT EXISTS system_health_events_occurred_at_idx
  ON system_health_events(occurred_at DESC);
CREATE INDEX IF NOT EXISTS system_health_events_severity_idx
  ON system_health_events(severity);

-- ── CONTENT QUEUE (content tab) ───────────────────────────────
CREATE TABLE IF NOT EXISTS content_queue (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  platform        text        NOT NULL
                              CHECK (platform IN ('x','linkedin','facebook','reddit','medium','substack','email')),
  content_type    text        DEFAULT 'post',  -- 'post', 'thread', 'article', 'letter'
  preview_text    text,
  full_content    text,
  status          text        DEFAULT 'draft'
                              CHECK (status IN ('draft','pending_approval','approved','published','rejected')),
  approved_by     text,
  approved_at     timestamptz,
  published_at    timestamptz,
  source_letter   text,        -- which operator letter this came from
  n8n_run_id      text,        -- trace back to n8n execution
  created_at      timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS content_queue_platform_idx  ON content_queue(platform);
CREATE INDEX IF NOT EXISTS content_queue_status_idx    ON content_queue(status);
CREATE INDEX IF NOT EXISTS content_queue_created_at_idx ON content_queue(created_at DESC);

-- ── DAILY CADENCE LOGS (cadence tab) ─────────────────────────
CREATE TABLE IF NOT EXISTS daily_cadence_logs (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  log_date      date        NOT NULL DEFAULT CURRENT_DATE,
  item_key      text        NOT NULL,  -- 'fp','xp','od','fu','on','dr','pa'
  item_label    text,
  completed     boolean     DEFAULT false,
  completed_at  timestamptz,
  notes         text,
  UNIQUE (log_date, item_key)
);

CREATE INDEX IF NOT EXISTS daily_cadence_logs_date_idx
  ON daily_cadence_logs(log_date DESC);

-- Seed today's cadence items if not already present
INSERT INTO daily_cadence_logs (log_date, item_key, item_label)
VALUES
  (CURRENT_DATE, 'fp', 'Founder post'),
  (CURRENT_DATE, 'xp', 'X posts (2)'),
  (CURRENT_DATE, 'od', 'Outreach drafts (5)'),
  (CURRENT_DATE, 'fu', 'Follow-ups (5)'),
  (CURRENT_DATE, 'on', 'Ops note'),
  (CURRENT_DATE, 'dr', 'Dashboard refinement'),
  (CURRENT_DATE, 'pa', 'Proof artifact')
ON CONFLICT (log_date, item_key) DO NOTHING;

-- ── RLS POLICIES (enable on all tables) ──────────────────────
-- Run these after confirming auth setup. Using service_role key
-- in n8n bypasses RLS. Anon key from dashboard needs these.

ALTER TABLE proof_vault          ENABLE ROW LEVEL SECURITY;
ALTER TABLE incidents            ENABLE ROW LEVEL SECURITY;
ALTER TABLE alert_routes         ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppressed_alerts    ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_health_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_queue        ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_cadence_logs   ENABLE ROW LEVEL SECURITY;

-- Allow service_role full access (n8n uses service_role key)
-- Dashboard should use service_role key too (internal tool, not public)
-- If you want anon access for the dashboard, add:
-- CREATE POLICY "anon_read" ON proof_vault FOR SELECT USING (true);
-- (repeat for each table as needed)
