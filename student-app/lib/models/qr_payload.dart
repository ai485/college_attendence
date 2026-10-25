import 'dart:convert';

/// Model representing the payload encoded in the dynamic QR code.
class QrPayload {
  final String sessionId;
  final String token;
  final int timestamp;
  final String serverIp;
  final int serverPort;

  QrPayload({
    required this.sessionId,
    required this.token,
    required this.timestamp,
    required this.serverIp,
    required this.serverPort,
  });

  /// Parse from the JSON string embedded in the QR code.
  factory QrPayload.fromQrString(String qrData) {
    final map = jsonDecode(qrData) as Map<String, dynamic>;
    return QrPayload(
      sessionId: map['sid'] as String,
      token: map['tok'] as String,
      timestamp: map['ts'] as int,
      serverIp: map['ip'] as String,
      serverPort: map['port'] as int,
    );
  }

  /// Base URL for the teacher's local server.
  String get baseUrl => 'http://$serverIp:$serverPort';

  Map<String, dynamic> toJson() => {
        'sid': sessionId,
        'tok': token,
        'ts': timestamp,
        'ip': serverIp,
        'port': serverPort,
      };

  @override
  String toString() => 'QrPayload(session=$sessionId, server=$serverIp:$serverPort)';
}
