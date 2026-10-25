"""
Configuration settings for the Teacher Desktop Application.
"""
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Server settings
SERVER_PORT = int(os.environ.get("SERVER_PORT", 5000))
SERVER_HOST = os.environ.get("SERVER_HOST", "0.0.0.0")

# Security and session
SECRET_KEY = os.environ.get("SECRET_KEY", "teacher-app-secret-key-39048f0e-c28b-4a57")

# Dynamic QR code rotation settings
QR_INTERVAL_SECONDS = int(os.environ.get("QR_INTERVAL_SECONDS", 5))
QR_GRACE_PERIOD_SECONDS = int(os.environ.get("QR_GRACE_PERIOD_SECONDS", 2))

# BLE beacon rotation settings
BLE_TOKEN_INTERVAL_SECONDS = int(os.environ.get("BLE_TOKEN_INTERVAL_SECONDS", 10))
BLE_MAX_HOPS = int(os.environ.get("BLE_MAX_HOPS", 2))

# Teacher authentication (bcrypt hash)
TEACHER_PASSWORD_HASH = os.environ.get("TEACHER_PASSWORD_HASH", "")

# SQLite Database path
DATABASE_PATH = os.environ.get("DATABASE_PATH", os.path.join(BASE_DIR, "attendance.db"))
