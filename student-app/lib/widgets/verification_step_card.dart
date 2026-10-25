import 'package:flutter/material.dart';
import '../models/verification_state.dart';

/// Card widget showing the status of a single verification step.
class VerificationStepCard extends StatelessWidget {
  final VerificationStep step;
  final StepStatus status;

  const VerificationStepCard({
    super.key,
    required this.step,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor(context), width: 1.5),
      ),
      child: Row(
        children: [
          // Status icon
          SizedBox(
            width: 40,
            height: 40,
            child: _buildIcon(context),
          ),
          const SizedBox(width: 16),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  VerificationState.stepLabel(step),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _subtitleColor(context),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    switch (status) {
      case StepStatus.pending:
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.withAlpha(51),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.radio_button_unchecked,
                color: Colors.grey, size: 24),
          ),
        );
      case StepStatus.inProgress:
        return const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        );
      case StepStatus.success:
        return Container(
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.check, color: Colors.white, size: 22),
          ),
        );
      case StepStatus.failed:
        return Container(
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.close, color: Colors.white, size: 22),
          ),
        );
      case StepStatus.skipped:
        return Container(
          decoration: BoxDecoration(
            color: Colors.orange.withAlpha(51),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.skip_next, color: Colors.orange, size: 22),
          ),
        );
    }
  }

  String _subtitle() {
    switch (status) {
      case StepStatus.pending:
        return 'Waiting...';
      case StepStatus.inProgress:
        return _inProgressText();
      case StepStatus.success:
        return 'Verified';
      case StepStatus.failed:
        return 'Failed';
      case StepStatus.skipped:
        return 'Skipped (not available)';
    }
  }

  String _inProgressText() {
    switch (step) {
      case VerificationStep.qr:
        return 'Validating QR code...';
      case VerificationStep.wifi:
        return 'Checking Wi-Fi connection...';
      case VerificationStep.ble:
        return 'Scanning for Bluetooth beacon...';
      case VerificationStep.biometric:
        return 'Waiting for biometric...';
    }
  }

  Color _bgColor(BuildContext context) {
    switch (status) {
      case StepStatus.success:
        return Colors.green.withAlpha(20);
      case StepStatus.failed:
        return Colors.red.withAlpha(20);
      case StepStatus.inProgress:
        return Theme.of(context).colorScheme.primaryContainer.withAlpha(77);
      default:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
  }

  Color _borderColor(BuildContext context) {
    switch (status) {
      case StepStatus.success:
        return Colors.green.withAlpha(102);
      case StepStatus.failed:
        return Colors.red.withAlpha(102);
      case StepStatus.inProgress:
        return Theme.of(context).colorScheme.primary.withAlpha(102);
      default:
        return Colors.transparent;
    }
  }

  Color _subtitleColor(BuildContext context) {
    switch (status) {
      case StepStatus.success:
        return Colors.green;
      case StepStatus.failed:
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.onSurface.withAlpha(153);
    }
  }
}
