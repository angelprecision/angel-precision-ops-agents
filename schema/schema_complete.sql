-- ============================================================
-- Angel Precision Ops — Complete Supabase Schema v2
-- Run in Supabase SQL editor. Paste the entire file at once.
-- Zero foreign key dependencies — all tables are standalone.
-- ============================================================


-- ── 1. LEADS — add columns to existing table ─────────────────

ALTER TABLE leads ADD COLUMN IF NOT EXISTS estimated_seriousness    text    DEFAULT 'unknown';
ALTER TABLE leads ADD COLUMN IF NOT EXISTS time_to_close_estimate   text    DEFAULT 'unknown';
ALTER TABLE leads ADD COLUMN IF NOT EXISTS last_engagement_score    integer DEFAULT 0;
ALTER TABLE leads ADD COLUMN IF NOT EXISTS booked_call_at           timestamptz;
ALTER TABLE leads ADD COLUMN IF NOT EXISTS last_engagement_at       timestamptz;
ALTER TABLE leads ADD COLUMN IF NOT EXISTS next_action              text;
ALTER TABLE leads ADD COLUMN IF NOT EXISTS notes                    text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'leads' AND column_name = 'temperature'
  ) THEN
    ALTER TABLE leads ADD COLUMN temperature text DEFAULT 'cold';
    ALTER TABLE leads ADD CONSTRAINT leads_temperature_check
      CHECK (temperature IN ('hot','warm','cold','dead'));
  END IF;
END $$;


