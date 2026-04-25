import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';
import { UserRole } from '../users/user-role.enum';
import { Gender } from '../students/student.entity';

export enum EmploymentType {
  Permanent = 'permanent',
  Contract = 'contract',
  Volunteer = 'volunteer',
}

export enum StaffAssignmentType {
  ClassTeacher = 'class_teacher',
  SubjectTeacher = 'subject_teacher',
}

@Entity('staff')
export class Staff {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'tenant_id', type: 'uuid' })
  tenantId: string;

  @Column({ name: 'school_id', type: 'uuid' })
  schoolId: string;

  @Column({ name: 'campus_id', type: 'uuid', nullable: true })
  campusId: string | null;

  /** Linked user account (nullable — staff can exist before they log in). */
  @Column({ name: 'user_id', type: 'uuid', nullable: true })
  userId: string | null;

  @Column({ name: 'staff_number', type: 'varchar', length: 50, nullable: true })
  staffNumber: string | null;

  @Column({ name: 'first_name', type: 'varchar', length: 100 })
  firstName: string;

  @Column({ name: 'middle_name', type: 'varchar', length: 100, nullable: true })
  middleName: string | null;

  @Column({ name: 'last_name', type: 'varchar', length: 100 })
  lastName: string;

  @Column({ type: 'enum', enum: Gender, nullable: true })
  gender: Gender | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  phone: string | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  email: string | null;

  @Column({ type: 'varchar', length: 150, nullable: true })
  department: string | null;

  @Column({
    name: 'system_role',
    type: 'enum',
    enum: UserRole,
    default: UserRole.Teacher,
  })
  systemRole: UserRole;

  @Column({
    name: 'employment_type',
    type: 'enum',
    enum: EmploymentType,
    default: EmploymentType.Permanent,
  })
  employmentType: EmploymentType;

  @Column({ name: 'date_joined', type: 'date', nullable: true })
  dateJoined: string | null;

  @Column({ name: 'is_active', type: 'boolean', default: true })
  isActive: boolean;

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

@Entity('staff_teaching_assignments')
export class StaffTeachingAssignment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'tenant_id', type: 'uuid' })
  tenantId: string;

  @Column({ name: 'school_id', type: 'uuid' })
  schoolId: string;

  @Column({ name: 'staff_id', type: 'uuid' })
  staffId: string;

  @Column({
    name: 'assignment_type',
    type: 'enum',
    enum: StaffAssignmentType,
  })
  assignmentType: StaffAssignmentType;

  @Column({ name: 'subject_id', type: 'uuid', nullable: true })
  subjectId: string | null;

  @Column({ name: 'class_arm_id', type: 'uuid', nullable: true })
  classArmId: string | null;

  @Column({ name: 'server_revision', type: 'bigint', default: 0 })
  serverRevision: number;

  @Column({ name: 'deleted', type: 'boolean', default: false })
  deleted: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
