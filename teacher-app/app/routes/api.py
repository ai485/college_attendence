"""
REST API endpoints for student verification and attendance management.
"""
import json
import uuid
from datetime import datetime
from flask import Blueprint, request, jsonify
from app.database import get_db
from app.qr_generator import qr_manager
from app.ble_beacon import ble_beacon
from app.utils import normalize_bssid, is_bssid_allowed
import config

api_bp = Blueprint("api", __name__)


# ─── Session Management ─────────────────────────────────────────────

@api_bp.route("/session/start", methods=["POST"])
def start_session():
    """Start a new attendance session."""
    data = request.get_json() or {}
    subject = data.get("subject", "").strip()
    room_number = data.get("room_number", "").strip()

    if not subject or not room_number:
        return jsonify({"error": "subject and room_number are required"}), 400

    db = get_db()

    # Check room exists
    room = db.execute("SELECT * FROM rooms WHERE room_number = ?", (room_number,)).fetchone()
    if not room:
        return jsonify({"error": f"Room '{room_number}' not found. Add it in Room Setup first."}), 404

    # Stop any active session
    db.execute("UPDATE sessions SET is_active = 0, ended_at = ? WHERE is_active = 1",
               (datetime.now().isoformat(),))

    # Create new session
    session_id = str(uuid.uuid4())[:8]
    session_secret = str(uuid.uuid4())

    db.execute(
        "INSERT INTO sessions (id, subject, room_number, session_secret, is_active) VALUES (?, ?, ?, ?, 1)",
        (session_id, subject, room_number, session_secret)
    )
    db.commit()

    # Initialize QR and BLE managers
    qr_manager.set_session(session_id, session_secret)
    ble_beacon.set_session(session_id, session_secret)

    return jsonify({
        "session_id": session_id,
        "subject": subject,
        "room_number": room_number,
        "started_at": datetime.now().isoformat()
    })


@api_bp.route("/session/stop", methods=["POST"])
def stop_session():
    """Stop the current active session."""
    db = get_db()
    db.execute("UPDATE sessions SET is_active = 0, ended_at = ? WHERE is_active = 1",
               (datetime.now().isoformat(),))
    db.commit()

    qr_manager.clear_session()
    ble_beacon.clear_session()

    return jsonify({"stopped": True})


@api_bp.route("/session/active", methods=["GET"])
def get_active_session():
    """Get the currently active session info."""
    db = get_db()
    session = db.execute("SELECT * FROM sessions WHERE is_active = 1").fetchone()
    if not session:
        return jsonify({"active": False})

    # Synchronize in-memory managers with DB session
    qr_manager.set_session(session["id"], session["session_secret"])
    ble_beacon.set_session(session["id"], session["session_secret"])

    return jsonify({
        "active": True,
        "session_id": session["id"],
        "subject": session["subject"],
        "room_number": session["room_number"],
        "started_at": session["started_at"]
    })


@api_bp.route("/qr/current", methods=["GET"])
def get_current_qr():
    """Get the latest dynamic QR code image directly over HTTP (zero CDN/WebSocket dependency)."""
    db = get_db()
    session = db.execute("SELECT * FROM sessions WHERE is_active = 1").fetchone()
    if not session:
        return jsonify({"active": False, "error": "No active session"}), 404

    qr_manager.set_session(session["id"], session["session_secret"])
    b64 = qr_manager.generate_qr_image_base64()
    if not b64:
        return jsonify({"active": False, "error": "Failed to generate QR"}), 500

    import time
    return jsonify({
        "active": True,
        "image": b64,
        "session_id": session["id"],
        "subject": session["subject"],
        "room_number": session["room_number"],
        "timestamp": int(time.time() * 1000),
        "interval": config.QR_INTERVAL_SECONDS
    })


# ─── Student Verification Pipeline ──────────────────────────────────

def _ensure_attendance_row(db, session_id, student_id):
    """Create attendance row if not exists, auto-register student."""
    # Auto-register student if needed
    existing = db.execute("SELECT id FROM students WHERE id = ?", (student_id,)).fetchone()
    if not existing:
        db.execute("INSERT OR IGNORE INTO students (id, name) VALUES (?, ?)",
                   (student_id, student_id))

    row = db.execute(
        "SELECT * FROM attendance WHERE session_id = ? AND student_id = ?",
        (session_id, student_id)
    ).fetchone()
    if not row:
        db.execute(
            "INSERT INTO attendance (session_id, student_id, status) VALUES (?, ?, 'pending')",
            (session_id, student_id)
        )
        db.commit()


