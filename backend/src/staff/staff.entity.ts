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

  @Column({ name: 'deleted', type: 'boolean', default: false })
  deleted: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
