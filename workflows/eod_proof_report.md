# End Of Day Proof Report Workflow

## Objective
Convert daily operational/trading activity into:
- founder reports
- client-safe summaries
- LinkedIn drafts
- X drafts
- Discord updates
- proof library entries
- lead follow-up snippets

This workflow is the bridge between:
trading -> proof -> content -> trust -> sales.

## Trigger
Cron:
- Monday-Friday
- 4:15 PM PT

## Data Sources
- proof_trades
- orders
- positions
- daily_trade_stats
- system_health_events
- incident_log
- founder_ops_notes

## Required Checks
- total trades processed
- rejected trades
- manual vs bot exits
- stale order count
- execution delays
- health severity events
- unresolved incidents

## Steps
1. Pull daily proof_trades.
2. Pull orders and positions.
3. Pull health and incident events.
4. Generate operational summary.
5. Generate founder-facing report.
6. Generate client-safe summary.
7. Generate X/LinkedIn/Discord drafts.
8. Store drafts in content_queue.
9. Store proof summary in daily_proof_reports.
10. Notify founder in Discord or Slack.

## Outputs
### Founder Report
Includes:
- operational health
- major issues
- wins
- execution observations
- next engineering priority

### Content Drafts
Must emphasize:
- execution quality
- monitoring
- risk controls
- system refinement
- operational lessons

Never emphasize:
- guaranteed profit
- unrealistic gains
- passive income

## Severity Model
INFO
WARNING
CRITICAL
EMERGENCY

CRITICAL or EMERGENCY automatically page founder.

## Future Expansion
- client PDF reports
- auto-generated screenshots
- proof vault indexing
- investor/operator weekly summaries