@api_bp.route("/verify/qr", methods=["POST"])
def verify_qr():
    """Step 1: Verify scanned QR token."""
    data = request.get_json() or {}
    student_id = data.get("student_id", "").strip()
    token = data.get("token", "").strip()
    timestamp = data.get("timestamp", 0)

    if not student_id or not token:
        return jsonify({"valid": False, "error": "student_id and token required"}), 400

    valid = qr_manager.validate_token(token, timestamp)

    if valid:
        db = get_db()
        session = db.execute("SELECT id FROM sessions WHERE is_active = 1").fetchone()
        if session:
            _ensure_attendance_row(db, session["id"], student_id)
            db.execute(
                "UPDATE attendance SET status = 'qr_verified', qr_verified_at = ? WHERE session_id = ? AND student_id = ?",
                (datetime.now().isoformat(), session["id"], student_id)
            )
            db.commit()

    return jsonify({
        "valid": valid,
        "step": "qr",
        "next": "wifi" if valid else None,
        "session_id": qr_manager._session_id if valid else None
    })


@api_bp.route("/verify/wifi", methods=["POST"])
def verify_wifi():
    """Step 2: Verify Wi-Fi BSSID matches classroom router."""
    data = request.get_json() or {}
    student_id = data.get("student_id", "").strip()
    session_id = data.get("session_id", "").strip()
    bssid = data.get("bssid", "").strip()

    if not student_id or not session_id or not bssid:
        return jsonify({"valid": False, "error": "student_id, session_id, and bssid required"}), 400

    db = get_db()

    # Get the room for this session
    session = db.execute("SELECT room_number FROM sessions WHERE id = ?", (session_id,)).fetchone()
    if not session:
        return jsonify({"valid": False, "error": "Session not found"}), 404

    # Get room BSSID whitelist
    room = db.execute("SELECT bssid_whitelist FROM rooms WHERE room_number = ?",
                      (session["room_number"],)).fetchone()
    if not room:
        return jsonify({"valid": False, "error": "Room config not found"}), 404

    whitelist = json.loads(room["bssid_whitelist"])
    valid = is_bssid_allowed(bssid, whitelist)

    if valid:
        db.execute(
            "UPDATE attendance SET status = 'wifi_verified', wifi_verified_at = ? WHERE session_id = ? AND student_id = ?",
            (datetime.now().isoformat(), session_id, student_id)
        )
        db.commit()

    return jsonify({
        "valid": valid,
        "step": "wifi",
        "next": "ble" if valid else None
    })


@api_bp.route("/verify/ble", methods=["POST"])
def verify_ble():
    """Step 3: Verify BLE proximity token."""
    data = request.get_json() or {}
    student_id = data.get("student_id", "").strip()
    session_id = data.get("session_id", "").strip()
    ble_token = data.get("ble_token", "").strip()
    hop_count = data.get("hop_count", 0)

    if not student_id or not session_id or not ble_token:
        return jsonify({"valid": False, "error": "student_id, session_id, and ble_token required"}), 400

    try:
        hop_count = int(hop_count)
    except (ValueError, TypeError):
        hop_count = 0

    valid = ble_beacon.validate_token(ble_token, hop_count)

    if valid:
        db = get_db()
        db.execute(
            "UPDATE attendance SET status = 'ble_verified', ble_verified_at = ? WHERE session_id = ? AND student_id = ?",
            (datetime.now().isoformat(), session_id, student_id)
        )
        db.commit()

    return jsonify({
        "valid": valid,
        "step": "ble",
        "next": "biometric" if valid else None
    })


