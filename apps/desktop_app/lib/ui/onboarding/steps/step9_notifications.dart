import 'package:flutter/material.dart';

import 'package:desktop_app/ui/onboarding/onboarding_models.dart';

class Step9Notifications extends StatelessWidget {
  const Step9Notifications({
    super.key,
    required this.initialValue,
    required this.onNext,
    required this.onBack,
  });

  final NotificationSettingsDraft initialValue;
  final ValueChanged<NotificationSettingsDraft> onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final senderId = TextEditingController(text: initialValue.senderId);
    final provider = TextEditingController(text: initialValue.providerName);
    var smsEnabled = initialValue.smsEnabled;
    var receiptsEnabled = initialValue.paymentReceiptsEnabled;
    var remindersEnabled = initialValue.feeRemindersEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notification Settings',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text(
            'Choose which parent-facing notifications should be enabled.'),
        const SizedBox(height: 24),
        Expanded(
          child: StatefulBuilder(
            builder: (context, setLocalState) => ListView(
              children: [
                SwitchListTile(
                  value: smsEnabled,
                  title: const Text('Enable SMS notifications'),
                  subtitle: const Text(
                    'SMS jobs will be queued when internet access is unavailable.',
                  ),
                  onChanged: (value) => setLocalState(() => smsEnabled = value),
                ),
                SwitchListTile(
                  value: receiptsEnabled,
                  title: const Text('Send payment receipt alerts'),
                  onChanged: (value) =>
                      setLocalState(() => receiptsEnabled = value),
                ),
                SwitchListTile(
                  value: remindersEnabled,
                  title: const Text('Send fee reminder alerts'),
                  onChanged: (value) =>
                      setLocalState(() => remindersEnabled = value),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: provider,
                  enabled: smsEnabled,
                  decoration: const InputDecoration(
                    labelText: 'SMS provider',
                    hintText: 'e.g. Arkesel or mNotify',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: senderId,
                  enabled: smsEnabled,
                  decoration: const InputDecoration(
                    labelText: 'Sender ID',
                    hintText: 'e.g. OFFSCHOOL',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(onPressed: onBack, child: const Text('Back')),
            FilledButton(
              onPressed: () {
                onNext(
                  NotificationSettingsDraft(
                    smsEnabled: smsEnabled,
                    paymentReceiptsEnabled: receiptsEnabled,
                    feeRemindersEnabled: remindersEnabled,
                    senderId: senderId.text.trim(),
                    providerName: provider.text.trim(),
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
