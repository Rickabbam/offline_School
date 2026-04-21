import {
  Body,
  Controller,
  Post,
  Request,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '../users/user-role.enum';
import { User } from '../users/user.entity';
import { OnboardingService } from './onboarding.service';
import { BootstrapSchoolSetupDto } from './dto/bootstrap-school.dto';

@Controller('onboarding')
@UseGuards(JwtAuthGuard, RolesGuard)
export class OnboardingController {
  constructor(private readonly onboardingService: OnboardingService) {}

  @Post('bootstrap-school')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  bootstrapSchool(
    @Request() req: { user: User },
    @Body() dto: BootstrapSchoolSetupDto,
  ) {
    return this.onboardingService.bootstrapSchoolSetup(req.user.id, dto);
  }
}
