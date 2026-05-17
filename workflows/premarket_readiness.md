# Premarket Readiness Workflow

## Objective
Determine whether Angel Precision is operationally safe to trade before market open.

This workflow exists to prevent live deployment during degraded or unsafe states.

## Trigger
Cron:
- Monday-Friday
- 5:45 AM PT
- 6:10 AM PT

## Systems Checked
### Backend
GET /health
GET /admin/client-readiness

### Bot Layer
- scanner status
- overnight reeval status
- queue health
- contract selector
- fill monitor
- reconciler
- exit engine
- position manager

### Broker Layer
- Tradier connectivity
- account mode
- stale orders
- open exits pending
- auth validity

### Safety Layer
- kill switch state
- entries paused state
- emergency flatten availability
- duplicate setup protection

## Output States
### READY
All systems operational.

### WARNING
Minor issue exists but deployment may continue with caution.

### NOT_READY
Trading should not begin.

### EMERGENCY
Critical operational issue detected.

## Founder Actions
Each report must include:
- blockers
- warnings
- affected systems
- recommended human actions
- whether live clients should be blocked

## Example Output
```json
{
  "status": "WARNING",
  "blockers": [],
  "warnings": [
    "Fill monitor latency elevated"
  ],
  "live_client_ready": false,
  "founder_actions": [
    "Restart fill monitor",
    "Verify order reconciliation before market open"
  ]
}
```
