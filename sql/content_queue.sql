-- Content Queue — stores all Claude-generated content pending approval
CREATE TABLE IF NOT EXISTS content_queue (
  id              bigserial PRIMARY KEY,
  linkedin_morning text,
  linkedin_afternoon text,
  x_morning       text,
  x_afternoon     text,
  theme           text,
  generated_at    date,
  status          text NOT NULL DEFAULT 'PENDING_APPROVAL',
  approval_required boolean DEFAULT true,
  safe_to_share   boolean DEFAULT false,
  published_at    timestamptz,
  created_at      timestamptz DEFAULT now()
);

-- Index for dashboard queries
CREATE INDEX IF NOT EXISTS idx_content_queue_status ON content_queue(status);
CREATE INDEX IF NOT EXISTS idx_content_queue_date ON content_queue(generated_at);
