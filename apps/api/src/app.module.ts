import { Module, type DynamicModule, type ExecutionContext } from "@nestjs/common";
import { APP_FILTER, APP_GUARD } from "@nestjs/core";
import { ThrottlerGuard, ThrottlerModule } from "@nestjs/throttler";
import { CONFIG, type Config } from "./config.js";
import { ErrorFilter } from "./common/error.filter.js";
import { PrismaService } from "./common/prisma.service.js";
import { AuthController } from "./auth/auth.controller.js";
import { AuthService } from "./auth/auth.service.js";
import { CsrfGuard, SessionGuard } from "./auth/guards.js";
import { SessionsService } from "./auth/sessions.service.js";
import { SavesController } from "./saves/saves.controller.js";
import { SavesService } from "./saves/saves.service.js";
import { ProgressionController } from "./progression/progression.controller.js";
import { ProgressionService } from "./progression/progression.service.js";
import { AchievementsController } from "./achievements/achievements.controller.js";
import { AchievementsService } from "./achievements/achievements.service.js";
import { SettingsController } from "./settings/settings.controller.js";
import { MeController } from "./me/me.controller.js";
import { HealthController } from "./health/health.controller.js";

/** Applies a named limit only to routes marked with @RateLimit(name). */
const only = (name: string) => (ctx: ExecutionContext) => Reflect.getMetadata("rateLimit", ctx.getHandler()) !== name;

@Module({})
export class AppModule {
  static forConfig(config: Config): DynamicModule {
    const { windowMs: ttl, ...limits } = config.rateLimits;
    return {
      module: AppModule,
      imports: [
        ThrottlerModule.forRoot([
          { name: "default", ttl, limit: limits.default },
          { name: "register", ttl, limit: limits.register, skipIf: only("register") },
          { name: "login", ttl, limit: limits.login, skipIf: only("login") },
        ]),
      ],
      controllers: [HealthController, AuthController, MeController, SavesController, ProgressionController, AchievementsController, SettingsController],
      providers: [
        { provide: CONFIG, useValue: config },
        PrismaService,
        SessionsService,
        AuthService,
        SavesService,
        AchievementsService,
        ProgressionService,
        // Guards run in this order: rate limit, CSRF, then session lookup.
        { provide: APP_GUARD, useClass: ThrottlerGuard },
        { provide: APP_GUARD, useClass: CsrfGuard },
        { provide: APP_GUARD, useClass: SessionGuard },
        { provide: APP_FILTER, useClass: ErrorFilter },
      ],
    };
  }
}
