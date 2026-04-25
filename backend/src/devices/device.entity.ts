import {
  Entity,
  Column,
  Index,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../users/user.entity';

@Entity('devices')
export class Device {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** Human-readable name, e.g. "Admin Office PC" */
  @Column({ name: 'device_name', type: 'varchar', length: 255 })
  deviceName: string;

  /** Unique fingerprint generated on first registration. */
  @Index({ unique: true })
  @Column({ name: 'device_fingerprint', type: 'varchar', length: 512 })
  deviceFingerprint: string;

  /** Long-lived offline token stored encrypted on the device. */
  @Column({ name: 'offline_token_hash', type: 'varchar', length: 512 })
  offlineTokenHash: string;

  @Column({ name: 'tenant_id', type: 'uuid', nullable: true })
  tenantId: string | null;

  @Column({ name: 'school_id', type: 'uuid', nullable: true })
  schoolId: string | null;

  @Column({ name: 'campus_id', type: 'uuid', nullable: true })
  campusId: string | null;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'registered_by_user_id' })
  registeredBy: User;

  @Column({ name: 'registered_by_user_id', type: 'uuid' })
  registeredByUserId: string;

  @Column({ name: 'is_active', type: 'boolean', default: true })
  isActive: boolean;

  @Column({ name: 'last_used_at', type: 'timestamptz', nullable: true })
  lastUsedAt: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
