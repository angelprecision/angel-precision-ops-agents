# Angel Precision Ops — API Reference

Base URL: `https://ap-ops-agents.onrender.com`  
Auth: `X-API-Key: <OPS_API_KEY>` on every request.

## Dashboard Read Endpoints

| Method | Path | Dashboard Tab | Description |
|--------|------|---------------|-------------|
| GET | `/api/overview` | Overview | Summary counts for all sections |
| GET | `/api/leads` | Sales | Lead list + hot/warm/cold counts. `?temperature=hot` |
| GET | `/api/content-queue` | Content | Queue items + per-platform last published. `?status=pending_approval` |
| GET | `/api/bot-ops` | Bot Ops | Recent health events + warning/critical counts |
| GET | `/api/clients` | Clients | Client list + active/onboarding/paused/kill-switch counts |
| GET | `/api/proof-vault` | Proof Vault | Artifacts + total/approved counts |
| GET | `/api/incidents` | Incidents | Incident list + open/resolved/critical counts |
| GET | `/api/escalations` | Escalations | Alert routes + suppressed alerts |
| GET | `/api/cadence` | Daily Cadence | Today's items + 7-day completion rates |

## n8n Write Endpoints

| Method | Path | n8n Workflow | Description |
|--------|------|--------------|-------------|
| POST | `/api/leads` | `inbound_lead_capture_agent` | Create/upsert lead by email |
| POST | `/api/content-queue` | `content_agent` | Submit draft for approval |
| POST | `/api/content-queue/:id/approve` | Manual / n8n | Approve content item |
| POST | `/api/content-queue/:id/reject` | Manual / n8n | Reject content item |
| POST | `/api/incidents` | `daily_ops_agent` | Log new incident |
| PUT | `/api/incidents/:id` | `daily_ops_agent` | Resolve/update incident |
| POST | `/api/proof-vault` | Any agent | Save proof artifact |
| POST | `/api/health-event` | Bot / n8n | Log system health event |
| POST | `/api/cadence/complete` | Dashboard / n8n | Mark cadence item done |

## Supabase Tables Used

| Table | Written by | Read by |
|-------|-----------|---------|
| `leads` | n8n `inbound_lead_capture_agent` | Sales tab |
| `content_queue` | n8n `content_agent` | Content tab |
| `system_health_events` | n8n `daily_ops_agent`, bot | Bot Ops tab |
| `clients` | Manual / onboarding | Clients tab |
| `proof_vault` | n8n agents, manual | Proof Vault tab |
| `incidents` | n8n `daily_ops_agent`, manual | Incidents tab |
| `alert_routes` | Schema seed | Escalations tab |
| `suppressed_alerts` | Alerting system | Escalations tab |
| `daily_cadence_logs` | Schema seed, dashboard | Daily Cadence tab |

## n8n HTTP Request Node — Example

```json
{
  "method": "POST",
  "url": "https://ap-ops-agents.onrender.com/api/leads",
  "headers": {
    "X-API-Key": "{{ $env.OPS_API_KEY }}",
    "Content-Type": "application/json"
  },
  "body": {
    "email": "{{ $json.email }}",
    "name": "{{ $json.name }}",
    "source": "typeform",
    "temperature": "warm",
    "estimated_seriousness": "high",
    "last_engagement_score": 80
  }
}
```

## Environment Variables (Render)

```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_SERVICE_KEY=eyJ...
OPS_API_KEY=<generate with: openssl rand -hex 32>
PORT=8080
```
