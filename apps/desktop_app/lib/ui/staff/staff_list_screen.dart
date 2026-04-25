import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/ui/staff/staff_form_screen.dart';

class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final user = context.watch<AuthService>().currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Text('Staff', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _search = value.trim()),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Staff'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StaffFormScreen()),
                ).then((_) => setState(() {})),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<StaffData>>(
            future: user?.tenantId == null || user?.schoolId == null
                ? Future.value(const <StaffData>[])
                : db.getAllStaff(
                    scope: LocalDataScope(
                      tenantId: user!.tenantId!,
                      schoolId: user.schoolId!,
                      campusId: user.campusId,
                    ),
                    search: _search.isEmpty ? null : _search,
                  ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _search.isEmpty
                            ? 'No staff yet. Add the first staff member.'
                            : 'No staff match "$_search".',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Staff No.')),
                    DataColumn(label: Text('Full Name')),
                    DataColumn(label: Text('Department')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Employment')),
                    DataColumn(label: Text('Active')),
                  ],
                  rows: rows
                      .map(
                        (staff) => DataRow(
                          onSelectChanged: (_) => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StaffFormScreen(existing: staff),
                            ),
                          ).then((_) => setState(() {})),
                          cells: [
                            DataCell(Text(staff.staffNumber ?? '-')),
                            DataCell(
                                Text('${staff.firstName} ${staff.lastName}')),
                            DataCell(Text(staff.department ?? '-')),
                            DataCell(Text(staff.systemRole)),
                            DataCell(Text(staff.employmentType)),
                            DataCell(
                              Icon(
                                staff.isActive
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color:
                                    staff.isActive ? Colors.green : Colors.red,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
