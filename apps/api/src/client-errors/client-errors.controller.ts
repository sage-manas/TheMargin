import { Body, Controller, HttpCode, Post, Req } from "@nestjs/common";
import type { Request } from "express";
import { ClientErrorsRequestSchema } from "@the-margin/contracts";
import { parse } from "../common/zod.js";
import { NoCsrf } from "../auth/guards.js";
import { RateLimit } from "../auth/auth.controller.js";
import { ClientErrorsService } from "./client-errors.service.js";

@Controller("client-errors")
export class ClientErrorsController {
  constructor(private readonly errors: ClientErrorsService) {}

  /**
   * Sent with `keepalive` as a page unloads, without a session or CSRF token:
   * it changes nothing a user owns. The Origin check still applies.
   */
  @Post()
  @HttpCode(204)
  @NoCsrf()
  @RateLimit("reports")
  async report(@Body() body: unknown, @Req() req: Request): Promise<void> {
    await this.errors.record(parse(ClientErrorsRequestSchema, body).reports, req.headers["user-agent"]);
  }
}
