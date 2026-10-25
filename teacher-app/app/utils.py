"""
Cryptographic, network, and utility helpers for Teacher Desktop Application.
"""
import socket
import hmac
import hashlib
import time
import re
from datetime import datetime
import bcrypt

def get_local_ip() -> str:
    """
    Determine the primary local LAN IP address of this machine.
    Falls back to hostname resolution or localhost if network unreachable.
    """
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0.5)
        # 8.8.8.8:80 doesn't actually initiate a connection, but OS chooses the outgoing LAN interface
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        try:
            return socket.gethostbyname(socket.gethostname())
        except Exception:
            return "127.0.0.1"

def get_current_timestamp_ms() -> int:
    """Return current Unix epoch time in milliseconds."""
    return int(time.time() * 1000)

def generate_hmac(secret: str, data: str) -> str:
    """Generate SHA256 HMAC digest in hex."""
    return hmac.new(
        secret.encode("utf-8"),
        data.encode("utf-8"),
        hashlib.sha256
    ).hexdigest()

def verify_hmac(secret: str, data: str, expected_hmac: str) -> bool:
    """Securely compare calculated HMAC with expected HMAC string."""
    calculated = generate_hmac(secret, data)
    return hmac.compare_digest(calculated, expected_hmac)

def hash_password(password: str) -> str:
    """Hash a password using bcrypt."""
    salt = bcrypt.gensalt(rounds=12)
    return bcrypt.hashpw(password.encode("utf-8"), salt).decode("utf-8")

def check_password(password: str, hashed: str) -> bool:
    """Verify password against bcrypt hash."""
    if not hashed or not password:
        return False
    try:
        return bcrypt.checkpw(password.encode("utf-8"), hashed.encode("utf-8"))
    except Exception:
        return False

def normalize_bssid(bssid: str) -> str:
    """
    Normalize MAC/BSSID address to standard uppercase colon-separated format.
    E.g., 'aa-bb-cc-dd-ee-ff' or 'aabbccddeeff' -> 'AA:BB:CC:DD:EE:FF'
    """
    if not bssid:
        return ""
    clean = re.sub(r"[^0-9A-Fa-f]", "", bssid.strip()).upper()
    if len(clean) == 12:
        return ":".join(clean[i:i+2] for i in range(0, 12, 2))
    return bssid.strip().upper()

def is_bssid_allowed(student_bssid: str, whitelist: list) -> bool:
    """Check if the student BSSID matches any entry in the room whitelist."""
    norm_student = normalize_bssid(student_bssid)
    if not norm_student:
        return False
    for allowed in whitelist:
        if normalize_bssid(str(allowed)) == norm_student:
            return True
    return False

def format_timestamp(dt: datetime = None) -> str:
    """Format datetime for display."""
    if dt is None:
        dt = datetime.now()
    return dt.strftime("%Y-%m-%d %H:%M:%S")
