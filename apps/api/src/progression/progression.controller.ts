import { Controller, Get, HttpCode, Param, Post } from "@nestjs/common";
import type { Progression } from "@the-margin/contracts";
import { Auth, CurrentSession } from "../auth/guards.js";
import type { ActiveSession } from "../auth/sessions.service.js";
import { ProgressionService } from "./progression.service.js";

@Controller("progression")
@Auth("required")
export class ProgressionController {
  constructor(private readonly progression: ProgressionService) {}

  @Get()
  list(@CurrentSession() s: ActiveSession): Promise<Progression> {
    return this.progression.list(s.user.id);
  }

  @Post(":chapterId/complete")
  @HttpCode(200)
  complete(@CurrentSession() s: ActiveSession, @Param("chapterId") chapterId: string): Promise<Progression[number]> {
    return this.progression.complete(s.user.id, chapterId);
  }
}
