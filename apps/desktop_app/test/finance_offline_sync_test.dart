import 'dart:convert';
import 'dart:io';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/ui/finance/finance_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _OfflineFinanceAuthService extends AuthService {
  _OfflineFinanceAuthService() : super(backendBaseUrl: 'http://localhost:3000');

  @override
  AuthUser? get currentUser => const AuthUser(
        id: 'user-1',
        email: 'cashier@example.com',
        fullName: 'Cashier User',
        role: 'cashier',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
      );

  @override
  bool get isOfflineSession => true;

  @override
  Dio createAuthenticatedClient() {
    throw StateError('Offline finance test must not use the network.');
  }
}

void main() {
  late AppDatabase db;
  late FinanceService service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.runMigrations();
    service = FinanceService(_OfflineFinanceAuthService(), db);

    await db.upsertClassLevel(
      ClassLevelsCacheCompanion.insert(
        id: 'class-level-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        name: 'Basic 1',
        sortOrder: const Value(1),
      ),
    );
    await db.upsertAcademicYear(
      AcademicYearsCacheCompanion.insert(
        id: 'year-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        label: '2026/2027',
        startDate: '2026-09-01',
        endDate: '2027-07-31',
      ),
    );
    await db.upsertTerm(
      TermsCacheCompanion.insert(
        id: 'term-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        academicYearId: 'year-1',
        name: 'Term 1',
        termNumber: 1,
        startDate: '2026-09-01',
        endDate: '2026-12-18',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test(
      'queues offline fee category and variation creation with school-scoped payload',
      () async {
    final category = await service.createFeeCategory(
      name: 'Tuition',
      billingTerm: 'per_term',
      isActive: true,
    );
    await service.createFeeStructureItem(
      feeCategoryId: '${category['id']}',
      classLevelId: 'class-level-1',
      termId: 'term-1',
      amount: 450,
      notes: 'Main term fee',
    );

    final categories = await db.select(db.feeCategories).get();
    final items = await db.select(db.feeStructureItems).get();
    final queueItems = await db.select(db.syncQueue).get();

    expect(categories, hasLength(1));
    expect(items, hasLength(1));
    expect(queueItems, hasLength(2));

    final categoryPayload =
        jsonDecode(queueItems.first.payloadJson) as Map<String, dynamic>;
    final itemPayload =
        jsonDecode(queueItems.last.payloadJson) as Map<String, dynamic>;

    expect(queueItems.first.entityType, 'fee_category');
    expect(queueItems.last.entityType, 'fee_structure_item');
    expect(categoryPayload['tenantId'], 'tenant-1');
    expect(categoryPayload['schoolId'], 'school-1');
    expect(itemPayload['feeCategoryId'], category['id']);
    expect(itemPayload['classLevelId'], 'class-level-1');
    expect(itemPayload['termId'], 'term-1');
    expect(itemPayload['amount'], 450.0);
  });

  test('generates draft invoices offline and advances through confirm and post',
      () async {
    final category = await service.createFeeCategory(
      name: 'Tuition',
      billingTerm: 'per_term',
      isActive: true,
    );
    await service.createFeeStructureItem(
      feeCategoryId: '${category['id']}',
      classLevelId: 'class-level-1',
      termId: 'term-1',
      amount: 450,
      notes: 'Main term fee',
    );

    await db.upsertStudent(
      StudentsCompanion.insert(
        id: 'student-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: const Value('campus-1'),
        firstName: 'Ama',
        lastName: 'Mensah',
        status: const Value('active'),
        syncStatus: const Value('local'),
      ),
    );
    await db.upsertClassArm(
      ClassArmsCacheCompanion.insert(
        id: 'arm-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        classLevelId: 'class-level-1',
        arm: 'A',
        displayName: 'Basic 1A',
      ),
    );
    await db.upsertEnrollment(
      EnrollmentsCompanion.insert(
        id: 'enrollment-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        studentId: 'student-1',
        classArmId: 'arm-1',
        academicYearId: 'year-1',
        enrollmentDate: '2026-09-02',
      ),
    );

    final result = await service.generateInvoices(termId: 'term-1');
    expect(result['created'], 1);

    final invoices = await db.select(db.invoices).get();
    expect(invoices, hasLength(1));
    expect(invoices.single.status, 'draft');
    expect(invoices.single.totalAmount, 450);

    await service.transitionInvoiceStatus(
      invoiceId: invoices.single.id,
      targetStatus: 'confirmed',
    );
    await service.transitionInvoiceStatus(
      invoiceId: invoices.single.id,
      targetStatus: 'posted',
    );

    final updated = await db.select(db.invoices).getSingle();
    expect(updated.status, 'posted');
    expect(updated.postedAt != null, isTrue);

    final invoiceQueueItems = await (db.select(db.syncQueue)
          ..where((row) => row.entityType.equals('invoice')))
        .get();
    expect(invoiceQueueItems, hasLength(1));
    final payload = jsonDecode(invoiceQueueItems.single.payloadJson)
        as Map<String, dynamic>;
    expect(payload['status'], 'posted');
    expect(payload['studentId'], 'student-1');
  });

  test('rejects duplicate fee variation rules for the same category scope',
      () async {
    final category = await service.createFeeCategory(
      name: 'Tuition',
      billingTerm: 'per_term',
      isActive: true,
    );

    await service.createFeeStructureItem(
      feeCategoryId: '${category['id']}',
      classLevelId: 'class-level-1',
      termId: 'term-1',
      amount: 450,
      notes: 'Main term fee',
    );

    await expectLater(
      () => service.createFeeStructureItem(
        feeCategoryId: '${category['id']}',
        classLevelId: 'class-level-1',
        termId: 'term-1',
        amount: 500,
        notes: 'Conflicting duplicate',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('already exists'),
        ),
      ),
    );

    final items = await db.select(db.feeStructureItems).get();
    final queueItems = await db.select(db.syncQueue).get();
    expect(items, hasLength(1));
    expect(queueItems.where((row) => row.entityType == 'fee_structure_item'),
        hasLength(1));
  });

  test('does not rebill one-time fee categories in later term invoices',
      () async {
    await db.upsertTerm(
      TermsCacheCompanion.insert(
        id: 'term-2',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        academicYearId: 'year-1',
        name: 'Term 2',
        termNumber: 2,
        startDate: '2027-01-10',
        endDate: '2027-04-09',
      ),
    );

    final tuition = await service.createFeeCategory(
      name: 'Tuition',
      billingTerm: 'per_term',
      isActive: true,
    );
    final admission = await service.createFeeCategory(
      name: 'Admission',
      billingTerm: 'one_time',
      isActive: true,
    );
    await service.createFeeStructureItem(
      feeCategoryId: '${tuition['id']}',
      classLevelId: 'class-level-1',
      amount: 450,
      notes: 'Tuition charge',
    );
    await service.createFeeStructureItem(
      feeCategoryId: '${admission['id']}',
      classLevelId: 'class-level-1',
      amount: 100,
      notes: 'One-time admission fee',
    );

    await db.upsertStudent(
      StudentsCompanion.insert(
        id: 'student-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: const Value('campus-1'),
        firstName: 'Ama',
        lastName: 'Mensah',
        status: const Value('active'),
        syncStatus: const Value('local'),
      ),
    );
    await db.upsertClassArm(
      ClassArmsCacheCompanion.insert(
        id: 'arm-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        classLevelId: 'class-level-1',
        arm: 'A',
        displayName: 'Basic 1A',
      ),
    );
    await db.upsertEnrollment(
      EnrollmentsCompanion.insert(
        id: 'enrollment-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        studentId: 'student-1',
        classArmId: 'arm-1',
        academicYearId: 'year-1',
        enrollmentDate: '2026-09-02',
      ),
    );

    await service.generateInvoices(termId: 'term-1');
    await service.generateInvoices(termId: 'term-2');

    final invoices = await db.getInvoices(
      scope: const LocalDataScope(
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
      ),
    );
    expect(invoices, hasLength(2));

    final term1Lines = (jsonDecode(
      invoices
          .singleWhere((invoice) => invoice.termId == 'term-1')
          .lineItemsJson,
    ) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final term2Lines = (jsonDecode(
      invoices
          .singleWhere((invoice) => invoice.termId == 'term-2')
          .lineItemsJson,
    ) as List<dynamic>)
        .cast<Map<String, dynamic>>();

    expect(term1Lines.map((line) => line['description']),
        containsAll(['Tuition', 'Admission']));
    expect(term2Lines.map((line) => line['description']), contains('Tuition'));
    expect(term2Lines.map((line) => line['description']),
        isNot(contains('Admission')));
    expect(
      invoices.singleWhere((invoice) => invoice.termId == 'term-1').totalAmount,
      550,
    );
    expect(
      invoices.singleWhere((invoice) => invoice.termId == 'term-2').totalAmount,
      450,
    );
  });

  test(
      'records offline payments, blocks overpayment, and uses reversal entries',
      () async {
    final category = await service.createFeeCategory(
      name: 'Tuition',
      billingTerm: 'per_term',
      isActive: true,
    );
    await service.createFeeStructureItem(
      feeCategoryId: '${category['id']}',
      classLevelId: 'class-level-1',
      termId: 'term-1',
      amount: 450,
      notes: 'Main term fee',
    );

    await db.upsertStudent(
      StudentsCompanion.insert(
        id: 'student-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: const Value('campus-1'),
        firstName: 'Ama',
        lastName: 'Mensah',
        status: const Value('active'),
        syncStatus: const Value('local'),
      ),
    );
    await db.upsertClassArm(
      ClassArmsCacheCompanion.insert(
        id: 'arm-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        classLevelId: 'class-level-1',
        arm: 'A',
        displayName: 'Basic 1A',
      ),
    );
    await db.upsertEnrollment(
      EnrollmentsCompanion.insert(
        id: 'enrollment-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        studentId: 'student-1',
        classArmId: 'arm-1',
        academicYearId: 'year-1',
        enrollmentDate: '2026-09-02',
      ),
    );

    await service.generateInvoices(termId: 'term-1');
    final invoice = (await db.select(db.invoices).get()).single;
    await service.transitionInvoiceStatus(
      invoiceId: invoice.id,
      targetStatus: 'confirmed',
    );
    await service.transitionInvoiceStatus(
      invoiceId: invoice.id,
      targetStatus: 'posted',
    );

    final created = await service.createPayment(
      invoiceId: invoice.id,
      amount: 300,
      paymentMode: 'cash',
      paymentDate: '2026-09-03',
      reference: '',
      notes: 'First tranche',
    );
    await service.transitionPaymentStatus(
      paymentId: '${created['id']}',
      targetStatus: 'confirmed',
    );
    await service.transitionPaymentStatus(
      paymentId: '${created['id']}',
      targetStatus: 'posted',
    );

    await expectLater(
      () => service.createPayment(
        invoiceId: invoice.id,
        amount: 200,
        paymentMode: 'bank',
        paymentDate: '2026-09-04',
        reference: 'BANK-1',
        notes: '',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('outstanding'),
        ),
      ),
    );

    final payment = (await db.getPayments(
      scope: const LocalDataScope(
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
      ),
    ))
        .single;
    expect(payment.status, 'posted');

    final reversal = await service.createPaymentReversal(
      paymentId: payment.id,
      reason: 'Entered against wrong family account',
    );
    expect(reversal['paymentId'], payment.id);

    final reversals = await db.getPaymentReversals(
      scope: const LocalDataScope(
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
      ),
    );
    expect(reversals, hasLength(1));

    await expectLater(
      () => service.createPaymentReversal(
        paymentId: payment.id,
        reason: 'Duplicate reversal should fail',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('already exists'),
        ),
      ),
    );

    final paymentQueueItems = await (db.select(db.syncQueue)
          ..where((row) => row.entityType.equals('payment')))
        .get();
    final reversalQueueItems = await (db.select(db.syncQueue)
          ..where((row) => row.entityType.equals('payment_reversal')))
        .get();
    expect(paymentQueueItems, hasLength(1));
    expect(reversalQueueItems, hasLength(1));

    final paymentPayload = jsonDecode(paymentQueueItems.single.payloadJson)
        as Map<String, dynamic>;
    expect(paymentPayload['status'], 'posted');
    expect(paymentPayload['amount'], 300.0);
  });

  test(
      'builds offline finance reports from posted records with reversals and campus scope',
      () async {
    final category = await service.createFeeCategory(
      name: 'Tuition',
      billingTerm: 'per_term',
      isActive: true,
    );
    await service.createFeeStructureItem(
      feeCategoryId: '${category['id']}',
      classLevelId: 'class-level-1',
      termId: 'term-1',
      amount: 450,
      notes: 'Main term fee',
    );

    await db.upsertStudent(
      StudentsCompanion.insert(
        id: 'student-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: const Value('campus-1'),
        firstName: 'Ama',
        lastName: 'Mensah',
        status: const Value('active'),
        syncStatus: const Value('local'),
      ),
    );
    await db.upsertClassArm(
      ClassArmsCacheCompanion.insert(
        id: 'arm-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        classLevelId: 'class-level-1',
        arm: 'A',
        displayName: 'Basic 1A',
      ),
    );
    await db.upsertEnrollment(
      EnrollmentsCompanion.insert(
        id: 'enrollment-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        studentId: 'student-1',
        classArmId: 'arm-1',
        academicYearId: 'year-1',
        enrollmentDate: '2026-09-02',
      ),
    );

    await service.generateInvoices(termId: 'term-1');
    final invoice = (await db.select(db.invoices).get()).single;
    await service.transitionInvoiceStatus(
      invoiceId: invoice.id,
      targetStatus: 'confirmed',
    );
    await service.transitionInvoiceStatus(
      invoiceId: invoice.id,
      targetStatus: 'posted',
    );

    final firstPayment = await service.createPayment(
      invoiceId: invoice.id,
      amount: 300,
      paymentMode: 'cash',
      paymentDate: '2026-09-03',
      reference: '',
      notes: '',
    );
    await service.transitionPaymentStatus(
      paymentId: '${firstPayment['id']}',
      targetStatus: 'confirmed',
    );
    await service.transitionPaymentStatus(
      paymentId: '${firstPayment['id']}',
      targetStatus: 'posted',
    );
    await service.createPaymentReversal(
      paymentId: '${firstPayment['id']}',
      reason: 'Wrong receipt',
    );

    final secondPayment = await service.createPayment(
      invoiceId: invoice.id,
      amount: 100,
      paymentMode: 'mtn_momo',
      paymentDate: '2026-09-03',
      reference: 'MOMO-1',
      notes: '',
    );
    await service.transitionPaymentStatus(
      paymentId: '${secondPayment['id']}',
      targetStatus: 'confirmed',
    );
    await service.transitionPaymentStatus(
      paymentId: '${secondPayment['id']}',
      targetStatus: 'posted',
    );

    await db.upsertInvoice(
      InvoicesCompanion.insert(
        id: 'other-campus-invoice',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: const Value('campus-2'),
        studentId: 'student-other-campus',
        academicYearId: 'year-1',
        termId: 'term-1',
        classArmId: 'arm-1',
        invoiceCode: 'INV-OTHER',
        status: const Value('posted'),
        lineItemsJson: '[]',
        totalAmount: 999,
        syncStatus: const Value('synced'),
      ),
    );

    final report = await service.loadReportWorkspace();

    expect(report.totalPostedInvoices, 450);
    expect(report.totalCollected, 100);
    expect(report.totalReversed, 300);
    expect(report.totalOutstanding, 350);
    expect(report.arrears, hasLength(1));
    expect(report.arrears.single.studentName, 'Ama Mensah');
    expect(report.arrears.single.className, 'Basic 1A');
    expect(report.arrears.single.outstandingAmount, 350);
    expect(report.dailyCollections, hasLength(1));
    expect(report.dailyCollections.single.paymentDate, '2026-09-03');
    expect(report.dailyCollections.single.paymentMode, 'mtn_momo');
    expect(report.dailyCollections.single.totalAmount, 100);
    expect(report.classSummaries, hasLength(1));
    expect(report.classSummaries.single.invoiceCount, 1);
    expect(report.classSummaries.single.billedAmount, 450);
    expect(report.classSummaries.single.collectedAmount, 100);
  });

  test('generates and exports scoped PDF receipts for posted payments',
      () async {
    final now = DateTime.parse('2026-09-03T10:00:00Z');
    await db.upsertSchoolProfile(
      SchoolProfileCacheCompanion(
        id: const Value('school-1'),
        tenantId: const Value('tenant-1'),
        name: const Value('Pilot Basic School'),
        shortName: const Value('PBS'),
        schoolType: const Value('basic'),
        address: const Value('Market Road'),
        region: const Value('Greater Accra'),
        district: const Value('Ga East'),
        contactPhone: const Value('0300000000'),
        contactEmail: const Value('admin@example.com'),
        onboardingDefaultsJson: const Value('{}'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await db.upsertCampusProfile(
      CampusProfileCacheCompanion(
        id: const Value('campus-1'),
        tenantId: const Value('tenant-1'),
        schoolId: const Value('school-1'),
        name: const Value('Main Campus'),
        address: const Value('Market Road'),
        contactPhone: const Value('0300000000'),
        registrationCode: const Value('MAIN'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    final category = await service.createFeeCategory(
      name: 'Tuition',
      billingTerm: 'per_term',
      isActive: true,
    );
    await service.createFeeStructureItem(
      feeCategoryId: '${category['id']}',
      classLevelId: 'class-level-1',
      termId: 'term-1',
      amount: 450,
      notes: 'Main term fee',
    );
    await db.upsertStudent(
      StudentsCompanion.insert(
        id: 'student-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: const Value('campus-1'),
        firstName: 'Ama',
        lastName: 'Mensah',
        status: const Value('active'),
        syncStatus: const Value('local'),
      ),
    );
    await db.upsertClassArm(
      ClassArmsCacheCompanion.insert(
        id: 'arm-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        classLevelId: 'class-level-1',
        arm: 'A',
        displayName: 'Basic 1A',
      ),
    );
    await db.upsertEnrollment(
      EnrollmentsCompanion.insert(
        id: 'enrollment-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        studentId: 'student-1',
        classArmId: 'arm-1',
        academicYearId: 'year-1',
        enrollmentDate: '2026-09-02',
      ),
    );

    await service.generateInvoices(termId: 'term-1');
    final invoice = (await db.select(db.invoices).get()).single;
    await service.transitionInvoiceStatus(
      invoiceId: invoice.id,
      targetStatus: 'confirmed',
    );
    await service.transitionInvoiceStatus(
      invoiceId: invoice.id,
      targetStatus: 'posted',
    );
    final payment = await service.createPayment(
      invoiceId: invoice.id,
      amount: 300,
      paymentMode: 'cash',
      paymentDate: '2026-09-03',
      reference: 'CASH-1',
      notes: '',
    );
    await service.transitionPaymentStatus(
      paymentId: '${payment['id']}',
      targetStatus: 'confirmed',
    );
    await service.transitionPaymentStatus(
      paymentId: '${payment['id']}',
      targetStatus: 'posted',
    );

    final receipt = await service.loadPostedPaymentReceipt('${payment['id']}');
    final pdfBytes =
        await service.buildPostedPaymentReceiptPdf('${payment['id']}');
    final outputDir = await Directory.systemTemp.createTemp('receipt-test-');
    final file = await service.exportPostedPaymentReceiptPdf(
      paymentId: '${payment['id']}',
      outputDirectoryPath: outputDir.path,
    );

    expect(receipt.schoolName, 'Pilot Basic School');
    expect(receipt.campusName, 'Main Campus');
    expect(receipt.studentName, 'Ama Mensah');
    expect(receipt.amountPaid, 300);
    expect(receipt.outstandingAfterReceipt, 150);
    expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');
    expect(await file.exists(), isTrue);
    expect(file.path.endsWith('.pdf'), isTrue);

    await service.createPaymentReversal(
      paymentId: '${payment['id']}',
      reason: 'Wrong receipt',
    );
    await expectLater(
      () => service.loadPostedPaymentReceipt('${payment['id']}'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Reversed payments'),
        ),
      ),
    );
  });
}
