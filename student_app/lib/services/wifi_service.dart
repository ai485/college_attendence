import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service to read the current Wi-Fi BSSID (Access Point MAC address).
class WifiService {
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Get the BSSID of the currently connected Wi-Fi access point.
  /// Returns null if unavailable or permission denied.
  /// 
  /// Requires Location permission on Android (ACCESS_FINE_LOCATION).
  /// On iOS, requires the CNCopyCurrentNetworkInfo entitlement.
  Future<String?> getCurrentBssid() async {
    // Request location permission (required for BSSID on Android)
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      return null;
    }

    try {
      final bssid = await _networkInfo.getWifiBSSID();
      // Some devices return "02:00:00:00:00:00" when permission is missing
      if (bssid == null ||
          bssid.isEmpty ||
          bssid == '02:00:00:00:00:00') {
        return null;
      }
      return bssid.toUpperCase();
    } catch (e) {
      return null;
    }
  }

  /// Get the current Wi-Fi network name (SSID) for display.
  Future<String?> getCurrentSsid() async {
    try {
      return await _networkInfo.getWifiName();
    } catch (e) {
      return null;
    }
  }
}
