# Rule

Do not optimize tonight.
Do not redesign tonight.
Goal = connected + visible + functioning.

# Tonight Execution Checklist

## Goal for tonight
By the end of tonight you should have:
- Supabase schema live
- Gmail OAuth connected to n8n
- OpenAI + Supabase + Gmail credentials configured
- Sales Inbox workflow imported and tested
- Follow-Up workflow imported
- Content workflow imported
- Daily Ops workflow imported
- Lead generation layer live
- Substack publication created
- One booking link live in Google Calendar

## Phase 1 — Supabase setup
1. Open Supabase SQL editor.
2. Run `supabase-schema.sql`.
3. Confirm tables exist: `agent_config`, `leads`, `lead_messages`, `ai_drafts`, `ops_notes`, `content_queue`, `clients`, `system_health_events`, `agent_runs`.
4. Confirm `agent_config` contains key `enabled`.
5. Create a private service role secret for n8n.

## Phase 2 — Gmail OAuth
1. Open Google Cloud Console.
2. Create project: `Angel Precision Agents`.
3. Enable Gmail API.
4. Configure OAuth consent screen.
5. Create OAuth client credentials.
6. Add your n8n redirect URI.
7. Copy client id and client secret into n8n credentials.
8. Test Gmail read + draft scopes.

## Phase 3 — n8n credentials
Create these credentials in n8n:
- Gmail OAuth2
- OpenAI API
- Supabase / Postgres HTTP credentials
- Discord or Slack webhook

Add environment values from `env.example`.

## Phase 4 — import workflows
Import in this order:
1. `n8n-sales-inbox-workflow.json`
2. `n8n-followup-workflow.json`
3. `n8n-content-workflow.json`
4. `n8n-daily-ops-workflow.json`
5. `n8n-prospect-research-workflow.json`
6. `n8n-inbound-lead-capture-workflow.json`

## Phase 5 — test Sales Inbox
Use 5 test emails:
- How much is it?
- How does this work?
- Can you guarantee anything?
- I want a call.
- Show me proof.

Expected result:
- lead row created/updated
- message stored
- classification returned
- Gmail draft created
- founder alert sent
- run logged

## Phase 6 — lead generation layer
1. Create waitlist form using the included landing page copy.
2. Route form submissions to Supabase and Gmail.
3. Add Google Calendar booking link to confirmation email and bio link.
4. Add 25 manual prospects tonight using `lead-list-template.csv`.
5. Run Prospect Research Agent on first 10 prospects.
6. Generate 5 custom outreach drafts.

## Phase 7 — content engine
1. Add 10 real ops notes.
2. Run Content Agent.
3. Approve 1 LinkedIn post, 2 X posts, 1 Substack welcome post, 1 Facebook post.
4. Save Reddit drafts for manual posting only.

## Phase 8 — daily ops
1. Insert sample health events.
2. Run Daily Ops workflow manually.
3. Confirm founder receives operator report.

## Phase 9 — Substack
1. Create publication using `substack-starter.md`.
2. Use the recommended About page.
3. Publish the welcome post.
4. Add booking link and waitlist link to publication footer.

## End-of-night checklist
- [ ] Supabase live
- [ ] n8n live
- [ ] Gmail draft creation working
- [ ] lead capture working
- [ ] booking link live
- [ ] Substack live
- [ ] first content queued
- [ ] first 25 prospects loaded
- [ ] 5 outreach drafts ready
- [ ] daily ops report tested
