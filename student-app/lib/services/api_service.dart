import 'dart:convert';
import 'package:http/http.dart' as http;

/// HTTP client for communicating with the teacher's local Flask server.
class ApiService {
  String? _baseUrl;

  /// Set the server base URL from QR payload.
  void setBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
  }

  /// Step 1: Verify scanned QR token with the server.
  Future<Map<String, dynamic>> verifyQr({
    required String studentId,
    required String token,
    required int timestamp,
  }) async {
    return _post('/api/verify/qr', {
      'student_id': studentId,
      'token': token,
      'timestamp': timestamp,
    });
  }

  /// Step 2: Verify Wi-Fi BSSID.
  Future<Map<String, dynamic>> verifyWifi({
    required String studentId,
    required String sessionId,
    required String bssid,
  }) async {
    return _post('/api/verify/wifi', {
      'student_id': studentId,
      'session_id': sessionId,
      'bssid': bssid,
    });
  }

  /// Step 3: Verify BLE proximity token.
  Future<Map<String, dynamic>> verifyBle({
    required String studentId,
    required String sessionId,
    required String bleToken,
    required int hopCount,
  }) async {
    return _post('/api/verify/ble', {
      'student_id': studentId,
      'session_id': sessionId,
      'ble_token': bleToken,
      'hop_count': hopCount,
    });
  }

  /// Step 4 (final): Confirm biometric verification.
  Future<Map<String, dynamic>> verifyBiometric({
    required String studentId,
    required String sessionId,
    required bool biometricVerified,
    required String deviceId,
    String? studentName,
  }) async {
    return _post('/api/verify/biometric', {
      'student_id': studentId,
      'session_id': sessionId,
      'biometric_verified': biometricVerified,
      'device_id': deviceId,
      'student_name': studentName ?? '',
    });
  }

  /// Request manual attendance approval from teacher.
  Future<Map<String, dynamic>> requestManualAttendance({
    required String studentId,
    required String studentName,
    required String sessionId,
    required String reason,
  }) async {
    return _post('/api/attendance/request-manual', {
      'student_id': studentId,
      'student_name': studentName,
      'session_id': sessionId,
      'reason': reason,
    });
  }

  /// Fallback: fetch BLE token over HTTP if BLE scanning fails.
  Future<Map<String, dynamic>> getBleTokenFallback() async {
    return _get('/api/ble/current-token');
  }

  // ─── Internal HTTP helpers ──────────────────────────────

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    if (_baseUrl == null) {
      return {'error': 'Server not connected. Scan QR first.'};
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'error': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    if (_baseUrl == null) {
      return {'error': 'Server not connected. Scan QR first.'};
    }

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl$path'))
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'error': 'Network error: ${e.toString()}'};
    }
  }
}
