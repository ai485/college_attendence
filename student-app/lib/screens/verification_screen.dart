import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/qr_payload.dart';
import '../models/verification_state.dart';
import '../providers/attendance_provider.dart';
import '../widgets/verification_step_card.dart';
import '../widgets/manual_request_dialog.dart';
import 'result_screen.dart';

/// Shows the multi-step verification pipeline with live status updates.
class VerificationScreen extends StatefulWidget {
  final QrPayload payload;

  const VerificationScreen({super.key, required this.payload});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // Start verification after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_started) {
        _started = true;
        context.read<AttendanceProvider>().startVerification(widget.payload);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifying...'),
        automaticallyImplyLeading: false,
      ),
      body: Consumer<AttendanceProvider>(
        builder: (context, provider, _) {
          final state = provider.state;

          // Auto-navigate to result when done
          if (!provider.isProcessing &&
              _started &&
              (provider.attendanceMarked || state.hasFailed)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => ResultScreen(
                      success: provider.attendanceMarked,
                      message: provider.resultMessage ?? '',
                    ),
                  ),
                );
              }
            });
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Session info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.wifi,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Connected to ${widget.payload.serverIp}:${widget.payload.serverPort}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Step cards
                  ...VerificationStep.values.map((step) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: VerificationStepCard(
                        step: step,
                        status: state.getStepStatus(step),
                      ),
                    );
                  }),

                  const Spacer(),

                  // Error message
                  if (state.errorMessage != null && state.hasFailed)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Theme.of(context)
                                  .colorScheme
                                  .error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (state.hasFailed) ...[
                    const SizedBox(height: 16),
                    // Manual request button
                    OutlinedButton.icon(
                      onPressed: () => _showManualDialog(context),
                      icon: const Icon(Icons.front_hand),
                      label:
                          const Text('Request Manual Attendance'),
                    ),
                    const SizedBox(height: 8),
                    // Back button
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showManualDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const ManualRequestDialog(),
    );
  }
}
