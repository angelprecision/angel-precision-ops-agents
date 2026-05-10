# n8n Node-by-Node Install Guide

## Goal
Connect Gmail, Supabase, OpenAI, Google Calendar, and alerts into one working agent system tonight.

## Before you start
You need:
- Supabase project
- n8n instance running
- Gmail / Google Workspace account
- OpenAI API key
- Discord or Slack webhook
- Google Calendar booking link

## Step 1 — n8n setup
1. Log into n8n.
2. Open Settings -> Variables / Credentials.
3. Add credentials for OpenAI, Gmail OAuth2, Supabase, and Discord/Slack.
4. Set timezone to America/Los_Angeles.

## Step 2 — Gmail OAuth credential
1. Create a new Gmail OAuth2 credential in n8n.
2. Paste Google client id and secret.
3. Use the n8n redirect URL in Google Cloud OAuth settings.
4. Authorize the Gmail account.
5. Test access with draft scope.

## Step 3 — Supabase credential
Option A: use Supabase node.
Option B: use HTTP Request node with service role key.

For fast setup:
1. Create a generic HTTP header auth credential.
2. Header name: `apikey`
3. Header value: your service role key.
4. Also add `Authorization: Bearer <service-role-key>` where needed.

## Step 4 — OpenAI credential
1. Create OpenAI credential in n8n.
2. Paste API key.
3. Test with a simple chat node.

## Step 5 — Discord/Slack alert credential
1. Create webhook connection.
2. Send a test message.

# Workflow 1 — Sales Inbox Agent

## Nodes
1. Gmail Trigger
2. IF Agent Enabled
3. Supabase Upsert Lead
4. Supabase Insert Lead Message
5. OpenAI Classify Reply
6. OpenAI Draft Response
7. Gmail Create Draft
8. Discord/Slack Notify Founder
9. Supabase Insert Agent Run

## Configuration
### 1) Gmail Trigger
- Node type: Gmail Trigger
- Event: new email
- Filter: inbox or dedicated sales label
- Frequency: every 1-2 minutes

### 2) IF Agent Enabled
- Node type: HTTP Request or Supabase
- Query `agent_config` where key = enabled
- Continue only if value.enabled = true

### 3) Upsert Lead
- Table: `leads`
- Match on: email
- Map fields: name, email, source='gmail', updated_at=now()

### 4) Insert Lead Message
- Table: `lead_messages`
- direction: inbound
- channel: email
- subject/body from Gmail

### 5) OpenAI Classify Reply
- Model: gpt-4.1-mini
- Prompt: use Sales Inbox Agent classifier from prompts.md
- Output: JSON only

### 6) OpenAI Draft Response
- Model: gpt-4.1
- Prompt: Sales Inbox Agent draft prompt
- Include last inbound message + classification + safe pricing posture + booking link

### 7) Gmail Create Draft
- To: sender email
- Subject: original subject or reply format
- Body: suggested_reply

### 8) Notify Founder
- Send summary: lead name, classification, risk level, draft created

### 9) Insert Agent Run
- Table: `agent_runs`
- Store input/output/status

# Workflow 2 — Follow-Up Agent

## Nodes
1. Schedule Trigger
2. IF Agent Enabled
3. Supabase Fetch Due Leads
4. OpenAI Draft Follow-Up
5. Gmail Create Draft
6. Supabase Update Next Followup
7. Supabase Insert Agent Run

## Schedule
- Every 6 hours

## Query filter
- `next_followup_at <= now()`
- `status not in ('rejected','paid','do_not_contact')`

# Workflow 3 — Content Agent

## Nodes
1. Schedule Trigger
2. IF Agent Enabled
3. Supabase Fetch Ops Notes
4. OpenAI Generate Platform Posts
5. Code / Split node to separate platforms
6. Supabase Insert Content Queue rows
7. Notify Founder
8. Supabase Insert Agent Run

## Platforms generated
- x_post
- reddit_post
- linkedin_post
- facebook_post
- medium_post
- substack_post

# Workflow 4 — Daily Ops Agent

## Nodes
1. Daily Trigger 4:15 PM PT
2. IF Agent Enabled
3. Supabase Get Health Events
4. Supabase Get Clients
5. OpenAI Summarize Ops
6. Gmail Send Report
7. Discord/Slack Send Alert Summary
8. Supabase Insert Agent Run

# Workflow 5 — Prospect Research Agent

## Nodes
1. Schedule Trigger or Manual Trigger
2. IF Agent Enabled
3. Supabase Fetch New Prospects
4. OpenAI Research Fit
5. OpenAI Draft Outreach
6. Supabase Save Draft
7. Notify Founder
8. Insert Agent Run

## Use
Run manually tonight on your first 10 loaded prospects.

# Workflow 6 — Inbound Lead Capture Agent

## Nodes
1. Webhook
2. IF Agent Enabled
3. Supabase Upsert Lead
4. OpenAI Classify Lead
5. Gmail Send Confirmation
6. Notify Founder
7. Insert Agent Run

## Landing form fields
- name
- email
- account_size_band
- goals
- risk_tolerance
- source

# Recommended node notes
- Keep OpenAI outputs JSON-only.
- Add error handling branch for every workflow.
- Log failures into `agent_runs` with `status='error'`.
- Start with workflows inactive, test each manually, then activate one by one.
