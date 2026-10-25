import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';

/// Dialog for requesting manual attendance approval from the teacher.
class ManualRequestDialog extends StatefulWidget {
  const ManualRequestDialog({super.key});

  @override
  State<ManualRequestDialog> createState() => _ManualRequestDialogState();
}

class _ManualRequestDialogState extends State<ManualRequestDialog> {
  final _reasonController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason')),
      );
      return;
    }

    setState(() => _sending = true);

    final provider = context.read<AttendanceProvider>();
    final success = await provider.requestManualAttendance(reason);

    if (mounted) {
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Request sent! Wait for teacher approval.'
                : 'Failed to send request. Try again.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.front_hand, color: Colors.orange),
          SizedBox(width: 12),
          Text('Request Manual Attendance'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Your teacher will verify your presence in the classroom and approve your attendance.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'e.g. Bluetooth not working',
            ),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Request'),
        ),
      ],
    );
  }
}
