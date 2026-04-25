import 'dart:convert';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class FeeStructuresWorkspaceData {
  const FeeStructuresWorkspaceData({
    required this.categories,
    required this.items,
    required this.classLevels,
    required this.terms,
  });

  final List<FeeCategory> categories;
  final List<FeeStructureItem> items;
  final List<ClassLevelsCacheData> classLevels;
  final List<TermsCacheData> terms;
}

class InvoiceWorkspaceData {
  const InvoiceWorkspaceData({
    required this.invoices,
    required this.students,
    required this.classLevels,
    required this.classArms,
    required this.terms,
  });

  final List<Invoice> invoices;
  final List<Student> students;
  final List<ClassLevelsCacheData> classLevels;
  final List<ClassArmsCacheData> classArms;
  final List<TermsCacheData> terms;
}

class PaymentWorkspaceData {
  const PaymentWorkspaceData({
    required this.invoices,
    required this.payments,
    required this.reversals,
    required this.students,
    required this.classArms,
    required this.terms,
  });

  final List<Invoice> invoices;
  final List<Payment> payments;
  final List<PaymentReversal> reversals;
  final List<Student> students;
  final List<ClassArmsCacheData> classArms;
  final List<TermsCacheData> terms;
}

class FinanceService {
  FinanceService(this._auth, this._db);

  final AuthService _auth;
  final AppDatabase _db;
  final _uuid = const Uuid();

  AuthUser get _user {
    final user = _auth.currentUser;
    if (user == null || user.tenantId == null || user.schoolId == null) {
      throw StateError('School workspace is not available for this session.');
    }
    return user;
  }

  LocalDataScope get _scope => LocalDataScope(
        tenantId: _user.tenantId!,
        schoolId: _user.schoolId!,
        campusId: _user.campusId,
      );

  Future<FeeStructuresWorkspaceData> loadWorkspace() async {
    final scope = _scope;
    final categories = await _db.getFeeCategories(scope: scope);
    final items = await _db.getFeeStructureItems(scope: scope);
    final classLevels = await _db.getClassLevels(scope: scope);
    final terms = await _db.getTerms(scope: scope);
    return FeeStructuresWorkspaceData(
      categories: categories,
      items: items,
      classLevels: classLevels,
      terms: terms,
    );
  }

  Future<InvoiceWorkspaceData> loadInvoiceWorkspace() async {
    final scope = _scope;
    final invoices = await _db.getInvoices(scope: scope);
    final students = await _db.getStudents(scope: scope);
    final classLevels = await _db.getClassLevels(scope: scope);
    final classArms = await _db.getClassArms(scope: scope);
    final terms = await _db.getTerms(scope: scope);
    return InvoiceWorkspaceData(
      invoices: invoices,
      students: students,
      classLevels: classLevels,
      classArms: classArms,
      terms: terms,
    );
  }

  Future<PaymentWorkspaceData> loadPaymentWorkspace() async {
    final scope = _scope;
    final invoices = await _db.getInvoices(scope: scope, status: 'posted');
    final payments = await _db.getPayments(scope: scope);
    final reversals = await _db.getPaymentReversals(scope: scope);
    final students = await _db.getStudents(scope: scope);
    final classArms = await _db.getClassArms(scope: scope);
    final terms = await _db.getTerms(scope: scope);
    return PaymentWorkspaceData(
      invoices: invoices,
      payments: payments,
      reversals: reversals,
      students: students,
      classArms: classArms,
      terms: terms,
    );
  }