@api_bp.route("/verify/biometric", methods=["POST"])
def verify_biometric():
    """Step 4 (final): Confirm biometric verification and mark present."""
    data = request.get_json() or {}
    student_id = data.get("student_id", "").strip()
    session_id = data.get("session_id", "").strip()
    biometric_verified = data.get("biometric_verified", False)
    device_id = data.get("device_id", "")
    student_name = data.get("student_name", "")

    if not student_id or not session_id:
        return jsonify({"valid": False, "error": "student_id and session_id required"}), 400

    if not biometric_verified:
        return jsonify({"valid": False, "error": "Biometric verification not confirmed"}), 400

    db = get_db()

    # Update student name and device_id if provided
    if student_name:
        db.execute("UPDATE students SET name = ? WHERE id = ?", (student_name, student_id))
    if device_id:
        db.execute("UPDATE students SET device_id = ? WHERE id = ?", (device_id, student_id))

    now = datetime.now().isoformat()
    db.execute(
        "UPDATE attendance SET status = 'present', biometric_verified_at = ?, marked_at = ? WHERE session_id = ? AND student_id = ?",
        (now, now, session_id, student_id)
    )
    db.commit()

    return jsonify({
        "attendance_marked": True,
        "status": "present",
        "student_id": student_id
    })


# ─── Manual Attendance ───────────────────────────────────────────────

@api_bp.route("/attendance/request-manual", methods=["POST"])
def request_manual():
    """Student requests manual attendance approval."""
    data = request.get_json() or {}
    student_id = data.get("student_id", "").strip()
    student_name = data.get("student_name", "").strip()
    session_id = data.get("session_id", "").strip()
    reason = data.get("reason", "").strip()

    if not student_id or not session_id:
        return jsonify({"error": "student_id and session_id required"}), 400

    db = get_db()

    # Auto-register student
    existing = db.execute("SELECT id FROM students WHERE id = ?", (student_id,)).fetchone()
    if not existing:
        db.execute("INSERT OR IGNORE INTO students (id, name) VALUES (?, ?)",
                   (student_id, student_name or student_id))

    _ensure_attendance_row(db, session_id, student_id)

    # Create manual request
    db.execute(
        "INSERT INTO manual_requests (session_id, student_id, student_name, reason) VALUES (?, ?, ?, ?)",
        (session_id, student_id, student_name or student_id, reason)
    )
    db.execute(
        "UPDATE attendance SET status = 'manual_requested' WHERE session_id = ? AND student_id = ?",
        (session_id, student_id)
    )
    db.commit()

    return jsonify({"requested": True, "message": "Manual attendance request sent to teacher."})


@api_bp.route("/attendance/approve-manual", methods=["POST"])
def approve_manual():
    """Teacher approves or rejects a manual request."""
    data = request.get_json() or {}
    request_id = data.get("request_id")
    approved = data.get("approved", False)

    if not request_id:
        return jsonify({"error": "request_id required"}), 400

    db = get_db()
    req = db.execute("SELECT * FROM manual_requests WHERE id = ?", (request_id,)).fetchone()
    if not req:
        return jsonify({"error": "Request not found"}), 404

    now = datetime.now().isoformat()
    new_status = "approved" if approved else "rejected"

    db.execute(
        "UPDATE manual_requests SET status = ?, resolved_at = ? WHERE id = ?",
        (new_status, now, request_id)
    )

    if approved:
        db.execute(
            "UPDATE attendance SET status = 'manual_approved', marked_at = ? WHERE session_id = ? AND student_id = ?",
            (now, req["session_id"], req["student_id"])
        )
    else:
        db.execute(
            "UPDATE attendance SET status = 'rejected' WHERE session_id = ? AND student_id = ?",
            (req["session_id"], req["student_id"])
        )

    db.commit()
    return jsonify({"approved": approved, "request_id": request_id})


@api_bp.route("/attendance/list", methods=["GET"])
def attendance_list():
    """Get attendance list for a session."""
    session_id = request.args.get("session_id", "")

    if not session_id:
        return jsonify({"error": "session_id query param required"}), 400

    db = get_db()
    rows = db.execute(
        """SELECT a.*, s.name as student_name 
           FROM attendance a 
           LEFT JOIN students s ON a.student_id = s.id
           WHERE a.session_id = ?
           ORDER BY a.marked_at DESC NULLS LAST""",
        (session_id,)
    ).fetchall()

    result = []
    for row in rows:
        result.append({
            "student_id": row["student_id"],
            "student_name": row["student_name"] or row["student_id"],
            "status": row["status"],
            "qr_verified_at": row["qr_verified_at"],
            "wifi_verified_at": row["wifi_verified_at"],
            "ble_verified_at": row["ble_verified_at"],
            "biometric_verified_at": row["biometric_verified_at"],
            "marked_at": row["marked_at"]
        })

    return jsonify({"attendance": result, "count": len(result)})


