import { Body, Controller, Get, Patch } from "@nestjs/common";
import { ProfilePatchSchema, type User } from "@the-margin/contracts";
import { PrismaService } from "../common/prisma.service.js";
import { parse } from "../common/zod.js";
import { Auth, CurrentSession } from "../auth/guards.js";
import type { ActiveSession } from "../auth/sessions.service.js";

@Controller("me")
@Auth("required")
export class MeController {
  constructor(private readonly db: PrismaService) {}

  @Get()
  me(@CurrentSession() s: ActiveSession): User {
    return s.user;
  }

  @Patch("profile")
  async patch(@CurrentSession() s: ActiveSession, @Body() body: unknown): Promise<User> {
    const p = parse(ProfilePatchSchema, body);
    const profile = await this.db.playerProfile.update({ where: { userId: s.user.id }, data: p });
    return { ...s.user, displayName: profile.displayName, avatar: profile.avatar };
  }
}
