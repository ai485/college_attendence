/// Represents the verification pipeline steps and their statuses.

enum VerificationStep { qr, wifi, ble, biometric }

enum StepStatus { pending, inProgress, success, failed, skipped }

/// Holds the status of each verification step.
class VerificationState {
  final Map<VerificationStep, StepStatus> steps;
  String? errorMessage;
  String? sessionId;

  VerificationState()
      : steps = {
          VerificationStep.qr: StepStatus.pending,
          VerificationStep.wifi: StepStatus.pending,
          VerificationStep.ble: StepStatus.pending,
          VerificationStep.biometric: StepStatus.pending,
        };

  void updateStep(VerificationStep step, StepStatus status) {
    steps[step] = status;
  }

  StepStatus getStepStatus(VerificationStep step) {
    return steps[step] ?? StepStatus.pending;
  }

  bool get allPassed => steps.values.every(
      (s) => s == StepStatus.success || s == StepStatus.skipped);

  bool get hasFailed => steps.values.any((s) => s == StepStatus.failed);

  void reset() {
    for (final step in VerificationStep.values) {
      steps[step] = StepStatus.pending;
    }
    errorMessage = null;
    sessionId = null;
  }

  /// Human-readable label for a step.
  static String stepLabel(VerificationStep step) {
    switch (step) {
      case VerificationStep.qr:
        return 'QR Code Scan';
      case VerificationStep.wifi:
        return 'Wi-Fi Verification';
      case VerificationStep.ble:
        return 'Bluetooth Proximity';
      case VerificationStep.biometric:
        return 'Biometric Verification';
    }
  }

  /// Icon for a step.
  static String stepIcon(VerificationStep step) {
    switch (step) {
      case VerificationStep.qr:
        return '📱';
      case VerificationStep.wifi:
        return '📶';
      case VerificationStep.ble:
        return '🔵';
      case VerificationStep.biometric:
        return '🔐';
    }
  }
}
