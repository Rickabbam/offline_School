import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { School } from '../schools/school.entity';

@Entity('campuses')
export class Campus {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'tenant_id', type: 'uuid' })
  tenantId: string;

  @Column({ name: 'school_id', type: 'uuid' })
  schoolId: string;

  @ManyToOne(() => School, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'school_id' })
  school: School;

  @Column({ type: 'varchar', length: 255 })
  name: string;

  @Column({ type: 'varchar', length: 255, nullable: true })
  address: string | null;

  @Column({ name: 'contact_phone', type: 'varchar', length: 50, nullable: true })
  contactPhone: string | null;

  /** Set once the desktop installer registers this campus installation. */
  @Column({ name: 'registration_code', type: 'varchar', length: 100, nullable: true })
  registrationCode: string | null;

  @Column({ name: 'deleted', type: 'boolean', default: false })
  deleted: boolean;

  @Column({ name: 'server_revision', type: 'bigint', default: 0 })
  serverRevision: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
