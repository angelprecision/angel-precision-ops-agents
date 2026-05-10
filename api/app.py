"""
Angel Precision Ops — Backend API
===================================
Serves the command-center dashboard and accepts n8n webhook writes.

Deploy as a separate Render web service: ap-ops-agents.onrender.com
All routes require X-API-Key header matching OPS_API_KEY env var.

Environment variables:
  SUPABASE_URL          — Supabase project URL
  SUPABASE_SERVICE_KEY  — service_role key (bypasses RLS)
  OPS_API_KEY           — secret key for this API
"""
from __future__ import annotations

import os
import time
from datetime import date, datetime, timezone
from functools import wraps

from flask import Flask, jsonify, request
from flask_cors import CORS
from supabase import create_client

app = Flask(__name__)
CORS(app)

# ── Supabase ──────────────────────────────────────────────────
SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_KEY = os.environ["SUPABASE_SERVICE_KEY"]
sb = create_client(SUPABASE_URL, SUPABASE_KEY)

OPS_API_KEY = os.getenv("OPS_API_KEY", "")


# ── Auth ──────────────────────────────────────────────────────
def require_api_key(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        if OPS_API_KEY:
            key = request.headers.get("X-API-Key", "")
            if key != OPS_API_KEY:
                return jsonify({"ok": False, "error": "unauthorized"}), 401
        return fn(*args, **kwargs)
    return wrapper


def _now():
    return datetime.now(timezone.utc).isoformat()


# ═══════════════════════════════════════════════════════════════
# DASHBOARD READ ENDPOINTS
# ═══════════════════════════════════════════════════════════════

@app.get("/api/overview")
@require_api_key
def overview():
    """Summary counts for the overview tab."""
    try:
        leads_res   = sb.table("leads").select("id,temperature", count="exact").execute()
        clients_res = sb.table("clients").select("id,status", count="exact").execute()
        vault_res   = sb.table("proof_vault").select("id,approved_for_content,approved_for_sales",
                                                       count="exact").execute()
        incidents_res = sb.table("incidents").select("id,status,severity",
                                                      count="exact").execute()

        leads   = leads_res.data   or []
        clients = clients_res.data or []
        vault   = vault_res.data   or []
        incs    = incidents_res.data or []

        return jsonify({
            "ok": True,
            "leads": {
                "total": len(leads),
                "hot":   sum(1 for l in leads if l.get("temperature") == "hot"),
                "warm":  sum(1 for l in leads if l.get("temperature") == "warm"),
                "cold":  sum(1 for l in leads if l.get("temperature") == "cold"),
            },
            "clients": {
                "total":       len(clients),
                "active":      sum(1 for c in clients if c.get("status") == "active"),
                "onboarding":  sum(1 for c in clients if c.get("status") == "onboarding"),
                "paused":      sum(1 for c in clients if c.get("status") == "paused"),
            },
            "proof_vault": {
                "total":             len(vault),
                "content_approved":  sum(1 for v in vault if v.get("approved_for_content")),
                "sales_approved":    sum(1 for v in vault if v.get("approved_for_sales")),
            },
            "incidents": {
                "open":     sum(1 for i in incs if i.get("status") == "open"),
                "critical": sum(1 for i in incs if i.get("severity") == "CRITICAL"),
                "emergency":sum(1 for i in incs if i.get("severity") == "EMERGENCY"),
            },
        })
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.get("/api/leads")
@require_api_key
def get_leads():
    """Sales pipeline — lead list + pipeline counts."""
    try:
        limit = min(int(request.args.get("limit", 50)), 200)
        temp  = request.args.get("temperature")

        q = sb.table("leads").select("*").order("last_engagement_at", desc=True).limit(limit)
        if temp:
            q = q.eq("temperature", temp)

        res   = q.execute()
        leads = res.data or []

        hot  = sum(1 for l in leads if l.get("temperature") == "hot")
        warm = sum(1 for l in leads if l.get("temperature") == "warm")
        cold = sum(1 for l in leads if l.get("temperature") == "cold")
        scores = [l.get("last_engagement_score", 0) for l in leads if l.get("last_engagement_score")]
        avg_score = round(sum(scores) / len(scores), 1) if scores else None

        return jsonify({
            "ok": True,
            "leads": leads,
            "summary": {"hot": hot, "warm": warm, "cold": cold, "avg_score": avg_score},
        })
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.get("/api/content-queue")
@require_api_key
def get_content_queue():
    """Content queue — per-platform last post + pending approval items."""
    try:
        limit = min(int(request.args.get("limit", 50)), 200)
        status = request.args.get("status")

        q = sb.table("content_queue").select("*").order("created_at", desc=True).limit(limit)
        if status:
            q = q.eq("status", status)

        res   = q.execute()
        items = res.data or []

        # Last published per platform
        by_platform: dict[str, str | None] = {}
        for item in items:
            p  = item.get("platform", "")
            ts = item.get("published_at")
            if p and ts:
                existing = by_platform.get(p)
                if existing is None or ts > existing:
                    by_platform[p] = ts

        pending = [i for i in items if i.get("status") == "pending_approval"]

        return jsonify({
            "ok": True,
            "items": items,
            "platform_last_published": by_platform,
            "pending_approval": pending,
            "pending_count": len(pending),
        })
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.post("/api/content-queue/<item_id>/approve")
@require_api_key
def approve_content(item_id: str):
    """Approve a content queue item for publishing."""
    try:
        data = request.get_json(silent=True) or {}
        sb.table("content_queue").update({
            "status":      "approved",
            "approved_by": data.get("approved_by", "operator"),
            "approved_at": _now(),
        }).eq("id", item_id).execute()
        return jsonify({"ok": True, "id": item_id, "status": "approved"})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.post("/api/content-queue/<item_id>/reject")
@require_api_key
def reject_content(item_id: str):
    """Reject a content queue item."""
    try:
        sb.table("content_queue").update({"status": "rejected"}).eq("id", item_id).execute()
        return jsonify({"ok": True, "id": item_id, "status": "rejected"})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.get("/api/bot-ops")
@require_api_key
def bot_ops():
    """Bot operations tab — recent health events + status summary."""
    try:
        limit = min(int(request.args.get("limit", 50)), 200)
        res   = (
            sb.table("system_health_events")
            .select("*")
            .order("occurred_at", desc=True)
            .limit(limit)
            .execute()
        )
        events   = res.data or []
        warnings  = sum(1 for e in events if e.get("severity") == "WARNING")
        criticals = sum(1 for e in events if e.get("severity") == "CRITICAL")

        return jsonify({
            "ok":       True,
            "events":   events,
            "summary":  {
                "total":    len(events),
                "warnings": warnings,
                "critical": criticals,
            },
        })
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.get("/api/clients")
@require_api_key
def get_clients():
    """Client list with status counts."""
    try:
        res     = sb.table("clients").select("*").order("created_at", desc=True).execute()
        clients = res.data or []
        return jsonify({
            "ok":     True,
            "clients": clients,
            "summary": {
                "total":       len(clients),
                "active":      sum(1 for c in clients if c.get("status") == "active"),
                "onboarding":  sum(1 for c in clients if c.get("status") == "onboarding"),
                "paused":      sum(1 for c in clients if c.get("status") == "paused"),
                "kill_switch": sum(1 for c in clients if c.get("kill_switch")),
            },
        })
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.get("/api/proof-vault")
@require_api_key
def get_proof_vault():
    """Proof vault artifacts + approval counts."""
    try:
        limit = min(int(request.args.get("limit", 50)), 200)
        today = date.today().isoformat()

        res       = sb.table("proof_vault").select("*").order("created_at", desc=True).limit(limit).execute()
        artifacts = res.data or []

        return jsonify({
            "ok":        True,
            "artifacts": artifacts,
            "summary": {
                "total":             len(artifacts),
                "content_approved":  sum(1 for a in artifacts if a.get("approved_for_content")),
                "sales_approved":    sum(1 for a in artifacts if a.get("approved_for_sales")),
                "saved_today":       sum(1 for a in artifacts
                                        if (a.get("created_at") or "")[:10] == today),
            },
        })
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.get("/api/incidents")
@require_api_key
def get_incidents():
    """Incident list + status/severity counts."""
    try:
        res  = sb.table("incidents").select("*").order("opened_at", desc=True).execute()
        incs = res.data or []
        return jsonify({
            "ok":       True,
            "incidents": incs,
            "summary": {
                "open":      sum(1 for i in incs if i.get("status") == "open"),
                "resolved":  sum(1 for i in incs if i.get("status") == "resolved"),
                "critical":  sum(1 for i in incs if i.get("severity") == "CRITICAL"),
                "emergency": sum(1 for i in incs if i.get("severity") == "EMERGENCY"),
            },
        })
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.get("/api/escalations")
@require_api_key
def get_escalations():
    """Alert routes + suppressed alerts."""
    try:
        routes_res   = sb.table("alert_routes").select("*").order("severity").execute()
        suppress_res = sb.table("suppressed_alerts").select("*").order("last_seen_at", desc=True).execute()
        return jsonify({
            "ok":               True,
            "routes":           routes_res.data or [],
            "suppressed_alerts":suppress_res.data or [],
        })
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.get("/api/cadence")
@require_api_key
def get_cadence():
    """Daily cadence items for today + week summary."""
    try:
        today = date.today().isoformat()
        today_res = (
            sb.table("daily_cadence_logs")
            .select("*")
            .eq("log_date", today)
            .execute()
        )

        # Week summary — last 7 days completion rate per item
        week_res = (
            sb.table("daily_cadence_logs")
            .select("log_date,item_key,completed")
            .gte("log_date", str(date.fromordinal(date.today().toordinal() - 6)))
            .execute()
        )
        week = week_res.data or []

        by_key: dict[str, dict] = {}
        for row in week:
            k = row.get("item_key", "")
            if k not in by_key:
                by_key[k] = {"completed": 0, "total": 0}
            by_key[k]["total"] += 1
            if row.get("completed"):
                by_key[k]["completed"] += 1

        return jsonify({
            "ok":       True,
            "today":    today_res.data or [],
            "week_summary": {k: {"rate": round(v["completed"]/v["total"]*100)}
                             for k, v in by_key.items() if v["total"]},
        })
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


# ═══════════════════════════════════════════════════════════════
# n8n WRITE ENDPOINTS
# ═══════════════════════════════════════════════════════════════

@app.post("/api/leads")
@require_api_key
def upsert_lead():
    """n8n: create or update a lead."""
    try:
        data = request.get_json(silent=True) or {}
        email = (data.get("email") or "").strip().lower()
        if not email:
            return jsonify({"ok": False, "error": "email required"}), 400

        payload = {
            "email":                  email,
            "name":                   data.get("name"),
            "source":                 data.get("source"),
            "status":                 data.get("status", "new"),
            "temperature":            data.get("temperature", "cold"),
            "estimated_seriousness":  data.get("estimated_seriousness", "unknown"),
            "time_to_close_estimate": data.get("time_to_close_estimate", "unknown"),
            "last_engagement_score":  data.get("last_engagement_score", 0),
            "last_engagement_at":     _now(),
            "next_action":            data.get("next_action"),
            "notes":                  data.get("notes"),
        }

        res = sb.table("leads").upsert(payload, on_conflict="email").execute()
        return jsonify({"ok": True, "lead": (res.data or [None])[0]})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.post("/api/content-queue")
@require_api_key
def create_content():
    """n8n content agent: submit a content draft for approval."""
    try:
        data = request.get_json(silent=True) or {}
        platform = (data.get("platform") or "").lower()
        if not platform:
            return jsonify({"ok": False, "error": "platform required"}), 400

        payload = {
            "platform":      platform,
            "content_type":  data.get("content_type", "post"),
            "preview_text":  data.get("preview_text"),
            "full_content":  data.get("full_content"),
            "status":        "pending_approval",
            "source_letter": data.get("source_letter"),
            "n8n_run_id":    data.get("n8n_run_id"),
            "created_at":    _now(),
        }

        res = sb.table("content_queue").insert(payload).execute()
        return jsonify({"ok": True, "item": (res.data or [None])[0]})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.post("/api/incidents")
@require_api_key
def create_incident():
    """n8n or manual: log a new incident."""
    try:
        data = request.get_json(silent=True) or {}
        if not data.get("title"):
            return jsonify({"ok": False, "error": "title required"}), 400

        payload = {
            "title":            data["title"],
            "severity":         data.get("severity", "INFO"),
            "status":           data.get("status", "open"),
            "source":           data.get("source"),
            "incident_type":    data.get("incident_type"),
            "summary":          data.get("summary"),
            "root_cause":       data.get("root_cause"),
            "fix_applied":      data.get("fix_applied"),
            "prevention_layer": data.get("prevention_layer"),
            "lesson_learned":   data.get("lesson_learned"),
            "content_angle":    data.get("content_angle"),
            "related_event_ids":data.get("related_event_ids"),
            "opened_at":        _now(),
        }

        res = sb.table("incidents").insert(payload).execute()
        return jsonify({"ok": True, "incident": (res.data or [None])[0]})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.put("/api/incidents/<incident_id>")
@require_api_key
def update_incident(incident_id: str):
    """Resolve or update an incident."""
    try:
        data = request.get_json(silent=True) or {}
        update: dict = {}
        for field in ("status","severity","root_cause","fix_applied",
                      "prevention_layer","lesson_learned","content_angle"):
            if field in data:
                update[field] = data[field]
        if data.get("status") in ("resolved", "closed") and "resolved_at" not in update:
            update["resolved_at"] = _now()

        res = sb.table("incidents").update(update).eq("id", incident_id).execute()
        return jsonify({"ok": True, "incident": (res.data or [None])[0]})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.post("/api/proof-vault")
@require_api_key
def create_proof_artifact():
    """n8n or manual: save a proof artifact."""
    try:
        data = request.get_json(silent=True) or {}
        if not data.get("title") or not data.get("artifact_type"):
            return jsonify({"ok": False, "error": "title and artifact_type required"}), 400

        payload = {
            "artifact_type":        data["artifact_type"],
            "title":                data["title"],
            "description":          data.get("description"),
            "platform_use":         data.get("platform_use"),
            "file_url":             data.get("file_url"),
            "related_trade_id":     data.get("related_trade_id"),
            "related_client_id":    data.get("related_client_id"),
            "sensitivity":          data.get("sensitivity", "internal"),
            "approved_for_content": bool(data.get("approved_for_content", False)),
            "approved_for_sales":   bool(data.get("approved_for_sales", False)),
            "created_at":           _now(),
        }

        res = sb.table("proof_vault").insert(payload).execute()
        return jsonify({"ok": True, "artifact": (res.data or [None])[0]})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.post("/api/health-event")
@require_api_key
def log_health_event():
    """n8n or bot: log a system health event (bot ops tab)."""
    try:
        data = request.get_json(silent=True) or {}
        payload = {
            "severity":   data.get("severity", "INFO"),
            "source":     data.get("source"),
            "event_type": data.get("event_type"),
            "message":    data.get("message"),
            "payload":    data.get("payload"),
            "resolved":   bool(data.get("resolved", False)),
            "occurred_at":_now(),
        }
        res = sb.table("system_health_events").insert(payload).execute()
        return jsonify({"ok": True, "event": (res.data or [None])[0]})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.post("/api/cadence/complete")
@require_api_key
def complete_cadence_item():
    """Mark a cadence item done for today."""
    try:
        data = request.get_json(silent=True) or {}
        key  = (data.get("item_key") or "").strip()
        if not key:
            return jsonify({"ok": False, "error": "item_key required"}), 400

        today = date.today().isoformat()

        # Ensure today's row exists first
        sb.table("daily_cadence_logs").upsert(
            {"log_date": today, "item_key": key},
            on_conflict="log_date,item_key",
        ).execute()

        res = sb.table("daily_cadence_logs").update({
            "completed":    True,
            "completed_at": _now(),
        }).eq("log_date", today).eq("item_key", key).execute()

        return jsonify({"ok": True, "item": (res.data or [None])[0]})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


# ── Health ────────────────────────────────────────────────────
@app.get("/health")
def health():
    return jsonify({"ok": True, "service": "ap-ops-agents", "ts": _now()})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 8080)), debug=False)
