import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../models/qr_payload.dart';
import '../providers/attendance_provider.dart';
import 'verification_screen.dart';

/// Full-screen QR code scanner screen.
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
      body: Stack(
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
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 32),

                // Instruction text
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
}
