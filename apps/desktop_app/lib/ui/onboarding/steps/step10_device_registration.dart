import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/auth_service.dart';

class Step10DeviceRegistration extends StatefulWidget {
  const Step10DeviceRegistration({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<Step10DeviceRegistration> createState() =>
      _Step10DeviceRegistrationState();
}

class _Step10DeviceRegistrationState extends State<Step10DeviceRegistration> {
  final _deviceNameCtrl = TextEditingController();
  bool _registering = false;
  String? _message;
  bool _registered = false;

  @override
  void dispose() {
    _deviceNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _registerDevice() async {
    setState(() {
      _registering = true;
      _message = null;
    });

    try {
      await context.read<AuthService>().ensureTrustedDeviceRegistered(
            _deviceNameCtrl.text.trim().isEmpty
                ? null
                : _deviceNameCtrl.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _registered = true;
        _message = 'This device is ready for trusted offline access.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Device registration failed. Check backend connectivity.';
      });
    } finally {
      if (mounted) {
        setState(() => _registering = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Device Registration',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text('Register this device for trusted offline access.'),
        const SizedBox(height: 24),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current user: ${auth.currentUser?.fullName ?? 'Not signed in'}',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _deviceNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Device name',
                          hintText: 'e.g. Admin Office PC',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed:
                            _registering || auth.currentUser == null
                                ? null
                                : _registerDevice,
                        icon: const Icon(Icons.lock_open_outlined),
                        label: Text(
                          _registering
                              ? 'Registering...'
                              : 'Register Trusted Device',
                        ),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _message!,
                          style: TextStyle(
                            color: _registered
                                ? Colors.green.shade700
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: widget.onBack,
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: widget.onNext,
              child: const Text('Continue'),
            ),
          ],
        ),
      ],
    );
  }
}
