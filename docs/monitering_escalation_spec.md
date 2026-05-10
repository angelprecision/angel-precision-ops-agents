[monitoring-escalation-spec.md](https://github.com/user-attachments/files/27573896/monitoring-escalation-spec.md)
# Monitoring Agent Escalation Spec

## Routing model
```
INFO     -> log only, include in daily report
WARNING  -> Discord/Slack alert, 15-min cooldown, daily report
CRITICAL -> Discord + email immediately, 10-min cooldown, escalate if unresolved after 20 min
EMERGENCY -> Discord + email + SMS, no suppression (except identical within 5 min), escalate every 10 min until resolved
```

## Alert fingerprint
Create fingerprint from:
```
severity + source + event_type + normalized_message_hash
```

## Suppression rules
- Same fingerprint within cooldown period -> increment count, suppress duplicate
- Same fingerprint count > 3 within cooldown -> send clustered alert instead
- Critical unresolved past escalation timer -> re-alert with escalation flag
- Emergency -> never suppress unless identical within 5 minutes

## Clustered alert format
```
CRITICAL CLUSTER: [event_type]

Count: [N] in [timeframe]
Source: [source]
Likely issue: [classification]
Action: [human_action recommendation]
```

## n8n implementation
After the OpenAI classification node, add:
1. Switch node routing by severity
2. For WARNING/CRITICAL/EMERGENCY paths:
   a. HTTP Request to check `alert_suppression` table for existing fingerprint
   b. IF fingerprint exists and within cooldown -> update count, skip alert
   c. IF fingerprint is new or past cooldown -> send alert, upsert suppression row
   d. For CRITICAL: add a Wait node (20 min) -> re-check if resolved -> if not, escalate
   e. For EMERGENCY: skip suppression, alert all channels immediately

## Escalation path
```
Level 1: Discord/Slack notification
Level 2: Email to founder
Level 3: SMS/phone (if configured)
Level 4: Auto-pause affected client accounts (requires explicit opt-in, never default)
```

Level 4 is Tier 3 (never autonomous without explicit configuration).

## Alert route table
Pre-seeded in the SQL upgrade. Modify `alert_routes` to change channels, cooldowns, or escalation timers without code changes.
