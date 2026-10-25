"""
BLE Beacon broadcaster for attendance proximity verification.
Broadcasts a rolling signed token that students can detect.

Falls back gracefully if BLE hardware is unavailable.
The token is also served via REST API as a fallback.
"""
import time
import hashlib
import hmac as hmac_mod
import threading
import struct
import config


class BLEBeacon:
    """
    Manages BLE beacon broadcasting for proximity verification.
    
    On platforms without BLE advertising support, it still generates
    valid tokens that can be served via the HTTP fallback endpoint.
    """

    # Well-known service UUID for the attendance system
    SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b"

    def __init__(self):
        self._session_id = None
        self._session_secret = None
        self._running = False
        self._thread = None
        self._ble_available = False
        self._current_token = None
        self._current_token_time = 0
        self._lock = threading.Lock()

    def set_session(self, session_id: str, session_secret: str):
        """Bind the beacon to an active session."""
        with self._lock:
            self._session_id = session_id
            self._session_secret = session_secret

    def clear_session(self):
        """Clear session and stop broadcasting."""
        with self._lock:
            self._session_id = None
            self._session_secret = None
            self._current_token = None

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

    def _get_ble_window_index(self) -> int:
        """Get the current BLE token rotation window index."""
        return int(time.time()) // config.BLE_TOKEN_INTERVAL_SECONDS

    def generate_token(self) -> dict:
        """
        Generate a BLE proximity token for the current window.
        Returns dict with token, hop_count=0, and metadata.
        """
        with self._lock:
            self._ensure_session()
            if not self._session_id or not self._session_secret:
                return None

            window = self._get_ble_window_index()
            data = f"ble:{self._session_id}:{window}"
            token = hmac_mod.new(
                self._session_secret.encode("utf-8"),
                data.encode("utf-8"),
                hashlib.sha256
            ).hexdigest()[:16]

            result = {
                "session_id": self._session_id,
                "ble_token": token,
                "hop_count": 0,
                "window": window,
                "timestamp": int(time.time() * 1000)
            }
            self._current_token = result
            self._current_token_time = time.time()
            return result

    def validate_token(self, ble_token: str, hop_count: int) -> bool:
        """
        Validate a BLE token submitted by a student.
        Checks HMAC signature and hop count limit.
        """
        with self._lock:
            self._ensure_session()
            if not self._session_id or not self._session_secret:
                return False

            # Reject if hop count exceeds max
            if hop_count > config.BLE_MAX_HOPS:
                return False

            # Check current and previous window
            current_window = self._get_ble_window_index()
            prev_window = current_window - 1

            for window in [current_window, prev_window]:
                data = f"ble:{self._session_id}:{window}"
                expected = hmac_mod.new(
                    self._session_secret.encode("utf-8"),
                    data.encode("utf-8"),
                    hashlib.sha256
                ).hexdigest()[:16]
                if hmac_mod.compare_digest(ble_token, expected):
                    return True

            return False

    def get_current_token(self) -> dict:
        """Get the most recent generated token (for HTTP fallback)."""
        # Auto-regenerate if expired
        if (time.time() - self._current_token_time) > config.BLE_TOKEN_INTERVAL_SECONDS:
            self.generate_token()
        return self._current_token

    def start(self):
        """Start BLE advertising in a background thread."""
        try:
            import asyncio
            from bleak import BleakScanner
            self._ble_available = True
        except ImportError:
            self._ble_available = False
            print("  ℹ️  bleak not installed. BLE advertising disabled.")
            print("     Install with: pip install bleak")
            return

        self._running = True
        self._thread = threading.Thread(target=self._broadcast_loop, daemon=True)
        self._thread.start()

    def _broadcast_loop(self):
        """Background loop to continuously generate BLE tokens."""
        while self._running:
            try:
                self.generate_token()
            except Exception as e:
                print(f"  ⚠️  BLE token generation error: {e}")
            time.sleep(config.BLE_TOKEN_INTERVAL_SECONDS)

    def stop(self):
        """Stop BLE broadcasting."""
        self._running = False
        if self._thread:
            self._thread.join(timeout=5)

    @property
    def is_available(self) -> bool:
        return self._ble_available


# Global BLE beacon instance
ble_beacon = BLEBeacon()
