"""
WebSocket events for real-time QR code push and attendance updates.
"""
import time
import threading
from flask_socketio import emit
from app.qr_generator import qr_manager
import config


def register_socketio_events(socketio):
    """Register all WebSocket event handlers."""

    qr_thread = None
    qr_running = False

    @socketio.on("connect")
    def handle_connect():
        print(f"  🔗 WebSocket client connected")
        emit("connected", {"status": "ok"})

    @socketio.on("disconnect")
    def handle_disconnect():
        print(f"  🔌 WebSocket client disconnected")

    @socketio.on("start_qr_stream")
    def handle_start_qr(data=None):
        """Start streaming QR codes to connected clients."""
        nonlocal qr_thread, qr_running

        if qr_running:
            return

        qr_running = True

        def qr_loop():
            nonlocal qr_running
            while qr_running:
                try:
                    b64 = qr_manager.generate_qr_image_base64()
                    if b64:
                        socketio.emit("qr_update", {
                            "image": b64,
                            "timestamp": int(time.time() * 1000)
                        })
                except Exception as e:
                    print(f"  ⚠️  QR generation error: {e}")
                time.sleep(config.QR_INTERVAL_SECONDS)

        qr_thread = threading.Thread(target=qr_loop, daemon=True)
        qr_thread.start()
        emit("qr_stream_started", {"interval": config.QR_INTERVAL_SECONDS})

    @socketio.on("stop_qr_stream")
    def handle_stop_qr(data=None):
        nonlocal qr_running
        qr_running = False
        emit("qr_stream_stopped", {})
