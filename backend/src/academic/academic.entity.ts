import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('academic_years')
export class AcademicYear {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'tenant_id', type: 'uuid' })
  tenantId: string;

  @Column({ name: 'school_id', type: 'uuid' })
  schoolId: string;

  /** e.g. "2024/2025" */
  @Column({ type: 'varchar', length: 20 })
  label: string;

  @Column({ name: 'start_date', type: 'date' })
  startDate: string;

  @Column({ name: 'end_date', type: 'date' })
  endDate: string;

  @Column({ name: 'is_current', type: 'boolean', default: false })
  isCurrent: boolean;

  @Column({ name: 'deleted', type: 'boolean', default: false })
  deleted: boolean;

  @Column({ name: 'server_revision', type: 'bigint', default: 0 })
  serverRevision: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}

@Entity('terms')
export class Term {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'tenant_id', type: 'uuid' })
  tenantId: string;

  @Column({ name: 'school_id', type: 'uuid' })
  schoolId: string;

  @Column({ name: 'academic_year_id', type: 'uuid' })
  academicYearId: string;

  /** e.g. "Term 1", "First Term" */
  @Column({ type: 'varchar', length: 100 })
  name: string;

  @Column({ name: 'term_number', type: 'int' })
  termNumber: number;

  @Column({ name: 'start_date', type: 'date' })
  startDate: string;

  @Column({ name: 'end_date', type: 'date' })
  endDate: string;

  @Column({ name: 'is_current', type: 'boolean', default: false })
  isCurrent: boolean;

  @Column({ name: 'deleted', type: 'boolean', default: false })
  deleted: boolean;

  @Column({ name: 'server_revision', type: 'bigint', default: 0 })
  serverRevision: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}

@Entity('class_levels')
export class ClassLevel {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'tenant_id', type: 'uuid' })
  tenantId: string;

  @Column({ name: 'school_id', type: 'uuid' })
  schoolId: string;

  /** e.g. "Basic 1", "JHS 2", "SHS 3" */
  @Column({ type: 'varchar', length: 100 })
  name: string;

  @Column({ name: 'sort_order', type: 'int', default: 0 })
  sortOrder: number;

  @Column({ name: 'deleted', type: 'boolean', default: false })
  deleted: boolean;

  @Column({ name: 'server_revision', type: 'bigint', default: 0 })
  serverRevision: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}

@Entity('class_arms')
export class ClassArm {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'tenant_id', type: 'uuid' })
  tenantId: string;

  @Column({ name: 'school_id', type: 'uuid' })
  schoolId: string;

  @Column({ name: 'class_level_id', type: 'uuid' })
  classLevelId: string;

  /** e.g. "A", "B", "Gold" */
  @Column({ type: 'varchar', length: 50 })
  arm: string;

  /** Full display name e.g. "Basic 1A" */
  @Column({ name: 'display_name', type: 'varchar', length: 150 })
  displayName: string;

  @Column({ name: 'deleted', type: 'boolean', default: false })
  deleted: boolean;

  @Column({ name: 'server_revision', type: 'bigint', default: 0 })
  serverRevision: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}

@Entity('subjects')
export class Subject {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'tenant_id', type: 'uuid' })
  tenantId: string;

  @Column({ name: 'school_id', type: 'uuid' })
  schoolId: string;

  @Column({ type: 'varchar', length: 150 })
  name: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  code: string | null;

  @Column({ name: 'deleted', type: 'boolean', default: false })
  deleted: boolean;

  @Column({ name: 'server_revision', type: 'bigint', default: 0 })
  serverRevision: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}

@Entity('grading_schemes')
export class GradingScheme {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'tenant_id', type: 'uuid' })
  tenantId: string;

  @Column({ name: 'school_id', type: 'uuid' })
  schoolId: string;

  @Column({ type: 'varchar', length: 100 })
  name: string;

  /**
   * JSON array of grade bands, e.g.:
   * [{"grade":"A1","min":80,"max":100,"remark":"Excellent"},...]
   */
  @Column({ type: 'jsonb' })
  bands: object;

  @Column({ name: 'is_default', type: 'boolean', default: false })
  isDefault: boolean;

  @Column({ name: 'deleted', type: 'boolean', default: false })
  deleted: boolean;

  @Column({ name: 'server_revision', type: 'bigint', default: 0 })
  serverRevision: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
