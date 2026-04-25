import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

export enum StudentStatus {
  Active = 'active',
  Withdrawn = 'withdrawn',
  Graduated = 'graduated',
  Transferred = 'transferred',
}

export enum Gender {
  Male = 'male',
  Female = 'female',
  Other = 'other',
}

@Entity('students')
export class Student {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'tenant_id', type: 'uuid' })
  tenantId: string;

  @Column({ name: 'school_id', type: 'uuid' })
  schoolId: string;

  @Column({ name: 'campus_id', type: 'uuid', nullable: true })
  campusId: string | null;

  @Column({ name: 'student_number', type: 'varchar', length: 50, nullable: true })
  studentNumber: string | null;

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

  @Column({
    type: 'enum',
    enum: StudentStatus,
    default: StudentStatus.Active,
  })
  status: StudentStatus;

  @Column({ name: 'profile_photo_url', type: 'varchar', length: 512, nullable: true })
  profilePhotoUrl: string | null;

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

export enum GuardianRelationship {
  Father = 'father',
  Mother = 'mother',
  Guardian = 'guardian',
  Sibling = 'sibling',
  Other = 'other',
}

@Entity('guardians')
export class Guardian {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'tenant_id', type: 'uuid' })
  tenantId: string;

  @Column({ name: 'school_id', type: 'uuid' })
  schoolId: string;

  @Column({ name: 'student_id', type: 'uuid' })
  studentId: string;

  @Column({ name: 'first_name', type: 'varchar', length: 100 })
  firstName: string;

  @Column({ name: 'last_name', type: 'varchar', length: 100 })
  lastName: string;

  @Column({ type: 'enum', enum: GuardianRelationship, default: GuardianRelationship.Guardian })
  relationship: GuardianRelationship;

  @Column({ type: 'varchar', length: 50, nullable: true })
  phone: string | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  email: string | null;

  @Column({ name: 'is_primary', type: 'boolean', default: false })
  isPrimary: boolean;

  @Column({ name: 'server_revision', type: 'bigint', default: 0 })
  serverRevision: number;

  @Column({ name: 'deleted', type: 'boolean', default: false })
  deleted: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}

@Entity('enrollments')
export class Enrollment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'tenant_id', type: 'uuid' })
  tenantId: string;

  @Column({ name: 'school_id', type: 'uuid' })
  schoolId: string;

  @Column({ name: 'student_id', type: 'uuid' })
  studentId: string;

  @Column({ name: 'class_arm_id', type: 'uuid' })
  classArmId: string;

  @Column({ name: 'academic_year_id', type: 'uuid' })
  academicYearId: string;

  @Column({ name: 'enrollment_date', type: 'date' })
  enrollmentDate: string;

  @Column({ name: 'server_revision', type: 'bigint', default: 0 })
  serverRevision: number;

  @Column({ name: 'deleted', type: 'boolean', default: false })
  deleted: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
