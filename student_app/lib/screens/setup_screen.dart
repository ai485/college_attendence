import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

/// One-time setup screen for student profile (ID and name).
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final StorageService _storage = StorageService();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final id = await _storage.getStudentId();
    final name = await _storage.getStudentName();
    if (id != null) _idController.text = id;
    if (name != null) _nameController.text = name;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    await _storage.setStudentId(_idController.text.trim());
    await _storage.setStudentName(_nameController.text.trim());

    // Also ensure device ID is generated
    await _storage.getDeviceId();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Setup')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                Icon(
                  Icons.school,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),

                Text(
                  'Set Up Your Profile',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Enter your student ID and name to get started.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(153),
                      ),
                ),
                const SizedBox(height: 40),

                TextFormField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: 'Student ID / Roll Number',
                    prefixIcon: Icon(Icons.badge),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save & Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
