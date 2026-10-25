import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'providers/attendance_provider.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AttendanceProvider(),
      child: MaterialApp(
        title: 'Attendance',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const _InitialRoute(),
      ),
    );
  }
}

/// Checks if profile is set up and routes accordingly.
class _InitialRoute extends StatefulWidget {
  const _InitialRoute();

  @override
  State<_InitialRoute> createState() => _InitialRouteState();
}

class _InitialRouteState extends State<_InitialRoute> {
  bool _loading = true;
  bool _profileReady = false;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    final storage = StorageService();
    final ready = await storage.isProfileSetup();
    if (mounted) {
      setState(() {
        _profileReady = ready;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _profileReady ? const HomeScreen() : const SetupScreen();
  }
}
