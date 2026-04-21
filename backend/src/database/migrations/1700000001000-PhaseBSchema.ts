import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Phase B migration — creates all tables for Steps 7–13:
 *   users, devices, tenants, schools, campuses,
 *   academic_years, terms, class_levels, class_arms, subjects, grading_schemes,
 *   students, guardians, enrollments, staff, applicants, attendance_records
 */
export class PhaseBSchema1700000001000 implements MigrationInterface {
  name = 'PhaseBSchema1700000001000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ─── ENUM types ────────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TYPE user_role AS ENUM (
        'admin','cashier','teacher','parent','student',
        'support_technician','support_admin'
      )
    `);
    await queryRunner.query(`
      CREATE TYPE tenant_status AS ENUM ('active','suspended','trial')
    `);
    await queryRunner.query(`
      CREATE TYPE school_type AS ENUM ('basic','jhs','shs','combined')
    `);
    await queryRunner.query(`
      CREATE TYPE gender AS ENUM ('male','female','other')
    `);
    await queryRunner.query(`
      CREATE TYPE student_status AS ENUM ('active','withdrawn','graduated','transferred')
    `);
    await queryRunner.query(`
      CREATE TYPE guardian_relationship AS ENUM ('father','mother','guardian','sibling','other')
    `);
    await queryRunner.query(`
      CREATE TYPE employment_type AS ENUM ('permanent','contract','volunteer')
    `);
    await queryRunner.query(`
      CREATE TYPE applicant_status AS ENUM (
        'applied','screened','admitted','enrolled','rejected','withdrawn'
      )
    `);
    await queryRunner.query(`
      CREATE TYPE attendance_status AS ENUM ('present','absent','late','excused')
    `);

    // ─── tenants ───────────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE tenants (
        id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        name          VARCHAR(255) NOT NULL,
        status        tenant_status NOT NULL DEFAULT 'trial',
        contact_email VARCHAR(255),
        contact_phone VARCHAR(50),
        deleted       BOOLEAN NOT NULL DEFAULT FALSE,
        created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    // ─── schools ───────────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE schools (
        id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id     UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
        name          VARCHAR(255) NOT NULL,
        short_name    VARCHAR(100),
        school_type   school_type NOT NULL DEFAULT 'basic',
        address       VARCHAR(255),
        region        VARCHAR(50),
        district      VARCHAR(50),
        contact_phone VARCHAR(50),
        contact_email VARCHAR(255),
        deleted       BOOLEAN NOT NULL DEFAULT FALSE,
        created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    // ─── campuses ──────────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE campuses (
        id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id         UUID NOT NULL,
        school_id         UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
        name              VARCHAR(255) NOT NULL,
        address           VARCHAR(255),
        contact_phone     VARCHAR(50),
        registration_code VARCHAR(100),
        deleted           BOOLEAN NOT NULL DEFAULT FALSE,
        created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    // ─── users ─────────────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE users (
        id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        email         VARCHAR(255) NOT NULL UNIQUE,
        password_hash VARCHAR(255) NOT NULL,
        full_name     VARCHAR(255) NOT NULL,
        role          user_role NOT NULL DEFAULT 'teacher',
        tenant_id     UUID,
        school_id     UUID,
        campus_id     UUID,
        is_active     BOOLEAN NOT NULL DEFAULT TRUE,
        deleted       BOOLEAN NOT NULL DEFAULT FALSE,
        created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(`CREATE INDEX idx_users_email ON users(email)`);

    // ─── devices ───────────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE devices (
        id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        device_name          VARCHAR(255) NOT NULL,
        device_fingerprint   VARCHAR(512) NOT NULL UNIQUE,
        offline_token_hash   VARCHAR(512) NOT NULL,
        tenant_id            UUID,
        campus_id            UUID,
        registered_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        is_active            BOOLEAN NOT NULL DEFAULT TRUE,
        last_used_at         TIMESTAMPTZ,
        created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    // ─── academic_years ────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE academic_years (
        id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id  UUID NOT NULL,
        school_id  UUID NOT NULL,
        label      VARCHAR(20) NOT NULL,
        start_date DATE NOT NULL,
        end_date   DATE NOT NULL,
        is_current BOOLEAN NOT NULL DEFAULT FALSE,
        deleted    BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    // ─── terms ─────────────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE terms (
        id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id        UUID NOT NULL,
        school_id        UUID NOT NULL,
        academic_year_id UUID NOT NULL REFERENCES academic_years(id),
        name             VARCHAR(100) NOT NULL,
        term_number      INT NOT NULL,
        start_date       DATE NOT NULL,
        end_date         DATE NOT NULL,
        is_current       BOOLEAN NOT NULL DEFAULT FALSE,
        deleted          BOOLEAN NOT NULL DEFAULT FALSE,
        created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    // ─── class_levels ──────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE class_levels (
        id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id  UUID NOT NULL,
        school_id  UUID NOT NULL,
        name       VARCHAR(100) NOT NULL,
        sort_order INT NOT NULL DEFAULT 0,
        deleted    BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    // ─── class_arms ────────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE class_arms (
        id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id       UUID NOT NULL,
        school_id       UUID NOT NULL,
        class_level_id  UUID NOT NULL REFERENCES class_levels(id),
        arm             VARCHAR(50) NOT NULL,
        display_name    VARCHAR(150) NOT NULL,
        deleted         BOOLEAN NOT NULL DEFAULT FALSE,
        created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    // ─── subjects ──────────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE subjects (
        id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id  UUID NOT NULL,
        school_id  UUID NOT NULL,
        name       VARCHAR(150) NOT NULL,
        code       VARCHAR(50),
        deleted    BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    // ─── grading_schemes ───────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE grading_schemes (
        id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id  UUID NOT NULL,
        school_id  UUID NOT NULL,
        name       VARCHAR(100) NOT NULL,
        bands      JSONB NOT NULL DEFAULT '[]',
        is_default BOOLEAN NOT NULL DEFAULT FALSE,
        deleted    BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    // ─── students ──────────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE students (
        id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id         UUID NOT NULL,
        school_id         UUID NOT NULL,
        campus_id         UUID,
        student_number    VARCHAR(50),
        first_name        VARCHAR(100) NOT NULL,
        middle_name       VARCHAR(100),
        last_name         VARCHAR(100) NOT NULL,
        date_of_birth     DATE,
        gender            gender,
        status            student_status NOT NULL DEFAULT 'active',
        profile_photo_url VARCHAR(512),
        sync_status       VARCHAR(50) NOT NULL DEFAULT 'synced',
        deleted           BOOLEAN NOT NULL DEFAULT FALSE,
        created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(`CREATE INDEX idx_students_school ON students(school_id)`);

    // ─── guardians ─────────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE guardians (
        id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id    UUID NOT NULL,
        school_id    UUID NOT NULL,
        student_id   UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
        first_name   VARCHAR(100) NOT NULL,
        last_name    VARCHAR(100) NOT NULL,
        relationship guardian_relationship NOT NULL DEFAULT 'guardian',
        phone        VARCHAR(50),
        email        VARCHAR(255),
        is_primary   BOOLEAN NOT NULL DEFAULT FALSE,
        deleted      BOOLEAN NOT NULL DEFAULT FALSE,
        created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    // ─── enrollments ───────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE enrollments (
        id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id        UUID NOT NULL,
        school_id        UUID NOT NULL,
        student_id       UUID NOT NULL REFERENCES students(id),
        class_arm_id     UUID NOT NULL REFERENCES class_arms(id),
        academic_year_id UUID NOT NULL REFERENCES academic_years(id),
        enrollment_date  DATE NOT NULL,
        deleted          BOOLEAN NOT NULL DEFAULT FALSE,
        created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    // ─── staff ─────────────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE staff (
        id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id       UUID NOT NULL,
        school_id       UUID NOT NULL,
        campus_id       UUID,
        user_id         UUID,
        staff_number    VARCHAR(50),
        first_name      VARCHAR(100) NOT NULL,
        middle_name     VARCHAR(100),
        last_name       VARCHAR(100) NOT NULL,
        gender          gender,
        phone           VARCHAR(50),
        email           VARCHAR(255),
        system_role     user_role NOT NULL DEFAULT 'teacher',
        employment_type employment_type NOT NULL DEFAULT 'permanent',
        date_joined     DATE,
        is_active       BOOLEAN NOT NULL DEFAULT TRUE,
        sync_status     VARCHAR(50) NOT NULL DEFAULT 'synced',
        deleted         BOOLEAN NOT NULL DEFAULT FALSE,
        created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    // ─── applicants ────────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE applicants (
        id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id        UUID NOT NULL,
        school_id        UUID NOT NULL,
        campus_id        UUID,
        first_name       VARCHAR(100) NOT NULL,
        middle_name      VARCHAR(100),
        last_name        VARCHAR(100) NOT NULL,
        date_of_birth    DATE,
        gender           gender,
        class_level_id   UUID,
        academic_year_id UUID,
        status           applicant_status NOT NULL DEFAULT 'applied',
        guardian_name    VARCHAR(200),
        guardian_phone   VARCHAR(50),
        guardian_email   VARCHAR(255),
        document_notes   TEXT,
        student_id       UUID,
        admitted_at      TIMESTAMPTZ,
        sync_status      VARCHAR(50) NOT NULL DEFAULT 'synced',
        deleted          BOOLEAN NOT NULL DEFAULT FALSE,
        created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    // ─── attendance_records ────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE attendance_records (
        id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id            UUID NOT NULL,
        school_id            UUID NOT NULL,
        campus_id            UUID,
        student_id           UUID NOT NULL REFERENCES students(id),
        class_arm_id         UUID NOT NULL REFERENCES class_arms(id),
        academic_year_id     UUID NOT NULL REFERENCES academic_years(id),
        term_id              UUID NOT NULL REFERENCES terms(id),
        attendance_date      DATE NOT NULL,
        status               attendance_status NOT NULL DEFAULT 'present',
        notes                TEXT,
        recorded_by_user_id  UUID,
        sync_status          VARCHAR(50) NOT NULL DEFAULT 'synced',
        deleted              BOOLEAN NOT NULL DEFAULT FALSE,
        created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE (student_id, class_arm_id, attendance_date)
      )
    `);
    await queryRunner.query(`
      CREATE INDEX idx_attendance_class_date
        ON attendance_records(class_arm_id, attendance_date)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS attendance_records`);
    await queryRunner.query(`DROP TABLE IF EXISTS applicants`);
    await queryRunner.query(`DROP TABLE IF EXISTS staff`);
    await queryRunner.query(`DROP TABLE IF EXISTS enrollments`);
    await queryRunner.query(`DROP TABLE IF EXISTS guardians`);
    await queryRunner.query(`DROP TABLE IF EXISTS students`);
    await queryRunner.query(`DROP TABLE IF EXISTS grading_schemes`);
    await queryRunner.query(`DROP TABLE IF EXISTS subjects`);
    await queryRunner.query(`DROP TABLE IF EXISTS class_arms`);
    await queryRunner.query(`DROP TABLE IF EXISTS class_levels`);
    await queryRunner.query(`DROP TABLE IF EXISTS terms`);
    await queryRunner.query(`DROP TABLE IF EXISTS academic_years`);
    await queryRunner.query(`DROP TABLE IF EXISTS devices`);
    await queryRunner.query(`DROP TABLE IF EXISTS users`);
    await queryRunner.query(`DROP TABLE IF EXISTS campuses`);
    await queryRunner.query(`DROP TABLE IF EXISTS schools`);
    await queryRunner.query(`DROP TABLE IF EXISTS tenants`);
    await queryRunner.query(`DROP TYPE IF EXISTS attendance_status`);
    await queryRunner.query(`DROP TYPE IF EXISTS applicant_status`);
    await queryRunner.query(`DROP TYPE IF EXISTS employment_type`);
    await queryRunner.query(`DROP TYPE IF EXISTS guardian_relationship`);
    await queryRunner.query(`DROP TYPE IF EXISTS student_status`);
    await queryRunner.query(`DROP TYPE IF EXISTS gender`);
    await queryRunner.query(`DROP TYPE IF EXISTS school_type`);
    await queryRunner.query(`DROP TYPE IF EXISTS tenant_status`);
    await queryRunner.query(`DROP TYPE IF EXISTS user_role`);
  }
}
