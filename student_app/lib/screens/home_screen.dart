import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../services/storage_service.dart';
import 'setup_screen.dart';
import 'scan_qr_screen.dart';

/// Main home screen showing student info and "Mark Attendance" button.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  String _studentId = '';
  String _studentName = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final id = await _storage.getStudentId();
    final name = await _storage.getStudentName();

    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SetupScreen()),
        );
      }
      return;
    }

    setState(() {
      _studentId = id;
      _studentName = name;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Edit Profile',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SetupScreen()),
              );
              _loadProfile();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // Student avatar/icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),

              // Student name
              Text(
                _studentName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),

              // Student ID
              Text(
                'ID: $_studentId',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(153),
                    ),
              ),

              const Spacer(),

              // Mark Attendance button
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Reset provider state and navigate to scanner
                    context.read<AttendanceProvider>().reset();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ScanQrScreen()),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner, size: 28),
                  label: const Text(
                    'Mark Attendance',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.primary,
                    foregroundColor:
                        Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
