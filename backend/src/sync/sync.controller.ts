import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Request,
  UseGuards,
} from "@nestjs/common";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { Roles } from "../auth/roles.decorator";
import { RolesGuard } from "../auth/roles.guard";
import { User } from "../users/user.entity";
import { UserRole } from "../users/user-role.enum";
import {
  SyncPullQueryDto,
  SyncPushRequestDto,
  SyncReconciliationAckDto,
  SyncReconciliationCurrentQueryDto,
  SyncReconciliationRequestDto,
} from "./dto/sync.dto";
import { SyncService } from "./sync.service";

@Controller("sync")
@UseGuards(JwtAuthGuard, RolesGuard)
export class SyncController {
  constructor(private readonly syncService: SyncService) {}

  @Get("pull")
  @Roles(
    UserRole.Admin,
    UserRole.Cashier,
    UserRole.Teacher,
    UserRole.SupportAdmin,
  )
  pull(@Request() req: { user: User }, @Query() query: SyncPullQueryDto) {
    return this.syncService.pull(
      req.user,
      query.entity_type,
      query.since,
      query.limit,
    );
  }

  @Post("push")
  @Roles(
    UserRole.Admin,
    UserRole.Cashier,
    UserRole.Teacher,
    UserRole.SupportAdmin,
  )
  push(@Request() req: { user: User }, @Body() body: SyncPushRequestDto) {
    return this.syncService.push(req.user, body);
  }

  @Post("reconciliation-requests")
  @Roles(UserRole.Admin, UserRole.SupportAdmin, UserRole.SupportTechnician)
  createReconciliationRequest(
    @Request() req: { user: User },
    @Body() body: SyncReconciliationRequestDto,
  ) {
    return this.syncService.createReconciliationRequest(req.user, body);
  }

  @Get("reconciliation-requests/current")
  @Roles(
    UserRole.Admin,
    UserRole.Cashier,
    UserRole.Teacher,
    UserRole.SupportAdmin,
    UserRole.SupportTechnician,
  )
  getCurrentReconciliationRequest(
    @Request() req: { user: User },
    @Query() query: SyncReconciliationCurrentQueryDto,
  ) {
    return this.syncService.getPendingReconciliationRequest(
      req.user,
      query.device_id,
    );
  }

  @Post("reconciliation-requests/:id/ack")
  @Roles(
    UserRole.Admin,
    UserRole.Cashier,
    UserRole.Teacher,
    UserRole.SupportAdmin,
    UserRole.SupportTechnician,
  )
  acknowledgeReconciliationRequest(
    @Request() req: { user: User },
    @Param("id") id: string,
    @Body() body: SyncReconciliationAckDto,
  ) {
    return this.syncService.acknowledgeReconciliationRequest(
      req.user,
      id,
      body.device_id,
    );
  }
}
