"""
Dashboard routes - Teacher-facing web interface.
"""
from flask import Blueprint, render_template, request, redirect, url_for, session, jsonify
from app.database import get_db
import config

dashboard_bp = Blueprint("dashboard", __name__)


@dashboard_bp.route("/")
def index():
    """Dashboard home page."""
    return render_template("dashboard.html")


@dashboard_bp.route("/qr")
def qr_display():
    """Full-screen QR code projection page."""
    return render_template("qr_display.html")


@dashboard_bp.route("/rooms")
def room_setup():
    """Room BSSID configuration page."""
    return render_template("room_setup.html")