  Future<Map<String, int>> generateInvoices({
    required String termId,
    String? classLevelId,
    String? studentId,
  }) async {
    final scope = _scope;
    final term = await _db.findTermById(scope: scope, termId: termId);
    if (term == null || term.deleted) {
      throw StateError('Term not found in the active local scope.');
    }
    if (classLevelId != null && classLevelId.isNotEmpty) {
      await _requireClassLevel(classLevelId);
    }
    if (studentId != null && studentId.isNotEmpty) {
      final student =
          await _db.findStudentById(scope: scope, studentId: studentId);
      if (student == null || student.deleted) {
        throw StateError('Student not found in the active local scope.');
      }
    }

    final enrollments = await _db.getEnrollmentsForAcademicYear(
      term.academicYearId,
      scope: scope,
    );
    final students = await _db.getStudents(scope: scope);
    final classArms = await _db.getClassArms(scope: scope);
    final categories = await _db.getFeeCategories(scope: scope);
    final feeItems = await _db.getFeeStructureItems(scope: scope);
    final existingInvoices = await _db.getInvoices(scope: scope);

    final studentsById = {for (final student in students) student.id: student};
    final classArmsById = {for (final arm in classArms) arm.id: arm};
    final billedOneTimeCategoriesByStudentId = <String, Set<String>>{};
    for (final invoice in existingInvoices) {
      final billed = billedOneTimeCategoriesByStudentId.putIfAbsent(
        invoice.studentId,
        () => <String>{},
      );
      final lines = (jsonDecode(invoice.lineItemsJson) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (final line in lines) {
        if (line['billingTerm'] == 'one_time' &&
            line['feeCategoryId'] is String) {
          billed.add(line['feeCategoryId'] as String);
        }
      }
    }

    var created = 0;
    var skippedExisting = 0;
    var skippedNoCharges = 0;

    for (final enrollment in enrollments) {
      final student = studentsById[enrollment.studentId];
      final classArm = classArmsById[enrollment.classArmId];
      if (student == null || classArm == null) {
        continue;
      }
      if (student.status != 'active') {
        continue;
      }
      if (studentId != null &&
          studentId.isNotEmpty &&
          student.id != studentId) {
        continue;
      }
      if (classLevelId != null &&
          classLevelId.isNotEmpty &&
          classArm.classLevelId != classLevelId) {
        continue;
      }

      final existing = await _db.findInvoiceByStudentTerm(
        scope: scope,
        studentId: student.id,
        termId: term.id,
      );
      if (existing != null) {
        skippedExisting += 1;
        continue;
      }

      final lineItems = _resolveInvoiceLineItems(
        categories: categories,
        feeItems: feeItems,
        classLevelId: classArm.classLevelId,
        termId: term.id,
        previouslyBilledOneTimeCategoryIds:
            billedOneTimeCategoriesByStudentId[student.id] ?? const <String>{},
      );
      if (lineItems.isEmpty) {
        skippedNoCharges += 1;
        continue;
      }

      final totalAmount = lineItems.fold<double>(
        0,
        (sum, item) => sum + (item['amount'] as double),
      );
      final now = DateTime.now();
      final invoiceId = _uuid.v4();
      final invoiceCode =
          _buildInvoiceCode(termId: term.id, studentId: student.id);

      await _db.transaction(() async {
        await _db.upsertInvoice(
          InvoicesCompanion(
            id: Value(invoiceId),
            tenantId: Value(scope.tenantId),
            schoolId: Value(scope.schoolId),
            campusId: Value(student.campusId ?? scope.campusId),
            studentId: Value(student.id),
            academicYearId: Value(term.academicYearId),
            termId: Value(term.id),
            classArmId: Value(classArm.id),
            invoiceCode: Value(invoiceCode),
            status: const Value('draft'),
            lineItemsJson: Value(jsonEncode(lineItems)),
            totalAmount: Value(totalAmount),
            generatedByUserId: Value(_user.id),
            postedAt: const Value(null),
            syncStatus: const Value('local'),
            serverRevision: const Value(0),
            deleted: const Value(false),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        await _db.enqueueSyncChange(
          entityType: 'invoice',
          entityId: invoiceId,
          operation: 'create',
          payload: {
            'id': invoiceId,
            'tenantId': scope.tenantId,
            'schoolId': scope.schoolId,
            'campusId': student.campusId ?? scope.campusId,
            'studentId': student.id,
            'academicYearId': term.academicYearId,
            'termId': term.id,
            'classArmId': classArm.id,
            'invoiceCode': invoiceCode,
            'status': 'draft',
            'lineItems': lineItems,
            'totalAmount': totalAmount,
            'generatedByUserId': _user.id,
            'postedAt': null,
          },
        );
      });
      billedOneTimeCategoriesByStudentId
          .putIfAbsent(student.id, () => <String>{})
          .addAll(lineItems
              .where((line) => line['billingTerm'] == 'one_time')
              .map((line) => line['feeCategoryId'] as String));
      created += 1;
    }

    return {
      'created': created,
      'skippedExisting': skippedExisting,
      'skippedNoCharges': skippedNoCharges,
    };
  }

  Future<Map<String, dynamic>> transitionInvoiceStatus({
    required String invoiceId,
    required String targetStatus,
  }) async {
    final existing =
        await _db.findInvoiceById(scope: _scope, invoiceId: invoiceId);
    if (existing == null || existing.deleted) {
      throw StateError('Invoice not found in the active local scope.');
    }

    final allowed =
        (existing.status == 'draft' && targetStatus == 'confirmed') ||
            (existing.status == 'confirmed' && targetStatus == 'posted');
    if (!allowed) {
      throw StateError(
        'Invoice lifecycle transition ${existing.status} -> $targetStatus is not allowed.',
      );
    }

    final now = DateTime.now();
    final postedAt = targetStatus == 'posted' ? now : existing.postedAt;
    final lineItems = jsonDecode(existing.lineItemsJson) as List<dynamic>;

    await _db.transaction(() async {
      await _db.upsertInvoice(
        InvoicesCompanion(
          id: Value(existing.id),
          tenantId: Value(existing.tenantId),
          schoolId: Value(existing.schoolId),
          campusId: Value(existing.campusId),
          studentId: Value(existing.studentId),
          academicYearId: Value(existing.academicYearId),
          termId: Value(existing.termId),
          classArmId: Value(existing.classArmId),
          invoiceCode: Value(existing.invoiceCode),
          status: Value(targetStatus),
          lineItemsJson: Value(existing.lineItemsJson),
          totalAmount: Value(existing.totalAmount),
          generatedByUserId: Value(existing.generatedByUserId),
          postedAt: Value(postedAt),
          syncStatus: const Value('local'),
          serverRevision: Value(existing.serverRevision),
          deleted: const Value(false),
          createdAt: Value(existing.createdAt),
          updatedAt: Value(now),
        ),
      );
      await _db.enqueueSyncChange(
        entityType: 'invoice',
        entityId: existing.id,
        operation: 'update',
        payload: {
          'id': existing.id,
          'tenantId': existing.tenantId,
          'schoolId': existing.schoolId,
          'campusId': existing.campusId,
          'studentId': existing.studentId,
          'academicYearId': existing.academicYearId,
          'termId': existing.termId,
          'classArmId': existing.classArmId,
          'invoiceCode': existing.invoiceCode,
          'status': targetStatus,
          'lineItems': lineItems,
          'totalAmount': existing.totalAmount,
          'generatedByUserId': existing.generatedByUserId,
          'postedAt': postedAt?.toIso8601String(),
          'baseServerRevision': existing.serverRevision,
          'baseUpdatedAt': existing.updatedAt.toIso8601String(),
        },
      );
    });

    return {
      'id': existing.id,
      'status': targetStatus,
      'postedAt': postedAt?.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> createPayment({
    required String invoiceId,
    required double amount,
    required String paymentMode,
    required String paymentDate,
    required String reference,
    required String notes,
  }) async {
    final invoice =
        await _db.findInvoiceById(scope: _scope, invoiceId: invoiceId);
    if (invoice == null || invoice.deleted) {
      throw StateError('Invoice not found in the active local scope.');
    }
    if (invoice.status != 'posted') {
      throw StateError(
          'Payments can only be recorded against posted invoices.');
    }
    _requirePositiveAmount(amount);
    _requirePaymentMode(paymentMode);
    await _assertPaymentWithinOutstanding(invoiceId: invoiceId, amount: amount);

    final id = _uuid.v4();
    final now = DateTime.now();
    final normalizedReference = _nullIfBlank(reference);
    final normalizedNotes = _nullIfBlank(notes);
    final paymentCode = _buildPaymentCode(invoiceId: invoice.id);

    await _db.transaction(() async {
      await _db.upsertPayment(
        PaymentsCompanion(
          id: Value(id),
          tenantId: Value(invoice.tenantId),
          schoolId: Value(invoice.schoolId),
          campusId: Value(invoice.campusId),
          invoiceId: Value(invoice.id),
          paymentCode: Value(paymentCode),
          status: const Value('draft'),
          amount: Value(amount),
          paymentMode: Value(paymentMode),
          paymentDate: Value(paymentDate),
          reference: Value(normalizedReference),
          notes: Value(normalizedNotes),
          receivedByUserId: Value(_user.id),
          postedAt: const Value(null),
          syncStatus: const Value('local'),
          serverRevision: const Value(0),
          deleted: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _db.enqueueSyncChange(
        entityType: 'payment',
        entityId: id,
        operation: 'create',
        payload: {
          'id': id,
          'tenantId': invoice.tenantId,
          'schoolId': invoice.schoolId,
          'campusId': invoice.campusId,
          'invoiceId': invoice.id,
          'paymentCode': paymentCode,
          'status': 'draft',
          'amount': amount,
          'paymentMode': paymentMode,
          'paymentDate': paymentDate,
          'reference': normalizedReference,
          'notes': normalizedNotes,
          'receivedByUserId': _user.id,
          'postedAt': null,
        },
      );
    });

    return {
      'id': id,
      'paymentCode': paymentCode,
      'status': 'draft',
      'amount': amount,
    };
  }

  Future<Map<String, dynamic>> transitionPaymentStatus({
    required String paymentId,
    required String targetStatus,
  }) async {
    final existing =
        await _db.findPaymentById(scope: _scope, paymentId: paymentId);
    if (existing == null || existing.deleted) {
      throw StateError('Payment not found in the active local scope.');
    }

    final allowed =
        (existing.status == 'draft' && targetStatus == 'confirmed') ||
            (existing.status == 'confirmed' && targetStatus == 'posted');
    if (!allowed) {
      throw StateError(
        'Payment lifecycle transition ${existing.status} -> $targetStatus is not allowed.',
      );
    }

    final invoice =
        await _db.findInvoiceById(scope: _scope, invoiceId: existing.invoiceId);
    if (invoice == null || invoice.deleted) {
      throw StateError(
          'Referenced invoice was not found in the active local scope.');
    }
    if (invoice.status != 'posted') {
      throw StateError('Payments can only be posted against posted invoices.');
    }
    if (targetStatus == 'posted') {
      await _assertPaymentWithinOutstanding(
        invoiceId: existing.invoiceId,
        amount: existing.amount,
        excludePaymentId: existing.id,
      );
    }

    final now = DateTime.now();
    final postedAt = targetStatus == 'posted' ? now : existing.postedAt;
    await _db.transaction(() async {
      await _db.upsertPayment(
        PaymentsCompanion(
          id: Value(existing.id),
          tenantId: Value(existing.tenantId),
          schoolId: Value(existing.schoolId),
          campusId: Value(existing.campusId),
          invoiceId: Value(existing.invoiceId),
          paymentCode: Value(existing.paymentCode),
          status: Value(targetStatus),
          amount: Value(existing.amount),
          paymentMode: Value(existing.paymentMode),
          paymentDate: Value(existing.paymentDate),
          reference: Value(existing.reference),
          notes: Value(existing.notes),
          receivedByUserId: Value(existing.receivedByUserId),
          postedAt: Value(postedAt),
          syncStatus: const Value('local'),
          serverRevision: Value(existing.serverRevision),
          deleted: const Value(false),
          createdAt: Value(existing.createdAt),
          updatedAt: Value(now),
        ),
      );
      await _db.enqueueSyncChange(
        entityType: 'payment',
        entityId: existing.id,
        operation: 'update',
        payload: {
          'id': existing.id,
          'tenantId': existing.tenantId,
          'schoolId': existing.schoolId,
          'campusId': existing.campusId,
          'invoiceId': existing.invoiceId,
          'paymentCode': existing.paymentCode,
          'status': targetStatus,
          'amount': existing.amount,
          'paymentMode': existing.paymentMode,
          'paymentDate': existing.paymentDate,
          'reference': existing.reference,
          'notes': existing.notes,
          'receivedByUserId': existing.receivedByUserId,
          'postedAt': postedAt?.toIso8601String(),
          'baseServerRevision': existing.serverRevision,
          'baseUpdatedAt': existing.updatedAt.toIso8601String(),
        },
      );
    });

    return {
      'id': existing.id,
      'status': targetStatus,
      'postedAt': postedAt?.toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> createPaymentReversal({
    required String paymentId,
    required String reason,
  }) async {
    final payment =
        await _db.findPaymentById(scope: _scope, paymentId: paymentId);
    if (payment == null || payment.deleted) {
      throw StateError('Payment not found in the active local scope.');
    }
    if (payment.status != 'posted') {
      throw StateError('Only posted payments can be reversed.');
    }
    final existing = await _db.findPaymentReversalByPaymentId(
      scope: _scope,
      paymentId: paymentId,
    );
    if (existing != null) {
      throw StateError('A reversal already exists for this payment.');
    }

    final normalizedReason = _nullIfBlank(reason);
    if (normalizedReason == null) {
      throw StateError('Reversal reason is required.');
    }

    final now = DateTime.now();
    final id = _uuid.v4();
    await _db.transaction(() async {
      await _db.upsertPaymentReversal(
        PaymentReversalsCompanion(
          id: Value(id),
          tenantId: Value(payment.tenantId),
          schoolId: Value(payment.schoolId),
          campusId: Value(payment.campusId),
          paymentId: Value(payment.id),
          invoiceId: Value(payment.invoiceId),
          amount: Value(payment.amount),
          reason: Value(normalizedReason),
          reversedByUserId: Value(_user.id),
          syncStatus: const Value('local'),
          serverRevision: const Value(0),
          deleted: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _db.enqueueSyncChange(
        entityType: 'payment_reversal',
        entityId: id,
        operation: 'create',
        payload: {
          'id': id,
          'tenantId': payment.tenantId,
          'schoolId': payment.schoolId,
          'campusId': payment.campusId,
          'paymentId': payment.id,
          'invoiceId': payment.invoiceId,
          'amount': payment.amount,
          'reason': normalizedReason,
          'reversedByUserId': _user.id,
        },
      );
    });

    return {
      'id': id,
      'paymentId': payment.id,
      'amount': payment.amount,
    };
  }

  Future<Map<String, dynamic>> createFeeCategory({
    required String name,
    required String billingTerm,
    required bool isActive,
  }) async {
    final now = DateTime.now();
    final user = _user;
    final id = _uuid.v4();

    await _db.transaction(() async {
      await _db.upsertFeeCategory(
        FeeCategoriesCompanion(
          id: Value(id),
          tenantId: Value(user.tenantId!),
          schoolId: Value(user.schoolId!),
          name: Value(name),
          billingTerm: Value(billingTerm),
          isActive: Value(isActive),
          serverRevision: const Value(0),
          deleted: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _db.enqueueSyncChange(
        entityType: 'fee_category',
        entityId: id,
        operation: 'create',
        payload: {
          'id': id,
          'tenantId': user.tenantId,
          'schoolId': user.schoolId,
          'name': name,
          'billingTerm': billingTerm,
          'isActive': isActive,
        },
      );
    });

    return {
      'id': id,
      'tenantId': user.tenantId,
      'schoolId': user.schoolId,
      'name': name,
      'billingTerm': billingTerm,
      'isActive': isActive,
      'serverRevision': 0,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> updateFeeCategory({
    required String id,
    required String name,
    required String billingTerm,
    required bool isActive,
  }) async {
    final existing = await _db.findFeeCategoryById(
      scope: _scope,
      feeCategoryId: id,
    );
    if (existing == null || existing.deleted) {
      throw StateError('Fee category not found in the active local scope.');
    }

    final now = DateTime.now();
    await _db.transaction(() async {
      await _db.upsertFeeCategory(
        FeeCategoriesCompanion(
          id: Value(existing.id),
          tenantId: Value(existing.tenantId),
          schoolId: Value(existing.schoolId),
          name: Value(name),
          billingTerm: Value(billingTerm),
          isActive: Value(isActive),
          serverRevision: Value(existing.serverRevision),
          deleted: const Value(false),
          createdAt: Value(existing.createdAt),
          updatedAt: Value(now),
        ),
      );
      await _db.enqueueSyncChange(
        entityType: 'fee_category',
        entityId: existing.id,
        operation: 'update',
        payload: {
          'id': existing.id,
          'tenantId': existing.tenantId,
          'schoolId': existing.schoolId,
          'name': name,
          'billingTerm': billingTerm,
          'isActive': isActive,
          'baseServerRevision': existing.serverRevision,
          'baseUpdatedAt': existing.updatedAt.toIso8601String(),
        },
      );
    });

    return {
      'id': existing.id,
      'tenantId': existing.tenantId,
      'schoolId': existing.schoolId,
      'name': name,
      'billingTerm': billingTerm,
      'isActive': isActive,
      'serverRevision': existing.serverRevision,
      'createdAt': existing.createdAt.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> createFeeStructureItem({
    required String feeCategoryId,
    String? classLevelId,
    String? termId,
    required double amount,
    required String notes,
  }) async {
    final user = _user;
    await _requireFeeCategory(feeCategoryId);
    await _requireClassLevel(classLevelId);
    await _requireTerm(termId);
    await _assertFeeStructureRuleAvailable(
      feeCategoryId: feeCategoryId,
      classLevelId: classLevelId,
      termId: termId,
    );

    final now = DateTime.now();
    final id = _uuid.v4();
    final normalizedNotes = _nullIfBlank(notes);

    await _db.transaction(() async {
      await _db.upsertFeeStructureItem(
        FeeStructureItemsCompanion(
          id: Value(id),
          tenantId: Value(user.tenantId!),
          schoolId: Value(user.schoolId!),
          feeCategoryId: Value(feeCategoryId),
          classLevelId: Value(classLevelId),
          termId: Value(termId),
          amount: Value(amount),
          notes: Value(normalizedNotes),
          serverRevision: const Value(0),
          deleted: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _db.enqueueSyncChange(
        entityType: 'fee_structure_item',
        entityId: id,
        operation: 'create',
        payload: {
          'id': id,
          'tenantId': user.tenantId,
          'schoolId': user.schoolId,
          'feeCategoryId': feeCategoryId,
          'classLevelId': classLevelId,
          'termId': termId,
          'amount': amount,
          'notes': normalizedNotes,
        },
      );
    });

    return {
      'id': id,
      'tenantId': user.tenantId,
      'schoolId': user.schoolId,
      'feeCategoryId': feeCategoryId,
      'classLevelId': classLevelId,
      'termId': termId,
      'amount': amount,
      'notes': normalizedNotes,
      'serverRevision': 0,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> updateFeeStructureItem({
    required String id,
    required String feeCategoryId,
    String? classLevelId,
    String? termId,
    required double amount,
    required String notes,
  }) async {
    final existing = await _db.findFeeStructureItemById(
      scope: _scope,
      feeStructureItemId: id,
    );
    if (existing == null || existing.deleted) {
      throw StateError(
          'Fee structure item not found in the active local scope.');
    }

    await _requireFeeCategory(feeCategoryId);
    await _requireClassLevel(classLevelId);
    await _requireTerm(termId);
    await _assertFeeStructureRuleAvailable(
      feeCategoryId: feeCategoryId,
      classLevelId: classLevelId,
      termId: termId,
      excludeId: existing.id,
    );

    final now = DateTime.now();
    final normalizedNotes = _nullIfBlank(notes);
    await _db.transaction(() async {
      await _db.upsertFeeStructureItem(
        FeeStructureItemsCompanion(
          id: Value(existing.id),
          tenantId: Value(existing.tenantId),
          schoolId: Value(existing.schoolId),
          feeCategoryId: Value(feeCategoryId),
          classLevelId: Value(classLevelId),
          termId: Value(termId),
          amount: Value(amount),
          notes: Value(normalizedNotes),
          serverRevision: Value(existing.serverRevision),
          deleted: const Value(false),
          createdAt: Value(existing.createdAt),
          updatedAt: Value(now),
        ),
      );
      await _db.enqueueSyncChange(
        entityType: 'fee_structure_item',
        entityId: existing.id,
        operation: 'update',
        payload: {
          'id': existing.id,
          'tenantId': existing.tenantId,
          'schoolId': existing.schoolId,
          'feeCategoryId': feeCategoryId,
          'classLevelId': classLevelId,
          'termId': termId,
          'amount': amount,
          'notes': normalizedNotes,
          'baseServerRevision': existing.serverRevision,
          'baseUpdatedAt': existing.updatedAt.toIso8601String(),
        },
      );
    });

    return {
      'id': existing.id,
      'tenantId': existing.tenantId,
      'schoolId': existing.schoolId,
      'feeCategoryId': feeCategoryId,
      'classLevelId': classLevelId,
      'termId': termId,
      'amount': amount,
      'notes': normalizedNotes,
      'serverRevision': existing.serverRevision,
      'createdAt': existing.createdAt.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
  }

  Future<void> _requireFeeCategory(String feeCategoryId) async {
    final category = await _db.findFeeCategoryById(
      scope: _scope,
      feeCategoryId: feeCategoryId,
    );
    if (category == null || category.deleted) {
      throw StateError('Fee category not found in the active local scope.');
    }
  }

  Future<void> _requireClassLevel(String? classLevelId) async {
    if (classLevelId == null || classLevelId.isEmpty) {
      return;
    }
    final level = await _db.findClassLevelById(
      scope: _scope,
      classLevelId: classLevelId,
    );
    if (level == null || level.deleted) {
      throw StateError('Class level not found in the active local scope.');
    }
  }

  Future<void> _requireTerm(String? termId) async {
    if (termId == null || termId.isEmpty) {
      return;
    }
    final term = await _db.findTermById(scope: _scope, termId: termId);
    if (term == null || term.deleted) {
      throw StateError('Term not found in the active local scope.');
    }
  }

  Future<void> _assertFeeStructureRuleAvailable({
    required String feeCategoryId,
    String? classLevelId,
    String? termId,
    String? excludeId,
  }) async {
    final duplicate = await _db.findFeeStructureItemByRule(
      scope: _scope,
      feeCategoryId: feeCategoryId,
      classLevelId: classLevelId,
      termId: termId,
      excludeId: excludeId,
    );
    if (duplicate != null) {
      throw StateError(
        'A fee variation already exists for this category, class, and term combination.',
      );
    }
  }

  Future<void> _assertPaymentWithinOutstanding({
    required String invoiceId,
    required double amount,
    String? excludePaymentId,
  }) async {
    final invoice =
        await _db.findInvoiceById(scope: _scope, invoiceId: invoiceId);
    if (invoice == null || invoice.deleted) {
      throw StateError('Invoice not found in the active local scope.');
    }

    final payments = await _db.getPayments(scope: _scope, invoiceId: invoiceId);
    final reversals =
        await _db.getPaymentReversals(scope: _scope, invoiceId: invoiceId);
    final reversedPaymentIds = reversals.map((row) => row.paymentId).toSet();
    final postedTotal = payments
        .where((payment) =>
            payment.status == 'posted' &&
            payment.id != excludePaymentId &&
            !reversedPaymentIds.contains(payment.id))
        .fold<double>(0, (sum, payment) => sum + payment.amount);
    final outstanding = invoice.totalAmount - postedTotal;
    if (amount > outstanding + 0.0001) {
      throw StateError(
          'Payment amount exceeds the outstanding invoice balance.');
    }
  }

  void _requirePositiveAmount(double amount) {
    if (amount <= 0) {
      throw StateError('Payment amount must be greater than zero.');
    }
  }

  void _requirePaymentMode(String paymentMode) {
    if (!_paymentModes.contains(paymentMode)) {
      throw StateError('Unsupported payment mode.');
    }
  }

  String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  List<Map<String, dynamic>> _resolveInvoiceLineItems({
    required List<FeeCategory> categories,
    required List<FeeStructureItem> feeItems,
    required String classLevelId,
    required String termId,
    required Set<String> previouslyBilledOneTimeCategoryIds,
  }) {
    final lines = <Map<String, dynamic>>[];
    for (final category in categories.where((item) => item.isActive)) {
      if (category.billingTerm == 'one_time' &&
          previouslyBilledOneTimeCategoryIds.contains(category.id)) {
        continue;
      }
      final matches = feeItems.where((item) {
        if (item.deleted || item.feeCategoryId != category.id) {
          return false;
        }
        final classMatches =
            item.classLevelId == null || item.classLevelId == classLevelId;
        final termMatches = item.termId == null || item.termId == termId;
        return classMatches && termMatches;
      }).toList(growable: false);
      if (matches.isEmpty) {
        continue;
      }

      matches.sort((a, b) => _specificityScore(b, classLevelId, termId)
          .compareTo(_specificityScore(a, classLevelId, termId)));
      final chosen = matches.first;
      lines.add({
        'feeCategoryId': category.id,
        'description': category.name,
        'amount': chosen.amount,
        'billingTerm': category.billingTerm,
        'classLevelId': chosen.classLevelId,
        'termId': chosen.termId,
        'notes': chosen.notes,
      });
    }
    return lines;
  }

  int _specificityScore(
    FeeStructureItem item,
    String classLevelId,
    String termId,
  ) {
    var score = 0;
    if (item.classLevelId == classLevelId) {
      score += 2;
    }
    if (item.termId == termId) {
      score += 1;
    }
    return score;
  }

  String _buildInvoiceCode({
    required String termId,
    required String studentId,
  }) {
    final compactTerm = termId.replaceAll('-', '');
    final compactStudent = studentId.replaceAll('-', '');
    final termToken = compactTerm.substring(
        0, compactTerm.length < 6 ? compactTerm.length : 6);
    final studentToken = compactStudent.substring(
      0,
      compactStudent.length < 6 ? compactStudent.length : 6,
    );
    final millis = DateTime.now().millisecondsSinceEpoch.toString();
    final tail = millis.substring(millis.length - 6);
    return 'INV-$termToken-$studentToken-$tail';
  }

  String _buildPaymentCode({required String invoiceId}) {
    final compactInvoice = invoiceId.replaceAll('-', '');
    final invoiceToken = compactInvoice.substring(
      0,
      compactInvoice.length < 6 ? compactInvoice.length : 6,
    );
    final millis = DateTime.now().millisecondsSinceEpoch.toString();
    final tail = millis.substring(millis.length - 6);
    return 'PAY-$invoiceToken-$tail';
  }
}

const List<String> _paymentModes = [
  'cash',
  'mtn_momo',
  'telecel_cash',
  'bank',
];
