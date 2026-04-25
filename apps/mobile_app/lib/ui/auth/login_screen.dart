import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:desktop_app/auth/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _offlineLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await context.read<AuthService>().login(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Login failed. Check your email and password.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _useTrustedDevice() async {
    setState(() {
      _offlineLoading = true;
      _error = null;
    });

    try {
      await context.read<AuthService>().loginWithTrustedDevice();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error'
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _offlineLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final auth = context.read<AuthService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFE7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D3B66),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.assignment_turned_in,
                                  color: Colors.white, size: 34),
                              const SizedBox(height: 14),
                              Text(
                                'Teacher Attendance',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Offline-first classroom register for trusted mobile devices.',
                                style: TextStyle(color: Color(0xFFD7E3F1)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Email is required.';
                            }
                            if (!value.contains('@')) {
                              return 'Enter a valid email.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                          onFieldSubmitted: (_) => _submit(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required.';
                            }
                            return null;
                          },
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _loading || _offlineLoading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Sign In'),
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<bool>(
                          future: auth.hasTrustedDeviceAccess(),
                          builder: (context, snapshot) {
                            if (!(snapshot.data ?? false)) {
                              return const SizedBox.shrink();
                            }
                            return OutlinedButton(
                              onPressed:
                                  _loading || _offlineLoading ? null : _useTrustedDevice,
                              child: _offlineLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Use Trusted Offline Access'),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
