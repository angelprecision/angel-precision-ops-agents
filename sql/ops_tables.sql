-- Angel Precision Ops Tables

create table if not exists leads (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  full_name text,
  email text unique,
  phone text,
  linkedin text,
  discord text,
  source text,
  status text,
  lead_score integer default 0,
  account_size_band text,
  broker text,
  goals text,
  risk_tolerance text,
  notes text,
  last_contacted_at timestamptz,
  next_followup_at timestamptz,
  assigned_to text,
  booking_link_sent boolean default false
);

create table if not exists lead_messages (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  lead_id uuid references leads(id),
  direction text,
  subject text,
  body text,
  classification text,
  risk_level text,
  requires_approval boolean default true
);

create table if not exists content_queue (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  platform text,
  title text,
  content text,
  cta text,
  status text default 'draft',
  source_note text,
  risk_flag boolean default false,
  approved_by text,
  posted_url text
);

create table if not exists daily_proof_reports (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  report_date date,
  founder_summary text,
  client_summary text,
  trades_processed integer,
  rejected_trades integer,
  incidents integer,
  warnings integer,
  blockers integer,
  ready_state text
);

create table if not exists incident_log (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  severity text,
  classification text,
  summary text,
  human_action text,
  resolved boolean default false,
  resolved_at timestamptz
);
