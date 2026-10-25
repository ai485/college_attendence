import 'package:local_auth/local_auth.dart';

/// Service for on-device biometric authentication.
///
/// Uses the OS native biometrics:
/// - Android: BiometricPrompt (fingerprint, face)
/// - iOS: Face ID / Touch ID
///
/// Biometric data never leaves the device's secure enclave.
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Check if the device supports biometric authentication.
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck || isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  /// Get the list of available biometric types.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Authenticate the student using device biometrics.
  ///
  /// Returns true if authentication succeeded.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Verify your identity to mark attendance',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/pattern as fallback
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }
}
