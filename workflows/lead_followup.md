# Lead Follow-Up Workflow

## Objective
Maintain consistent lead communication without sounding needy, spammy, or hype-driven.

## Trigger
Runs every 6 hours.

## Pull Conditions
Fetch leads where:
- next_followup_at <= now()
- status not in (Closed Won, Closed Lost, Do Not Contact)

## Workflow
1. Pull due leads.
2. Pull previous messages.
3. Classify current lead state.
4. Generate follow-up draft.
5. Create Gmail draft.
6. Log draft to lead_messages.
7. Move next_followup_at forward.
8. Notify founder if lead_score >= threshold.

## Message Types
### Day 2
Light touch.
Short reminder.
Invite fit call.

### Day 4
Clarify system positioning.
Mention operational focus.
Invite conversation.

### Day 7
Polite close-the-loop.
Offer future reconnection.

## High Priority Triggers
Escalate immediately if lead asks about:
- pricing
- proof
- performance
- legal/compliance
- account handling
- onboarding

## Required Tone
- calm
- precise
- confident
- no hype
- no desperation

## Goal
Consistency > aggressiveness.
The objective is trust accumulation.
