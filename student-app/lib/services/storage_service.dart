import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../config.dart';

/// Service for local persistent storage (student profile, device ID).
class StorageService {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Get or generate a unique device ID.
  Future<String> getDeviceId() async {
    final prefs = await _preferences;
    var deviceId = prefs.getString(AppConfig.keyDeviceId);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await prefs.setString(AppConfig.keyDeviceId, deviceId);
    }
    return deviceId;
  }

  /// Get saved student ID.
  Future<String?> getStudentId() async {
    final prefs = await _preferences;
    return prefs.getString(AppConfig.keyStudentId);
  }

  /// Save student ID.
  Future<void> setStudentId(String id) async {
    final prefs = await _preferences;
    await prefs.setString(AppConfig.keyStudentId, id);
  }

  /// Get saved student name.
  Future<String?> getStudentName() async {
    final prefs = await _preferences;
    return prefs.getString(AppConfig.keyStudentName);
  }

  /// Save student name.
  Future<void> setStudentName(String name) async {
    final prefs = await _preferences;
    await prefs.setString(AppConfig.keyStudentName, name);
  }

  /// Check if the student profile is set up.
  Future<bool> isProfileSetup() async {
    final id = await getStudentId();
    final name = await getStudentName();
    return id != null && id.isNotEmpty && name != null && name.isNotEmpty;
  }
}
