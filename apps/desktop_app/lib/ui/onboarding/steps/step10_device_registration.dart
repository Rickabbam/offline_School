import 'package:flutter/material.dart';

import 'package:desktop_app/ui/onboarding/onboarding_models.dart';

class Step10DeviceRegistration extends StatefulWidget {
  const Step10DeviceRegistration({
    super.key,
    required this.initialValue,
    required this.onNext,
    required this.onBack,
  });

  final DeviceRegistrationDraft initialValue;
  final ValueChanged<DeviceRegistrationDraft> onNext;
  final VoidCallback onBack;

  @override
  State<Step10DeviceRegistration> createState() =>
      _Step10DeviceRegistrationState();
}

class _Step10DeviceRegistrationState extends State<Step10DeviceRegistration> {
  late final TextEditingController _deviceNameCtrl;
  late bool _registerOfflineAccess;

  @override
  void initState() {
    super.initState();
    _deviceNameCtrl =
        TextEditingController(text: widget.initialValue.deviceName);
    _registerOfflineAccess = widget.initialValue.registerOfflineAccess;
  }

  @override
  void dispose() {
    _deviceNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedDeviceName = _deviceNameCtrl.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Device Registration',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Decide whether this workstation should receive a trusted offline token after school setup is committed.',
        ),
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
                      const Text(
                        'Trusted device registration is completed during the final setup submission, after tenant, school, and campus scope exist.',
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
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: _registerOfflineAccess,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Enable trusted offline login on this device',
                        ),
                        subtitle: const Text(
                          'Recommended for the main front-desk or admin office workstation.',
                        ),
                        onChanged: (value) {
                          setState(
                            () => _registerOfflineAccess = value ?? true,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _registerOfflineAccess
                            ? 'Status: ready to register on setup completion'
                            : 'Status: offline login disabled for now',
                      ),
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
              onPressed: () {
                widget.onNext(
                  DeviceRegistrationDraft(
                    deviceName: resolvedDeviceName,
                    registerOfflineAccess: _registerOfflineAccess,
                    isRegistered: _registerOfflineAccess,
                  ),
                );
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ],
    );
  }
}
