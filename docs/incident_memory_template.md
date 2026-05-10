
# Incident Memory Template

## Use this for every major system issue

```
Title:
Severity: INFO / WARNING / CRITICAL / EMERGENCY
Date:
System Area:
What Happened:
Impact:
Root Cause:
Immediate Fix:
Long-Term Prevention:
Proof Artifact:
Content Angle:
Status: open / resolved
```

## Incident categories
- queue cascade
- stale quotes
- execution blockage
- broker/API issue
- duplicate order risk
- fill monitor outage
- position mismatch
- scanner degradation
- reconciler mismatch
- kill switch issue
- latency degradation
- data feed interruption

## Example incident
```
Title: Initial queue visibility gap
Severity: WARNING
Date: 2026-05-08
System Area: Execution queue
What Happened: Queue status was not clearly surfaced in operator view during first live session
Impact: Delayed awareness of pending orders by ~4 minutes
Root Cause: Queue health not included in primary dashboard panel
Immediate Fix: Added queue health metrics to AP Health Center plan
Long-Term Prevention: Daily ops summary includes queue status; monitoring agent classifies queue delays
Proof Artifact: 2026-05-08_queue-visibility_gap-identified_internal
Content Angle: "Why monitoring is the real edge in automation"
Status: resolved
```

## Why incident memory matters
1. Improves the product through documented learning
2. Builds institutional knowledge
3. Creates content material (lessons from real operations)
4. Shows prospective clients that issues are caught and fixed, not hidden
5. Prevents the same failure from happening twice

## Daily rule
If something breaks or degrades today, document it before you sleep.
A sloppy founder hides incidents. A serious operator documents and prevents them.
