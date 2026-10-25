"""
Dynamic QR code generation with HMAC-signed tokens.
Tokens rotate every QR_INTERVAL_SECONDS (default 5s).
"""
import time
import json
import io
import base64
import uuid
import hashlib
import hmac as hmac_mod
import qrcode
from qrcode.image.pil import PilImage
import config
from app.utils import get_local_ip


class QRTokenManager:
    """Manages rotating QR tokens for attendance sessions."""

    def __init__(self):
        self._session_id = None
        self._session_secret = None

    def set_session(self, session_id: str, session_secret: str):
        """Bind to an active session."""
        self._session_id = session_id
        self._session_secret = session_secret

    def clear_session(self):
        """Unbind from current session."""
        self._session_id = None
        self._session_secret = None

    def _ensure_session(self):
        """Lazy-load active session from SQLite if in-memory state is empty."""
        if not self._session_id or not self._session_secret:
            try:
                from app.database import connect_db
                conn = connect_db()
                row = conn.execute("SELECT id, session_secret FROM sessions WHERE is_active = 1").fetchone()
                if row:
                    self._session_id = row["id"]
                    self._session_secret = row["session_secret"]
                conn.close()
            except Exception:
                pass

    def _get_window_index(self, timestamp_ms: int = None) -> int:
        """Get the time window index for a given timestamp."""
        ts = timestamp_ms or int(time.time() * 1000)
        return ts // (config.QR_INTERVAL_SECONDS * 1000)

    def generate_token(self) -> dict:
        """
        Generate a signed QR token for the current time window.
        Returns dict with session_id, token, timestamp, server info.
        """
        self._ensure_session()
        if not self._session_id or not self._session_secret:
            return None

        ts_ms = int(time.time() * 1000)
        window = self._get_window_index(ts_ms)

        # Create HMAC-signed token from session_secret + window index
        data = f"{self._session_id}:{window}"
        token = hmac_mod.new(
            self._session_secret.encode("utf-8"),
            data.encode("utf-8"),
            hashlib.sha256
        ).hexdigest()[:16]  # First 16 hex chars for compact QR

        ip = get_local_ip()

        payload = {
            "sid": self._session_id,
            "tok": token,
            "ts": ts_ms,
            "ip": ip,
            "port": config.SERVER_PORT
        }
        return payload

    def validate_token(self, token: str, timestamp_ms: int) -> bool:
        """
        Validate a scanned QR token against current and adjacent windows.
        Allows ±grace period windows for latency.
        """
        self._ensure_session()
        if not self._session_id or not self._session_secret:
            return False

        # Check current window and the immediately previous window
        now_ms = int(time.time() * 1000)
        grace_ms = config.QR_GRACE_PERIOD_SECONDS * 1000
        current_window = self._get_window_index(now_ms)
        prev_window = self._get_window_index(now_ms - config.QR_INTERVAL_SECONDS * 1000)

        for window in [current_window, prev_window]:
            data = f"{self._session_id}:{window}"
            expected = hmac_mod.new(
                self._session_secret.encode("utf-8"),
                data.encode("utf-8"),
                hashlib.sha256
            ).hexdigest()[:16]
            if hmac_mod.compare_digest(token, expected):
                return True

        return False

    def generate_qr_image_base64(self) -> str:
        """Generate QR code as base64 PNG string for WebSocket push."""
        payload = self.generate_token()
        if not payload:
            return None

        payload_str = json.dumps(payload, separators=(",", ":"))

        qr = qrcode.QRCode(
            version=None,
            error_correction=qrcode.constants.ERROR_CORRECT_M,
            box_size=12,
            border=4,
        )
        qr.add_data(payload_str)
        qr.make(fit=True)

        img = qr.make_image(fill_color="black", back_color="white")

        buf = io.BytesIO()
        img.save(buf, format="PNG")
        buf.seek(0)
        b64 = base64.b64encode(buf.getvalue()).decode("utf-8")
        return b64


# Global QR manager instance
qr_manager = QRTokenManager()
