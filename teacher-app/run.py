"""
Entry point for the Teacher Desktop Application.
Run this script to start the attendance server.
"""
import sys
import os

# Add project root to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app
from app.database import init_db
from app.utils import get_local_ip
from app.ble_beacon import BLEBeacon
import config


def print_banner(ip, port):
    """Print startup banner with connection info."""
    print("\n" + "=" * 60)
    print("  📚 Attendance System - Teacher Dashboard")
    print("=" * 60)
    print(f"  🌐 Dashboard:   http://{ip}:{port}/")
    print(f"  📺 QR Projector: http://{ip}:{port}/qr")
    print(f"  🔗 Local IP:     {ip}")
    print(f"  🔌 Port:         {port}")
    print("=" * 60)
    print("  Students should connect to the same Wi-Fi network")
    print("  and scan the QR code displayed on the projector.")
    print("=" * 60 + "\n")


def main():
    # Initialize database
    init_db()
    print("✅ Database initialized.")

    # Create Flask app
    app, socketio = create_app()

    # Sync active session if already exists in DB
    try:
        from app.database import connect_db
        from app.qr_generator import qr_manager
        from app.ble_beacon import ble_beacon
        conn = connect_db()
        active = conn.execute("SELECT id, session_secret FROM sessions WHERE is_active = 1").fetchone()
        if active:
            qr_manager.set_session(active["id"], active["session_secret"])
            ble_beacon.set_session(active["id"], active["session_secret"])
            print(f"🔄 Restored active session: {active['id']}")
        conn.close()
    except Exception as e:
        print(f"⚠️  Session sync warning: {e}")

    # Get network info
    ip = get_local_ip()
    port = config.SERVER_PORT

    # Attempt to start BLE beacon (non-critical)
    ble = BLEBeacon()
    try:
        ble.start()
        print("✅ BLE Beacon started.")
    except Exception as e:
        print(f"⚠️  BLE Beacon unavailable: {e}")
        print("   (Students can use Wi-Fi fallback for BLE token)")

    print_banner(ip, port)

    # Run with SocketIO
    socketio.run(
        app,
        host=config.SERVER_HOST,
        port=port,
        debug=False,
        allow_unsafe_werkzeug=True
    )


if __name__ == "__main__":
    main()
