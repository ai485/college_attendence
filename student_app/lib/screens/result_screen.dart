import 'package:flutter/material.dart';
import 'home_screen.dart';

/// Final result screen showing success or failure.
class ResultScreen extends StatelessWidget {
  final bool success;
  final String message;

  const ResultScreen({
    super.key,
    required this.success,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: success
                      ? Colors.green.withAlpha(26)
                      : Colors.red.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  success ? Icons.check_circle : Icons.cancel,
                  size: 80,
                  color: success ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                success ? 'Attendance Marked!' : 'Verification Failed',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: success ? Colors.green : Colors.red,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Message
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(179),
                    ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // Done button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const HomeScreen()),
                      (route) => false,
                    );
                  },
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
