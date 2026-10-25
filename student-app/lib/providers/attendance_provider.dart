import 'package:flutter/foundation.dart';
import '../models/qr_payload.dart';
import '../models/verification_state.dart';
import '../services/api_service.dart';
import '../services/wifi_service.dart';
import '../services/ble_service.dart';
import '../services/biometric_service.dart';
import '../services/storage_service.dart';
import '../config.dart';

/// Orchestrates the entire attendance verification pipeline.
///
/// Flow: QR Scan → Wi-Fi BSSID → BLE Proximity → Biometrics → Done
class AttendanceProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final WifiService _wifi = WifiService();
  final BleService _ble = BleService();
  final BiometricService _biometric = BiometricService();
  final StorageService _storage = StorageService();

  QrPayload? _qrPayload;
  final VerificationState _state = VerificationState();
  bool _isProcessing = false;
  String? _resultMessage;
  bool _attendanceMarked = false;

  // ─── Getters ─────────────────────────────────────────────

  VerificationState get state => _state;
  bool get isProcessing => _isProcessing;
  String? get resultMessage => _resultMessage;
  bool get attendanceMarked => _attendanceMarked;
  QrPayload? get qrPayload => _qrPayload;
  StorageService get storage => _storage;

  // ─── Pipeline ────────────────────────────────────────────

  /// Start the full verification pipeline after QR is scanned.
  Future<void> startVerification(QrPayload payload) async {
    _qrPayload = payload;
    _state.reset();
    _isProcessing = true;
    _attendanceMarked = false;
    _resultMessage = null;
    notifyListeners();

    // Set server URL from QR payload
    _api.setBaseUrl(payload.baseUrl);

    // Step 1: Verify QR token
    await _verifyQr(payload);
    if (_state.hasFailed) return;

    // Step 2: Verify Wi-Fi BSSID
    await _verifyWifi();
    if (_state.hasFailed) return;

    // Step 3: Verify BLE Proximity
    await _verifyBle();
    if (_state.hasFailed) return;

    // Step 4: Biometric
    await _verifyBiometric();
  }

  /// Step 1: Verify the QR token with the teacher's server.
  Future<void> _verifyQr(QrPayload payload) async {
    _state.updateStep(VerificationStep.qr, StepStatus.inProgress);
    notifyListeners();

    final studentId = await _storage.getStudentId() ?? '';
    final result = await _api.verifyQr(
      studentId: studentId,
      token: payload.token,
      timestamp: payload.timestamp,
    );

    if (result['valid'] == true) {
      _state.sessionId = result['session_id'] as String?;
      _state.updateStep(VerificationStep.qr, StepStatus.success);
    } else {
      _state.updateStep(VerificationStep.qr, StepStatus.failed);
      _state.errorMessage =
          result['error'] as String? ?? 'QR code expired. Try scanning again.';
      _isProcessing = false;
    }
    notifyListeners();
  }

  /// Step 2: Verify Wi-Fi BSSID matches the classroom router.
  Future<void> _verifyWifi() async {
    _state.updateStep(VerificationStep.wifi, StepStatus.inProgress);
    notifyListeners();

    final bssid = await _wifi.getCurrentBssid();
    if (bssid == null) {
      _state.updateStep(VerificationStep.wifi, StepStatus.failed);
      _state.errorMessage =
          'Could not read Wi-Fi info. Make sure you are connected to the classroom Wi-Fi and location permission is granted.';
      _isProcessing = false;
      notifyListeners();
      return;
    }

    final studentId = await _storage.getStudentId() ?? '';
    final sessionId = _state.sessionId ?? _qrPayload!.sessionId;

    final result = await _api.verifyWifi(
      studentId: studentId,
      sessionId: sessionId,
      bssid: bssid,
    );

    if (result['valid'] == true) {
      _state.updateStep(VerificationStep.wifi, StepStatus.success);
    } else {
      _state.updateStep(VerificationStep.wifi, StepStatus.failed);
      _state.errorMessage =
          result['error'] as String? ?? 'Wi-Fi verification failed. You may not be connected to the classroom router.';
      _isProcessing = false;
    }
    notifyListeners();
  }

  /// Step 3: Verify Bluetooth proximity.
  Future<void> _verifyBle() async {
    _state.updateStep(VerificationStep.ble, StepStatus.inProgress);
    notifyListeners();

    // First try BLE scanning
    final bleResult = await _ble.scanForBeacon(
      timeout: AppConfig.bleScanTimeoutSeconds,
    );

    String? bleToken;
    int hopCount = 0;

    if (bleResult.found && bleResult.bleToken != null) {
      bleToken = bleResult.bleToken;
      hopCount = bleResult.hopCount;
    } else {
      // Fallback: fetch BLE token via HTTP (Wi-Fi based proximity)
      final fallback = await _api.getBleTokenFallback();
      if (fallback['ble_token'] != null) {
        bleToken = fallback['ble_token'] as String;
        hopCount = 0; // Direct from server
      }
    }

    if (bleToken == null) {
      _state.updateStep(VerificationStep.ble, StepStatus.failed);
      _state.errorMessage =
          'Bluetooth proximity check failed. Make sure Bluetooth is on and you are in the classroom.';
      _isProcessing = false;
      notifyListeners();
      return;
    }

    final studentId = await _storage.getStudentId() ?? '';
    final sessionId = _state.sessionId ?? _qrPayload!.sessionId;

    final result = await _api.verifyBle(
      studentId: studentId,
      sessionId: sessionId,
      bleToken: bleToken,
      hopCount: hopCount,
    );

    if (result['valid'] == true) {
      _state.updateStep(VerificationStep.ble, StepStatus.success);
    } else {
      _state.updateStep(VerificationStep.ble, StepStatus.failed);
      _state.errorMessage =
          result['error'] as String? ?? 'Bluetooth verification failed.';
      _isProcessing = false;
    }
    notifyListeners();
  }

  /// Step 4: Biometric verification (final step).
  Future<void> _verifyBiometric() async {
    _state.updateStep(VerificationStep.biometric, StepStatus.inProgress);
    notifyListeners();

    final available = await _biometric.isAvailable();

    if (!available) {
      // If no biometrics available, skip and note it
      _state.updateStep(VerificationStep.biometric, StepStatus.skipped);
      _state.errorMessage = 'Biometrics not available on this device. Proceeding without.';
    } else {
      final authenticated = await _biometric.authenticate();
      if (!authenticated) {
        _state.updateStep(VerificationStep.biometric, StepStatus.failed);
        _state.errorMessage = 'Biometric verification failed or cancelled.';
        _isProcessing = false;
        notifyListeners();
        return;
      }
      _state.updateStep(VerificationStep.biometric, StepStatus.success);
    }

    // Submit final verification to server
    final studentId = await _storage.getStudentId() ?? '';
    final studentName = await _storage.getStudentName() ?? '';
    final deviceId = await _storage.getDeviceId();
    final sessionId = _state.sessionId ?? _qrPayload!.sessionId;

    final result = await _api.verifyBiometric(
      studentId: studentId,
      sessionId: sessionId,
      biometricVerified: true,
      deviceId: deviceId,
      studentName: studentName,
    );

    if (result['attendance_marked'] == true) {
      _attendanceMarked = true;
      _resultMessage = 'Attendance marked successfully!';
    } else {
      _resultMessage = result['error'] as String? ?? 'Failed to mark attendance.';
    }

    _isProcessing = false;
    notifyListeners();
  }

  // ─── Manual Request ──────────────────────────────────────

  /// Request manual attendance when automated checks fail.
  Future<bool> requestManualAttendance(String reason) async {
    final studentId = await _storage.getStudentId() ?? '';
    final studentName = await _storage.getStudentName() ?? '';
    final sessionId = _state.sessionId ?? _qrPayload?.sessionId ?? '';

    if (sessionId.isEmpty) return false;

    final result = await _api.requestManualAttendance(
      studentId: studentId,
      studentName: studentName,
      sessionId: sessionId,
      reason: reason,
    );

    if (result['requested'] == true) {
      _resultMessage = 'Manual attendance request sent to teacher. Please wait for approval.';
      notifyListeners();
      return true;
    }

    _resultMessage = result['error'] as String? ?? 'Failed to send request.';
    notifyListeners();
    return false;
  }

  /// Reset everything for a new attempt.
  void reset() {
    _qrPayload = null;
    _state.reset();
    _isProcessing = false;
    _resultMessage = null;
    _attendanceMarked = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _ble.dispose();
    super.dispose();
  }
}
