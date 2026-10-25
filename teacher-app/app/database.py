"""
Database management and SQLite connection helpers.
"""
import sqlite3
import json
import os
from contextlib import contextmanager
from flask import g, current_app
import config

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS rooms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    room_number TEXT UNIQUE NOT NULL,
    bssid_whitelist TEXT NOT NULL  -- JSON array of allowed BSSIDs
);

CREATE TABLE IF NOT EXISTS students (
    id TEXT PRIMARY KEY,           -- Student ID / Roll number
    name TEXT NOT NULL,
    device_id TEXT                 -- Registered device fingerprint
);

CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,           -- UUID
    subject TEXT NOT NULL,
    room_number TEXT NOT NULL,
    started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    ended_at DATETIME,
    session_secret TEXT NOT NULL,  -- HMAC key for this session
    is_active BOOLEAN DEFAULT 1,
    FOREIGN KEY (room_number) REFERENCES rooms(room_number)
);

CREATE TABLE IF NOT EXISTS attendance (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    student_id TEXT NOT NULL,
    status TEXT DEFAULT 'pending', -- pending, qr_verified, wifi_verified, ble_verified, present, manual_requested, manual_approved, rejected
    qr_verified_at DATETIME,
    wifi_verified_at DATETIME,
    ble_verified_at DATETIME,
    biometric_verified_at DATETIME,
    marked_at DATETIME,
    FOREIGN KEY (session_id) REFERENCES sessions(id),
    FOREIGN KEY (student_id) REFERENCES students(id),
    UNIQUE(session_id, student_id)
);

CREATE TABLE IF NOT EXISTS manual_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    student_id TEXT NOT NULL,
    student_name TEXT,
    reason TEXT,
    status TEXT DEFAULT 'pending', -- pending, approved, rejected
    requested_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    resolved_at DATETIME,
    FOREIGN KEY (session_id) REFERENCES sessions(id)
);

CREATE TABLE IF NOT EXISTS app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
"""

def get_db_path():
    """Get the database path from Flask config or fallback to config module."""
    if current_app:
        return current_app.config.get("DATABASE_PATH", config.DATABASE_PATH)
    return config.DATABASE_PATH

def connect_db(db_path=None):
    """Create a raw database connection with row factory enabled."""
    path = db_path or get_db_path()
    conn = sqlite3.connect(path, timeout=10.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")
    return conn

def get_db():
    """
    Get the database connection for the current Flask application context.
    If outside of an active Flask request context, opens a new connection.
    """
    try:
        if "db" not in g:
            g.db = connect_db()
        return g.db
    except RuntimeError:
        # Outside Flask application/request context
        return connect_db()

def close_db(e=None):
    """Close the database connection at the end of the request."""
    db = g.pop("db", None) if hasattr(g, "db") else None
    if db is not None:
        try:
            db.close()
        except Exception:
            pass

@contextmanager
def db_session(db_path=None):
    """
    Context manager for database transactions, especially useful in background threads.
    Automatically commits on success or rolls back on exception.
    """
    conn = connect_db(db_path)
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

def init_db(db_path=None):
    """Initialize SQLite database tables and seed initial default data."""
    path = db_path or config.DATABASE_PATH
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    
    with sqlite3.connect(path) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        conn.executescript(SCHEMA_SQL)
        
        # Seed sample rooms if none exist
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM rooms")
        count = cursor.fetchone()[0]
        if count == 0:
            sample_rooms = [
                ("R201", json.dumps(["AA:BB:CC:DD:EE:01", "AA:BB:CC:DD:EE:02", "00:11:22:33:44:55"])),
                ("R202", json.dumps(["AA:BB:CC:DD:EE:03", "12:34:56:78:9A:BC"])),
                ("Lab-101", json.dumps(["F0:9F:C2:11:22:33", "C4:41:1E:55:66:77"]))
            ]
            cursor.executemany(
                "INSERT INTO rooms (room_number, bssid_whitelist) VALUES (?, ?)",
                sample_rooms
            )
            conn.commit()
