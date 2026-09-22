import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/app_store.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/comparison_provider.dart';
import 'core/providers/find_care_provider.dart';
import 'core/providers/account_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_layout.dart';
import 'screens/capture_screen.dart';
import 'screens/compare_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/privacy_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ComparisonProvider()),
        ChangeNotifierProvider(create: (_) => FindCareProvider()),
        ChangeNotifierProvider(create: (_) => AccountProvider()),
      ],
      child: const SkinTwinApp(),
    ),
  );
}

class SkinTwinApp extends StatelessWidget {
  const SkinTwinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkinTwin',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthGuard(),
      routes: {
        '/app': (context) => const MainLayout(),
        '/capture': (context) => const CaptureScreen(),
        '/compare': (context) => const CompareScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/privacy': (context) => const PrivacySettingsScreen(),
        '/skin_twins': (context) => const MainLayout(),
        '/find-care': (context) => const MainLayout(),
      },
    );
  }
}

class AuthGuard extends StatelessWidget {
  const AuthGuard({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (authProvider.isAuthenticated) {
      return const MainLayout();
    } else {
      return const LoginScreen();
    }
  }
}
