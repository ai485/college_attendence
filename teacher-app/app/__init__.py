"""
Flask application factory and initialization.
"""
from flask import Flask
from flask_socketio import SocketIO
from flask_cors import CORS
import config
from app.database import close_db


socketio = SocketIO(cors_allowed_origins="*", async_mode="threading")


def create_app():
    """Create and configure the Flask application."""
    app = Flask(
        __name__,
        static_folder="../static",
        template_folder="../templates"
    )

    app.config["SECRET_KEY"] = config.SECRET_KEY
    app.config["DATABASE_PATH"] = config.DATABASE_PATH

    # Enable CORS for student app requests
    CORS(app)

    # Register teardown
    app.teardown_appcontext(close_db)

    # Register blueprints
    from app.routes.dashboard import dashboard_bp
    from app.routes.api import api_bp
    from app.routes.ws import register_socketio_events

    app.register_blueprint(dashboard_bp)
    app.register_blueprint(api_bp, url_prefix="/api")

    # Initialize SocketIO
    socketio.init_app(app)
    register_socketio_events(socketio)

    return app, socketio
