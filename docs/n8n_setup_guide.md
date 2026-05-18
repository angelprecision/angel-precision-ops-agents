# Angel Precision — N8N Agent Setup Guide

## What's built

4 workflows that run the company automatically:

| Workflow | Schedule | What it does |
|---|---|---|
| `master_content_engine` | 8:00 AM ET Mon–Fri | Pulls proof data → Claude → LinkedIn/X drafts → Discord preview |
| `eod_proof_engine` | 4:15 PM ET Mon–Fri | Today's trades → Claude → EOD Discord report + content queue |
| `premarket_brief` | 8:30 AM ET Mon–Fri | Bot health + overnight signals → Discord brief |
| `content_approval_publisher` | Webhook-triggered | Approve → auto-post to LinkedIn/X |

## Step 1 — Run Supabase SQL

```sql
-- content_queue table (stores all generated content)
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
```

## Step 2 — Set N8N credentials

In N8N → Settings → Credentials, add:

**Supabase API**
- URL: `https://jhawzqnhcihevkhehogm.supabase.co`
- Service Key: your service role key

**HTTP Header Auth** (for Anthropic)
- Header: `x-api-key`
- Value: your Anthropic API key

## Step 3 — Set N8N environment variables

In N8N → Settings → Environment Variables:

```
SUPABASE_URL         = https://jhawzqnhcihevkhehogm.supabase.co
ANTHROPIC_API_KEY    = your key
AP_BOT_URL           = https://angel-precision-bot-official-1.onrender.com
DISCORD_WEBHOOK_BOT  = your discord webhook for #bot-alerts
DISCORD_WEBHOOK_CONTENT = your discord webhook for #content-queue
LINKEDIN_ACCESS_TOKEN = your token
LINKEDIN_PERSON_ID   = your person ID
TWITTER_BEARER_TOKEN = your token
```

## Step 4 — Import workflows

In N8N → Workflows → Import from File:

1. `workflows/premarket_brief.json`
2. `workflows/master_content_engine.json`
3. `workflows/eod_proof_engine.json`
4. `workflows/content_approval_publisher.json`

Activate in this order — premarket first, EOD second, content engine third.

## Step 5 — Discord channels

Create two Discord webhooks:
- `#bot-operations` — bot health, pre-market brief, EOD report
- `#content-queue` — daily content drafts, publish confirmations

## Step 6 — Approve and publish

Every morning you get a Discord preview in `#content-queue`:
```
📝 Content Ready for Approval — Monday, May 18

Theme: Execution discipline and morning readiness

LinkedIn Morning:
[draft post]

X Morning:
[draft post]

✅ Approve in Content Queue to auto-post.
```

To publish, call the webhook:
```bash
curl -X POST https://your-n8n.com/webhook/ap-approve-content \
  -H "Content-Type: application/json" \
  -d '{"content_id": 1, "platform": "linkedin", "text": "your approved text"}'
```

Or add an approval button to your admin dashboard that hits this webhook.

## How Claude generates content

All 3 agents use `claude-opus-4-5` with strict brand rules:
- Never guarantee returns
- Never promise passive income
- Always emphasize monitored execution
- Founder-led, technical, calm tone
- Separate bot behavior from market outcome

Content themes rotate by day:
- Monday: readiness + market open discipline
- Tuesday: execution quality + rejection logic
- Wednesday: founder lesson + technical fix
- Thursday: trust layer + client safety
- Friday: weekly proof + next build priority
