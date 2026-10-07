import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/nexora_logo.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const NexoraApp());
}

class NexoraApp extends StatelessWidget {
  const NexoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..bootstrap(),
      child: MaterialApp(
        title: 'Nexora',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        builder: (context, child) {
          return Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
            },
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.booting) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NexoraLogo(height: 56),
              SizedBox(height: 28),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return state.loggedIn ? const ShellScreen() : const LoginScreen();
  }
}
