import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import {
  AcademicYear,
  ClassArm,
  ClassLevel,
  GradingScheme,
  Subject,
  Term,
} from "../academic/academic.entity";
import { Applicant } from "../admissions/applicant.entity";
import { AttendanceRecord } from "../attendance/attendance-record.entity";
import { AuditModule } from "../audit/audit.module";
import { Campus } from "../campuses/campus.entity";
import {
  FeeCategory,
  FeeStructureItem,
  Invoice,
  Payment,
  PaymentReversal,
} from "../finance/finance.entity";
import { School } from "../schools/school.entity";
import { Staff, StaffTeachingAssignment } from "../staff/staff.entity";
import { Enrollment, Guardian, Student } from "../students/student.entity";
import { SyncController } from "./sync.controller";
import { SyncReconciliationRequest } from "./sync-reconciliation-request.entity";
import { SyncPushReceipt } from "./sync-push-receipt.entity";
import { SyncService } from "./sync.service";

@Module({
  imports: [
    AuditModule,
    TypeOrmModule.forFeature([
      Student,
      Guardian,
      Enrollment,
      FeeCategory,
      FeeStructureItem,
      Invoice,
      Payment,
      PaymentReversal,
      Staff,
      Applicant,
      AttendanceRecord,
      AcademicYear,
      Term,
      ClassLevel,
      ClassArm,
      Subject,
      School,
      GradingScheme,
      Campus,
      StaffTeachingAssignment,
      SyncPushReceipt,
      SyncReconciliationRequest,
    ]),
  ],
  providers: [SyncService],
  controllers: [SyncController],
})
export class SyncModule {}
