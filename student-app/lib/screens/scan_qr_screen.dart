import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/qr_payload.dart';
import '../providers/attendance_provider.dart';
import 'verification_screen.dart';

/// Full-screen QR code scanner screen.
///
/// NOTE: mobile_scanner does not request the camera permission itself.
/// Declaring CAMERA in AndroidManifest.xml is not enough on Android 6+ —
/// the permission must also be granted at runtime. If the scanner is shown
/// without it, the camera never starts and the screen stays black, with no
/// error shown. So this screen only starts the camera after confirming the
/// permission, and shows a recovery UI (grant / app settings) otherwise.
class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  // autoStart: false so the camera is only started once we know the
  // camera permission is granted (see _startCamera).
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    autoStart: false,
  );
  bool _scanned = false;
  bool _cameraReady = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  /// Request the camera permission if needed, then start the camera.
  /// If permission is refused, show a recovery UI instead of a black screen.
  Future<void> _startCamera() async {
    var status = await Permission.camera.status;
    if (status.isDenied) {
      status = await Permission.camera.request();
    }
    if (!mounted) return;

    if (status.isGranted) {
      setState(() {
        _permissionDenied = false;
        _cameraReady = true;
      });
      // Start only after the MobileScanner widget is in the tree.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.start();
      });
    } else {
      // Denied or permanently denied: the system will not prompt again
      // for a permanently denied permission, so the user must enable it
      // in app settings (offered by the fallback UI below).
      setState(() => _permissionDenied = true);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;

      try {
        // Try to parse as our attendance QR payload
        final payload = QrPayload.fromQrString(raw);

        setState(() => _scanned = true);
        _controller.stop();

        // Navigate to verification screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => VerificationScreen(payload: payload),
          ),
        );
        return;
      } catch (e) {
        // Not a valid attendance QR, ignore
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _permissionDenied
          ? _buildPermissionDenied()
          : !_cameraReady
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    // Camera viewfinder
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                    ),

                    // Overlay
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(102),
                      ),
                    ),

                    // Cutout and instructions
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Scan frame
                          Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color:
                                    Theme.of(context).colorScheme.primary,
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Instruction text
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(179),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Point camera at the QR code\non the projector screen',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  /// Shown when the camera permission is refused, instead of a black screen.
  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Camera access is needed to scan the QR code.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _startCamera,
              child: const Text('Grant Camera Permission'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: openAppSettings,
              child: const Text('Open App Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
