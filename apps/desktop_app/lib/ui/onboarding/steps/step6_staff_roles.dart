import 'package:flutter/material.dart';

import 'package:desktop_app/ui/onboarding/onboarding_models.dart';

class Step6StaffRoles extends StatefulWidget {
  const Step6StaffRoles({
    super.key,
    required this.initialValue,
    required this.onNext,
    required this.onBack,
  });

  final List<StaffRoleDraft> initialValue;
  final ValueChanged<List<StaffRoleDraft>> onNext;
  final VoidCallback onBack;

  @override
  State<Step6StaffRoles> createState() => _Step6StaffRolesState();
}

class _Step6StaffRolesState extends State<Step6StaffRoles> {
  static const _availableRoles = [
    'admin',
    'cashier',
    'teacher',
    'parent',
    'student',
    'support_technician',
  ];

  late List<StaffRoleDraft> _roles;

  @override
  void initState() {
    super.initState();
    _roles = widget.initialValue.isEmpty
        ? _availableRoles
            .map(
              (role) => StaffRoleDraft(
                role: role,
                enabled: role == 'admin' || role == 'teacher',
                headcount: role == 'admin'
                    ? 1
                    : role == 'teacher'
                        ? 6
                        : 0,
              ),
            )
            .toList(growable: false)
        : [...widget.initialValue];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Staff Roles', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text(
          'Select the system roles you expect to use in the first term and estimate headcount for each.',
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.separated(
            itemCount: _roles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final role = _roles[index];
              return _RoleTile(
                draft: role,
                onChanged: (value) {
                  setState(() => _roles[index] = value);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This step prepares operating defaults. Individual staff records are created later in the staff management step.',
                    style: Theme.of(context).textTheme.bodyMedium,
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
            OutlinedButton(
              onPressed: widget.onBack,
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => widget.onNext(_roles),
              child: const Text('Continue'),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoleTile extends StatefulWidget {
  const _RoleTile({required this.draft, required this.onChanged});

  final StaffRoleDraft draft;
  final ValueChanged<StaffRoleDraft> onChanged;

  @override
  State<_RoleTile> createState() => _RoleTileState();
}

class _RoleTileState extends State<_RoleTile> {
  late bool _enabled;
  late double _headcount;

  @override
  void initState() {
    super.initState();
    _enabled = widget.draft.enabled;
    _headcount = widget.draft.headcount.toDouble();
  }

  @override
  void didUpdateWidget(covariant _RoleTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft) {
      _enabled = widget.draft.enabled;
      _headcount = widget.draft.headcount.toDouble();
    }
  }

  void _emit() {
    widget.onChanged(
      widget.draft.copyWith(
        enabled: _enabled,
        headcount: _enabled ? _headcount.round() : 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.draft.role
        .split('_')
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Switch(
                  value: _enabled,
                  onChanged: (value) {
                    setState(() => _enabled = value);
                    _emit();
                  },
                ),
              ],
            ),
            if (_enabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text('Estimated users: ${_headcount.round()}'),
                  ),
                  Expanded(
                    flex: 2,
                    child: Slider(
                      min: 1,
                      max: 25,
                      divisions: 24,
                      value: _headcount.clamp(1, 25),
                      label: _headcount.round().toString(),
                      onChanged: (value) {
                        setState(() => _headcount = value);
                        _emit();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
