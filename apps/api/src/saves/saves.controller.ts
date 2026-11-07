import { Body, Controller, Get, Param, Put } from "@nestjs/common";
import { BackupSaveRequestSchema, PutSaveRequestSchema, type CloudSave } from "@the-margin/contracts";
import { ApiError } from "../common/errors.js";
import { parse } from "../common/zod.js";
import { Auth, CurrentSession } from "../auth/guards.js";
import type { ActiveSession } from "../auth/sessions.service.js";
import { assertSupportedVersion, SavesService } from "./saves.service.js";

@Controller("saves")
@Auth("required")
export class SavesController {
  constructor(private readonly saves: SavesService) {}

  @Get("main")
  get(@CurrentSession() s: ActiveSession): Promise<CloudSave> {
    return this.saves.get(s.user.id);
  }

  @Put("main")
  async put(@CurrentSession() s: ActiveSession, @Body() body: unknown): Promise<{ revision: number }> {
    assertSupportedVersion(body);
    const req = parse(PutSaveRequestSchema, body);
    return { revision: await this.saves.put(s.user.id, req.baseRevision, req.save) };
  }

  @Put("backup-:ts")
  async backup(@CurrentSession() s: ActiveSession, @Param("ts") ts: string, @Body() body: unknown): Promise<{ slot: string }> {
    if (!/^\d{1,16}$/.test(ts)) throw new ApiError("VALIDATION_FAILED", "Backup slots are named backup-<unix ms>.");
    assertSupportedVersion(body);
    return { slot: await this.saves.backup(s.user.id, ts, parse(BackupSaveRequestSchema, body).save) };
  }
}
