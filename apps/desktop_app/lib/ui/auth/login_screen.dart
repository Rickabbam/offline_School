import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

import 'package:desktop_app/auth/auth_service.dart';

/// Login screen shown when no authenticated session exists.
/// Supports online email+password login.
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
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();
      await auth.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    } catch (e) {
      if (mounted) {
        final auth = context.read<AuthService>();
        setState(() => _error = loginFailureMessage(e, auth.backendBaseUrl));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useTrustedDevice() async {
    setState(() {
      _offlineLoading = true;
      _error = null;
    });

    try {
      await context.read<AuthService>().loginWithTrustedDevice();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e'
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
      backgroundColor: colorScheme.surfaceContainerHighest,
      body: Center(
        child: SizedBox(
          width: 400,
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.school,
                      size: 56,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'offline_School',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email is required.';
                        if (!v.contains('@')) return 'Enter a valid email.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtrl,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password is required.';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: colorScheme.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
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
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<bool>(
                      future: auth.hasTrustedDeviceAccess(),
                      builder: (context, snapshot) {
                        final available = snapshot.data ?? false;
                        if (!available) {
                          return const SizedBox.shrink();
                        }
                        return SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _loading || _offlineLoading
                                ? null
                                : _useTrustedDevice,
                            child: _offlineLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Use Trusted Offline Access'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Offline access is available once this device is registered. Logging out now ends the session without deleting device trust.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                      textAlign: TextAlign.center,
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

@visibleForTesting
String loginFailureMessage(Object error, String backendBaseUrl) {
  if (error is DioException) {
    final networkFailure = error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout;
    if (networkFailure || error.response == null) {
      return 'Cannot reach the backend at $backendBaseUrl. Start the backend, then try again.';
    }

    final statusCode = error.response?.statusCode;
    if (statusCode == 401) {
      return 'Invalid email or password.';
    }
    if (statusCode == 400) {
      return 'Login request was rejected. Check the email format and password.';
    }
    return 'Login failed with server status $statusCode.';
  }

  return 'Login failed. Try again.';
}
