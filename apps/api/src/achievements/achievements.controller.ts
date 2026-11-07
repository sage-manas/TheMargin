import { Controller, Get, HttpCode, Param, Post } from "@nestjs/common";
import { Auth, CurrentSession } from "../auth/guards.js";
import type { ActiveSession } from "../auth/sessions.service.js";
import { AchievementsService } from "./achievements.service.js";

@Controller("achievements")
export class AchievementsController {
  constructor(private readonly achievements: AchievementsService) {}

  @Get()
  @Auth("optional")
  list(@CurrentSession() s: ActiveSession | null) {
    return this.achievements.list(s?.user.id ?? null);
  }

  @Post(":code/unlock")
  @HttpCode(200)
  @Auth("required")
  unlock(@CurrentSession() s: ActiveSession, @Param("code") code: string) {
    return this.achievements.unlock(s.user.id, code);
  }
}
