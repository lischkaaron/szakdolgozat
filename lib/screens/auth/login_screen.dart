import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../state/auth_controller.dart';
import 'auth_widgets.dart';
import 'register_screen.dart';
import 'server_settings_dialog.dart';

/// Bejelentkezés a backend `POST /api/auth/login` végpontján keresztül.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await context.read<AuthController>().login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  void _openRegister() {
    context.read<AuthController>().clearError();
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const RegisterScreen()));
  }

  /// A backend címének módosítása (fizikai eszközön gyakran szükséges).
  Future<void> _openServerSettings() async {
    final auth = context.read<AuthController>();
    final changed = await showServerSettingsDialog(context);

    if (!mounted) {
      return;
    }

    if (!changed) {
      return;
    }

    auth.clearError();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Szerver cím mentve: ${context.read<ApiClient>().baseUrl}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthHeader(
                      title: 'Motoros Konvoj',
                      subtitle: 'Jelentkezz be, hogy lásd a konvojt.',
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      key: const Key('loginEmailField'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'E-mail cím',
                        prefixIcon: Icon(Icons.alternate_email),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return 'Add meg az e-mail címedet.';
                        }
                        if (!text.contains('@')) {
                          return 'Érvénytelen e-mail cím.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('loginPasswordField'),
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Jelszó',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Jelszó megjelenítése'
                              : 'Jelszó elrejtése',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Add meg a jelszavadat.';
                        }
                        return null;
                      },
                    ),
                    if (auth.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      AuthErrorMessage(message: auth.errorMessage!),
                    ],
                    const SizedBox(height: 24),
                    AuthSubmitButton(
                      label: 'BELÉPÉS',
                      isBusy: auth.isBusy,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: auth.isBusy ? null : _openRegister,
                      child: const Text('Nincs még fiókod? Regisztrálj'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      key: const Key('serverSettingsButton'),
                      onPressed: auth.isBusy ? null : _openServerSettings,
                      icon: const Icon(Icons.dns_outlined, size: 16),
                      label: Text(
                        'Szerver: ${context.watch<ApiClient>().baseUrl}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
