import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/nexora_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _server = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _server.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AppState>().login(
            _server.text,
            _user.text,
            _pass.text,
          );
    } catch (_) {
      if (mounted) {
        final message = context.read<AppState>().error ?? 'Error de acceso';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 820;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/brand/login_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: AppColors.background,
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xCC0B0B0D),
                    Color(0xF20B0B0D),
                    Color(0xFF0B0B0D),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: wide ? 460 : 440,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            const SizedBox(height: 24),
                            const Center(child: NexoraLogo(height: 52)),
                            const SizedBox(height: 10),
                            const Text(
                              'Cine, series y televisión en vivo\ndesde tu panel Xtream / XUI.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.muted,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 36),
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xE6141416),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.outline),
                              ),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _server,
                                    autofocus: true,
                                    keyboardType: TextInputType.url,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [AutofillHints.url],
                                    decoration: const InputDecoration(
                                      labelText: 'URL del servidor',
                                      hintText: 'http://dns:puerto',
                                      prefixIcon: Icon(Icons.dns_outlined),
                                    ),
                                    validator: (value) =>
                                        (value == null || value.trim().isEmpty)
                                            ? 'Introduce la URL del portal'
                                            : null,
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _user,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [AutofillHints.username],
                                    decoration: const InputDecoration(
                                      labelText: 'Usuario',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    validator: (value) =>
                                        (value == null || value.trim().isEmpty)
                                            ? 'Introduce el usuario'
                                            : null,
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _pass,
                                    obscureText: _obscure,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    autofillHints: const [AutofillHints.password],
                                    decoration: InputDecoration(
                                      labelText: 'Contraseña',
                                      prefixIcon: const Icon(Icons.lock_outline),
                                      suffixIcon: IconButton(
                                        onPressed: () =>
                                            setState(() => _obscure = !_obscure),
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                      ),
                                    ),
                                    validator: (value) =>
                                        (value == null || value.isEmpty)
                                            ? 'Introduce la contraseña'
                                            : null,
                                  ),
                                  const SizedBox(height: 22),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _busy ? null : _submit,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: _busy
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.4,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text('Entrar'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            const Text(
                              'Las credenciales se guardan cifradas en este dispositivo.\nCompatible con paneles Xtream Codes y XUI.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.faint,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
