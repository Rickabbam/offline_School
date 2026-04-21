import 'package:flutter/material.dart';

class Step11Confirmation extends StatefulWidget {
  const Step11Confirmation({
    super.key,
    required this.onComplete,
  });

  final Future<void> Function() onComplete;

  @override
  State<Step11Confirmation> createState() => _Step11ConfirmationState();
}

class _Step11ConfirmationState extends State<Step11Confirmation> {
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.onComplete();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Setup submission failed. $e';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Setup Complete!', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Submit the collected setup data to activate the school workspace.'),
        const SizedBox(height: 24),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 96,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Ready to create the tenant, school, campus, and academic setup.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.icon(
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_submitting ? 'Submitting...' : 'Finish Setup'),
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ],
    );
  }
}
