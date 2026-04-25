import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';
import { Gender } from '../students/student.entity';

export enum ApplicantStatus {
  Applied = 'applied',
  Screened = 'screened',
  Admitted = 'admitted',
  Enrolled = 'enrolled',
  Rejected = 'rejected',
  Withdrawn = 'withdrawn',
}

@Entity('applicants')
export class Applicant {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'tenant_id', type: 'uuid' })
  tenantId: string;

  @Column({ name: 'school_id', type: 'uuid' })
  schoolId: string;

  @Column({ name: 'campus_id', type: 'uuid', nullable: true })
  campusId: string | null;

  @Column({ name: 'first_name', type: 'varchar', length: 100 })
  firstName: string;

  @Column({ name: 'middle_name', type: 'varchar', length: 100, nullable: true })
  middleName: string | null;

  @Column({ name: 'last_name', type: 'varchar', length: 100 })
  lastName: string;

  @Column({ name: 'date_of_birth', type: 'date', nullable: true })
  dateOfBirth: string | null;

  @Column({ type: 'enum', enum: Gender, nullable: true })
  gender: Gender | null;

  /** Applying for this class level, e.g. "Basic 1" */
  @Column({ name: 'class_level_id', type: 'uuid', nullable: true })
  classLevelId: string | null;

  /** Target academic year for enrollment */
  @Column({ name: 'academic_year_id', type: 'uuid', nullable: true })
  academicYearId: string | null;

  @Column({
    type: 'enum',
    enum: ApplicantStatus,
    default: ApplicantStatus.Applied,
  })
  status: ApplicantStatus;

  /** Guardian/parent contact for the application */
  @Column({ name: 'guardian_name', type: 'varchar', length: 200, nullable: true })
  guardianName: string | null;

  @Column({ name: 'guardian_phone', type: 'varchar', length: 50, nullable: true })
  guardianPhone: string | null;

  @Column({ name: 'guardian_email', type: 'varchar', length: 255, nullable: true })
  guardianEmail: string | null;

  /** Notes about physical documents received */
  @Column({ name: 'document_notes', type: 'text', nullable: true })
  documentNotes: string | null;

  /** Set when applicant is converted to a full student record */
  @Column({ name: 'student_id', type: 'uuid', nullable: true })
  studentId: string | null;

  @Column({ name: 'admitted_at', type: 'timestamptz', nullable: true })
  admittedAt: Date | null;

  @Column({ name: 'sync_status', type: 'varchar', length: 50, default: 'synced' })
  syncStatus: string;

  @Column({ name: 'server_revision', type: 'bigint', default: 0 })
  serverRevision: number;

  @Column({ name: 'deleted', type: 'boolean', default: false })
  deleted: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
