import { MigrationInterface, QueryRunner } from "typeorm";

export class OnboardingDefaults1700000002000 implements MigrationInterface {
  name = "OnboardingDefaults1700000002000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE schools
      ADD COLUMN onboarding_defaults JSONB NOT NULL DEFAULT '{}'::jsonb
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE schools
      DROP COLUMN IF EXISTS onboarding_defaults
    `);
  }
}
