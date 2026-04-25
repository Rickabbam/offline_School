import 'package:flutter/material.dart';

import 'package:desktop_app/ui/finance/fee_structures_screen.dart';
import 'package:desktop_app/ui/finance/finance_service.dart';
import 'package:desktop_app/ui/finance/invoices_screen.dart';
import 'package:desktop_app/ui/finance/payments_screen.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({
    super.key,
    required this.service,
  });

  final FinanceService service;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const Material(
            color: Colors.transparent,
            child: TabBar(
              tabs: [
                Tab(text: 'Fee Structures'),
                Tab(text: 'Invoices'),
                Tab(text: 'Payments'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                FeeStructuresScreen(service: service),
                InvoicesScreen(service: service),
                PaymentsScreen(service: service),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
