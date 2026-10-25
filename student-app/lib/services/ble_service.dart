import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config.dart';

/// Result of a BLE proximity scan.
class BleProofResult {
  final bool found;
  final String? bleToken;
  final int hopCount;
  final bool isFallback;

  BleProofResult({
    required this.found,
    this.bleToken,
    this.hopCount = 0,
    this.isFallback = false,
  });
}

/// Service for BLE beacon scanning and relay broadcasting.
///
/// 1. Scans for the teacher's BLE beacon (or relayed beacons from other students).
/// 2. After own verification, can relay the beacon for nearby students.
class BleService {
  StreamSubscription? _scanSubscription;
  bool _isScanning = false;

  /// Request Bluetooth permissions.
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    // Check if critical permissions are granted
    final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final locationGranted =
        statuses[Permission.locationWhenInUse]?.isGranted ?? false;

    return scanGranted || locationGranted;
  }

  /// Scan for attendance BLE beacons.
  ///
  /// Scans for [timeout] duration looking for beacons from the teacher
  /// or from other verified students (hop_count ≤ 2).
  ///
  /// Returns a [BleProofResult] with the token and hop count if found.
  Future<BleProofResult> scanForBeacon({
    int timeout = 15,
  }) async {
    final completer = Completer<BleProofResult>();

    try {
      // Check Bluetooth availability
      final isAvailable = await FlutterBluePlus.isAvailable;
      if (!isAvailable) {
        return BleProofResult(found: false);
      }

      final isOn = await FlutterBluePlus.adapterState.first;
      if (isOn != BluetoothAdapterState.on) {
        return BleProofResult(found: false);
      }

      await requestPermissions();

      _isScanning = true;

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: timeout),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      _scanSubscription = FlutterBluePlus.onScanResults.listen(
        (results) {
          for (final result in results) {
            final beacon = _parseBeacon(result);
            if (beacon != null && !completer.isCompleted) {
              completer.complete(beacon);
              _stopScan();
              return;
            }
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.complete(BleProofResult(found: false));
          }
        },
      );

      // Timeout fallback
      Future.delayed(Duration(seconds: timeout), () {
        if (!completer.isCompleted) {
          completer.complete(BleProofResult(found: false));
          _stopScan();
        }
      });

      return await completer.future;
    } catch (e) {
      return BleProofResult(found: false);
    }
  }

  /// Parse BLE advertisement data looking for our attendance beacon.
  BleProofResult? _parseBeacon(ScanResult result) {
    try {
      // Check service UUIDs
      for (final serviceUuid in result.advertisementData.serviceUuids) {
        if (serviceUuid.toString().toLowerCase() ==
            AppConfig.bleServiceUuid.toLowerCase()) {
          // Found our beacon! Extract data from manufacturer data or service data.
          final mfgData = result.advertisementData.manufacturerData;
          if (mfgData.isNotEmpty) {
            final data = mfgData.values.first;
            if (data.length >= 9) {
              // Parse: [session_id(4), token(4), hop_count(1)]
              final token = data.sublist(4, 8).map(
                  (b) => b.toRadixString(16).padLeft(2, '0')).join();
              final hopCount = data[8];

              if (hopCount <= AppConfig.maxBleHops) {
                return BleProofResult(
                  found: true,
                  bleToken: token,
                  hopCount: hopCount,
                );
              }
            }
          }

          // If we found the service UUID but couldn't parse data,
          // still count it as found with just a name match
          final localName = result.advertisementData.advName;
          if (localName.startsWith('ATT-')) {
            // Token embedded in name: ATT-<token>-<hop>
            final parts = localName.split('-');
            if (parts.length >= 3) {
              return BleProofResult(
                found: true,
                bleToken: parts[1],
                hopCount: int.tryParse(parts[2]) ?? 0,
              );
            }
          }
        }
      }

      // Also check by device name pattern
      final name = result.advertisementData.advName;
      if (name.startsWith('ATT-')) {
        final parts = name.split('-');
        if (parts.length >= 3) {
          return BleProofResult(
            found: true,
            bleToken: parts[1],
            hopCount: int.tryParse(parts[2]) ?? 0,
          );
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Stop any ongoing BLE scan.
  Future<void> _stopScan() async {
    _isScanning = false;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  /// Clean up resources.
  Future<void> dispose() async {
    await _stopScan();
  }
}
