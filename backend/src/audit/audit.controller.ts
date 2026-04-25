import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  Request,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { User } from '../users/user.entity';
import { UserRole } from '../users/user-role.enum';
import { AuditQueryDto } from './dto/audit-query.dto';
import { OperatorAuditEventDto } from './dto/operator-audit-event.dto';
import { AuditService } from './audit.service';

@Controller('audit')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AuditController {
  constructor(private readonly audit: AuditService) {}

  @Get('logs')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  listLogs(@Request() req: { user: User }, @Query() query: AuditQueryDto) {
    return this.audit.listRecent(req.user, query);
  }

  @Post('operator-events')
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  recordOperatorEvent(
    @Request() req: { user: User },
    @Body() dto: OperatorAuditEventDto,
  ) {
    return this.audit.recordOperatorEvent(req.user, dto);
  }
}
