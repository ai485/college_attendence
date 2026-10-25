/// App-wide constants and configuration.
class AppConfig {
  /// Default server port (matches teacher app config).
  static const int defaultServerPort = 5000;

  /// BLE service UUID for the attendance system.
  /// Must match the teacher app's BLE beacon UUID.
  static const String bleServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';

  /// Maximum allowed BLE hop count.
  static const int maxBleHops = 2;

  /// Timeout for BLE scanning before offering fallback (seconds).
  static const int bleScanTimeoutSeconds = 15;

  /// Timeout for QR scanning (seconds).
  static const int qrScanTimeoutSeconds = 60;

  /// App name.
  static const String appName = 'Attendance';

  /// Local storage keys.
  static const String keyStudentId = 'student_id';
  static const String keyStudentName = 'student_name';
  static const String keyDeviceId = 'device_id';
}
