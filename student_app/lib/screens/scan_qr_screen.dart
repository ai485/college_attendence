import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/qr_payload.dart';
import '../providers/attendance_provider.dart';
import 'verification_screen.dart';

/// Full-screen QR code scanner screen.
///
/// Camera permission must be granted at runtime on Android 6+ — the CAMERA
/// entry in AndroidManifest.xml alone is not enough, and mobile_scanner does
/// not prompt for it. This screen therefore only shows the scanner after the
/// permission is confirmed, and shows a recovery UI otherwise.
///
/// The scanner deliberately uses mobile_scanner's default auto-start: calling
/// `controller.start()` manually can race the widget attaching to the
/// controller and leave it stuck in an error state (just a "!" icon with no
/// way back). Instead, any start failure is surfaced through [errorBuilder]
/// with the real error code and a Retry button.
class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _scanned = false;
  bool _cameraReady = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  /// Confirm the camera permission before showing the scanner.
  /// If refused, show a recovery UI instead of a dead camera view.
  Future<void> _checkCameraPermission() async {
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
    } else {
      // Denied or permanently denied: the system will not prompt again
      // for a permanently denied permission, so the user must enable it
      // in app settings (offered by the fallback UI below).
      setState(() => _permissionDenied = true);
    }
  }

  /// Retry starting the camera after a start failure (e.g. the camera was
  /// busy or the controller failed to attach on the first attempt).
  Future<void> _retryCamera() async {
    try {
      await _controller.stop();
      await _controller.start();
    } on MobileScannerException {
      // The errorBuilder below will show the new error state.
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
                      // Never leave the user staring at the default "!"
                      // error icon: show what failed and offer a retry.
                      errorBuilder: (context, error, child) {
                        final isPermission = error.errorCode ==
                            MobileScannerErrorCode.permissionDenied;
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  isPermission
                                      ? 'Camera permission was denied.'
                                      : 'Camera could not be started '
                                          '(${error.errorCode}).',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _retryCamera,
                                  child: const Text('Retry Camera'),
                                ),
                                if (isPermission) ...[
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: openAppSettings,
                                    child:
                                        const Text('Open App Settings'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
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
              onPressed: _checkCameraPermission,
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
