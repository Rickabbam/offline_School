import * as dotenv from 'dotenv';
import * as bcrypt from 'bcrypt';
import { AppDataSource } from '../data-source';
import { User } from '../../users/user.entity';
import { UserRole } from '../../users/user-role.enum';

dotenv.config();

const supportedRoles = Object.values(UserRole);

async function main() {
  const adminEmail =
    process.env.DEFAULT_ADMIN_EMAIL?.trim().toLowerCase() ??
    'admin@offline-school.local';
  const adminPassword =
    process.env.DEFAULT_ADMIN_PASSWORD?.trim() ?? 'ChangeMe123!';
  const adminFullName =
    process.env.DEFAULT_ADMIN_FULL_NAME?.trim() ?? 'Offline School Admin';

  await AppDataSource.initialize();

  try {
    const users = AppDataSource.getRepository(User);
    const existingAdmin = await users.findOne({
      where: { email: adminEmail, deleted: false },
    });

    const passwordHash = await bcrypt.hash(adminPassword, 12);

    if (existingAdmin) {
      existingAdmin.fullName = adminFullName;
      existingAdmin.passwordHash = passwordHash;
      existingAdmin.role = UserRole.Admin;
      existingAdmin.isActive = true;
      await users.save(existingAdmin);
      console.log(`Updated bootstrap admin user: ${adminEmail}`);
    } else {
      await users.save(
        users.create({
          email: adminEmail,
          passwordHash,
          fullName: adminFullName,
          role: UserRole.Admin,
          isActive: true,
          deleted: false,
        }),
      );
      console.log(`Created bootstrap admin user: ${adminEmail}`);
    }

    console.log(`Supported roles: ${supportedRoles.join(', ')}`);
    console.log(
      'Roles are enum-backed in the users table; no separate roles table is required.',
    );
  } finally {
    await AppDataSource.destroy();
  }
}

main().catch((error) => {
  console.error('Role seed failed:', error);
  process.exitCode = 1;
});