@api_bp.route("/attendance/manual-requests", methods=["GET"])
def manual_requests_list():
    """Get pending manual attendance requests."""
    session_id = request.args.get("session_id", "")
    db = get_db()

    if session_id:
        rows = db.execute(
            "SELECT * FROM manual_requests WHERE session_id = ? AND status = 'pending' ORDER BY requested_at DESC",
            (session_id,)
        ).fetchall()
    else:
        rows = db.execute(
            "SELECT * FROM manual_requests WHERE status = 'pending' ORDER BY requested_at DESC"
        ).fetchall()

    result = []
    for row in rows:
        result.append({
            "id": row["id"],
            "session_id": row["session_id"],
            "student_id": row["student_id"],
            "student_name": row["student_name"],
            "reason": row["reason"],
            "requested_at": row["requested_at"]
        })

    return jsonify({"requests": result})


# ─── BLE Token Fallback ──────────────────────────────────────────────

@api_bp.route("/ble/current-token", methods=["GET"])
def get_ble_token():
    """Fallback endpoint: serve current BLE token over HTTP."""
    token = ble_beacon.get_current_token()
    if not token:
        return jsonify({"error": "No active session"}), 404
    return jsonify(token)


# ─── Room Management ─────────────────────────────────────────────────

@api_bp.route("/rooms", methods=["GET"])
def list_rooms():
    """List all rooms."""
    db = get_db()
    rows = db.execute("SELECT * FROM rooms ORDER BY room_number").fetchall()
    result = []
    for row in rows:
        result.append({
            "id": row["id"],
            "room_number": row["room_number"],
            "bssid_whitelist": json.loads(row["bssid_whitelist"])
        })
    return jsonify({"rooms": result})


@api_bp.route("/rooms", methods=["POST"])
def add_room():
    """Add a new room with BSSID whitelist."""
    data = request.get_json() or {}
    room_number = data.get("room_number", "").strip()
    bssids = data.get("bssid_whitelist", [])

    if not room_number:
        return jsonify({"error": "room_number is required"}), 400

    # Normalize BSSIDs
    normalized = [normalize_bssid(b) for b in bssids if b.strip()]

    db = get_db()
    try:
        db.execute(
            "INSERT INTO rooms (room_number, bssid_whitelist) VALUES (?, ?)",
            (room_number, json.dumps(normalized))
        )
        db.commit()
    except Exception as e:
        if "UNIQUE" in str(e):
            return jsonify({"error": f"Room '{room_number}' already exists"}), 409
        raise

    return jsonify({"created": True, "room_number": room_number})


@api_bp.route("/rooms/<room_number>", methods=["PUT"])
def update_room(room_number):
    """Update a room's BSSID whitelist."""
    data = request.get_json() or {}
    bssids = data.get("bssid_whitelist", [])
    normalized = [normalize_bssid(b) for b in bssids if b.strip()]

    db = get_db()
    db.execute(
        "UPDATE rooms SET bssid_whitelist = ? WHERE room_number = ?",
        (json.dumps(normalized), room_number)
    )
    db.commit()
    return jsonify({"updated": True})


@api_bp.route("/rooms/<room_number>", methods=["DELETE"])
def delete_room(room_number):
    """Delete a room, checking for active sessions and cleaning up past session foreign keys."""
    db = get_db()

    # Check if this room currently has an active session
    active_session = db.execute(
        "SELECT id, subject FROM sessions WHERE room_number = ? AND is_active = 1",
        (room_number,)
    ).fetchone()
    if active_session:
        return jsonify({
            "error": f"Cannot delete '{room_number}' because an attendance session ('{active_session['subject']}') is currently active. Stop the session first."
        }), 400

    try:
        # Cascade clean up past ended sessions and attendance records for this room
        session_rows = db.execute("SELECT id FROM sessions WHERE room_number = ?", (room_number,)).fetchall()
        for s in session_rows:
            sid = s["id"]
            db.execute("DELETE FROM manual_requests WHERE session_id = ?", (sid,))
            db.execute("DELETE FROM attendance WHERE session_id = ?", (sid,))
        db.execute("DELETE FROM sessions WHERE room_number = ?", (room_number,))
        
        # Delete the room
        db.execute("DELETE FROM rooms WHERE room_number = ?", (room_number,))
        db.commit()
        return jsonify({"deleted": True, "room_number": room_number})
    except Exception as e:
        db.rollback()
        return jsonify({"error": f"Failed to delete room: {str(e)}"}), 500
