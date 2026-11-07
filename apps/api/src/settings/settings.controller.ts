import { Body, Controller, Get, Put } from "@nestjs/common";
import { DEFAULT_SETTINGS, SettingsSchema, type Settings } from "@the-margin/contracts";
import { PrismaService } from "../common/prisma.service.js";
import { parse } from "../common/zod.js";
import { Auth, CurrentSession } from "../auth/guards.js";
import type { ActiveSession } from "../auth/sessions.service.js";

// Settings are a small versioned document, separate from saves so they never
// cause a progress conflict (SAVE_SCHEMA §3).
@Controller("settings")
@Auth("required")
export class SettingsController {
  constructor(private readonly db: PrismaService) {}

  @Get()
  async get(@CurrentSession() s: ActiveSession): Promise<Settings> {
    const row = await this.db.playerSettings.findUnique({ where: { userId: s.user.id } });
    const stored = row ? SettingsSchema.safeParse(row.payload) : null;
    return stored?.success ? stored.data : DEFAULT_SETTINGS;
  }

  @Put()
  async put(@CurrentSession() s: ActiveSession, @Body() body: unknown): Promise<Settings> {
    const settings = parse(SettingsSchema, body);
    const data = { settingsVersion: settings.version, payload: settings };
    await this.db.playerSettings.upsert({ where: { userId: s.user.id }, create: { ...data, userId: s.user.id }, update: data });
    return settings;
  }
}