-- ── 2. PROOF VAULT ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS proof_vault (
  id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  artifact_type        text        NOT NULL,
  title                text        NOT NULL,
  description          text,
  platform_use         text,
  file_url             text,
  related_trade_id     text,
  related_client_id    uuid,
  sensitivity          text        NOT NULL DEFAULT 'internal',
  approved_for_content boolean     NOT NULL DEFAULT false,
  approved_for_sales   boolean     NOT NULL DEFAULT false,
  created_at           timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS proof_vault_created_at_idx  ON proof_vault (created_at DESC);
CREATE INDEX IF NOT EXISTS proof_vault_sensitivity_idx ON proof_vault (sensitivity);


-- ── 3. INCIDENTS ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS incidents (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  title             text        NOT NULL,
  severity          text        NOT NULL DEFAULT 'INFO',
  status            text        NOT NULL DEFAULT 'open',
  source            text,
  incident_type     text,
  summary           text,
  root_cause        text,
  fix_applied       text,
  prevention_layer  text,
  lesson_learned    text,
  content_angle     text,
  related_event_ids jsonb,
  opened_at         timestamptz NOT NULL DEFAULT now(),
  resolved_at       timestamptz
);

CREATE INDEX IF NOT EXISTS incidents_status_idx    ON incidents (status);
CREATE INDEX IF NOT EXISTS incidents_severity_idx  ON incidents (severity);
CREATE INDEX IF NOT EXISTS incidents_opened_at_idx ON incidents (opened_at DESC);


-- ── 4. ALERT ROUTES ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS alert_routes (
  id                       uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  severity                 text        NOT NULL,
  channel                  text        NOT NULL,
  destination              text,
  cooldown_minutes         integer     NOT NULL DEFAULT 15,
  escalation_after_minutes integer     NOT NULL DEFAULT 30,
  enabled                  boolean     NOT NULL DEFAULT true,
  created_at               timestamptz NOT NULL DEFAULT now()
);

INSERT INTO alert_routes (severity, channel, destination, cooldown_minutes, escalation_after_minutes)
SELECT * FROM (VALUES
  ('INFO',      'log_only',          'daily_report',        0,  0),
  ('WARNING',   'discord',           'ops-alerts',         15, 30),
  ('CRITICAL',  'discord+email',     'ops-alerts+founder', 10, 20),
  ('EMERGENCY', 'discord+email+sms', 'all',                 5, 10)
) AS v(severity, channel, destination, cooldown_minutes, escalation_after_minutes)
WHERE NOT EXISTS (SELECT 1 FROM alert_routes LIMIT 1);


-- ── 5. SUPPRESSED ALERTS ─────────────────────────────────────

CREATE TABLE IF NOT EXISTS suppressed_alerts (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  fingerprint  text        NOT NULL UNIQUE,
  severity     text,
  count        integer     NOT NULL DEFAULT 1,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  escalated    boolean     NOT NULL DEFAULT false,
  expires_at   timestamptz
);

CREATE INDEX IF NOT EXISTS suppressed_alerts_fp_idx ON suppressed_alerts (fingerprint);


-- ── 6. SYSTEM HEALTH EVENTS ──────────────────────────────────

CREATE TABLE IF NOT EXISTS system_health_events (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  severity    text        NOT NULL DEFAULT 'INFO',
  source      text,
  event_type  text,
  message     text,
  payload     jsonb,
  resolved    boolean     NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS system_health_events_at_idx  ON system_health_events (occurred_at DESC);
CREATE INDEX IF NOT EXISTS system_health_events_sev_idx ON system_health_events (severity);


-- ── 7. CONTENT QUEUE ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS content_queue (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  platform      text        NOT NULL,
  content_type  text        NOT NULL DEFAULT 'post',
  preview_text  text,
  full_content  text,
  status        text        NOT NULL DEFAULT 'draft',
  approved_by   text,
  approved_at   timestamptz,
  published_at  timestamptz,
  source_letter text,
  n8n_run_id    text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS content_queue_platform_idx ON content_queue (platform);
CREATE INDEX IF NOT EXISTS content_queue_status_idx   ON content_queue (status);
CREATE INDEX IF NOT EXISTS content_queue_created_idx  ON content_queue (created_at DESC);


-- ── 8. DAILY CADENCE LOGS ────────────────────────────────────

CREATE TABLE IF NOT EXISTS daily_cadence_logs (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  log_date     date        NOT NULL DEFAULT CURRENT_DATE,
  item_key     text        NOT NULL,
  item_label   text,
  completed    boolean     NOT NULL DEFAULT false,
  completed_at timestamptz,
  notes        text,
  UNIQUE (log_date, item_key)
);

CREATE INDEX IF NOT EXISTS daily_cadence_logs_date_idx ON daily_cadence_logs (log_date DESC);

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


-- ── 9. AP SYSTEM CONTROL (bot health center) ─────────────────

CREATE TABLE IF NOT EXISTS ap_system_control (
  id                   integer     PRIMARY KEY DEFAULT 1,
  global_killswitch    boolean     NOT NULL DEFAULT false,
  global_entriespaused boolean     NOT NULL DEFAULT false,
  reason               text,
  updated_at           timestamptz,
  updated_by           text,
  CONSTRAINT ap_system_control_single_row CHECK (id = 1)
);

INSERT INTO ap_system_control (id) VALUES (1) ON CONFLICT DO NOTHING;


-- ── 10. AP ADMIN AUDIT (bot health center) ───────────────────

CREATE TABLE IF NOT EXISTS ap_admin_audit (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  action     text        NOT NULL,
  actor      text,
  target     text,
  payload    jsonb       NOT NULL DEFAULT '{}',
  result     jsonb       NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ap_admin_audit_created_at_idx ON ap_admin_audit (created_at DESC);


-- ── 11. RLS — enable on all new tables ───────────────────────
-- n8n uses service_role key which bypasses RLS automatically.
-- Dashboard API (ap-ops-agents) also uses service_role key.

ALTER TABLE proof_vault          ENABLE ROW LEVEL SECURITY;
ALTER TABLE incidents            ENABLE ROW LEVEL SECURITY;
ALTER TABLE alert_routes         ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppressed_alerts    ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_health_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_queue        ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_cadence_logs   ENABLE ROW LEVEL SECURITY;
ALTER TABLE ap_system_control    ENABLE ROW LEVEL SECURITY;
ALTER TABLE ap_admin_audit       ENABLE ROW LEVEL SECURITY;

-- ── DONE ─────────────────────────────────────────────────────
