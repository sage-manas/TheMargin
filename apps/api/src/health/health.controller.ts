import { Controller, Get } from "@nestjs/common";
import { SkipThrottle } from "@nestjs/throttler";
import { ApiError } from "../common/errors.js";
import { PrismaService } from "../common/prisma.service.js";

@Controller("health")
@SkipThrottle()
export class HealthController {
  constructor(private readonly db: PrismaService) {}

  @Get()
  async health(): Promise<{ status: "ok"; db: "ok" }> {
    try {
      await this.db.$queryRaw`SELECT 1`;
    } catch {
      throw new ApiError("INTERNAL", "The database isn't reachable.", {}, 503);
    }
    return { status: "ok", db: "ok" };
  }
}
