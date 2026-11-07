import "reflect-metadata";
import { NestFactory } from "@nestjs/core";
import type { NestExpressApplication } from "@nestjs/platform-express";
import cookieParser from "cookie-parser";
import helmet from "helmet";
import { MAX_SAVE_BYTES } from "@the-margin/contracts";
import { AppModule } from "./app.module.js";
import type { Config } from "./config.js";

/** Builds the API (shared by main.ts and the integration tests). */
export async function createApp(config: Config, opts: { logger?: false } = {}): Promise<NestExpressApplication> {
  const app = await NestFactory.create<NestExpressApplication>(AppModule.forConfig(config), { bodyParser: false, ...opts });
  app.set("trust proxy", config.trustProxy);
  app.setGlobalPrefix("v1");
  app.use(helmet());
  app.use(cookieParser());
  // A save (≤ 64 KB) plus its envelope; anything bigger is refused unread.
  app.useBodyParser("json", { limit: MAX_SAVE_BYTES + 4096 });
  app.enableCors({ origin: config.webOrigins, credentials: true, allowedHeaders: ["content-type", "x-csrf-token"], methods: ["GET", "POST", "PUT", "PATCH", "DELETE"] });
  app.enableShutdownHooks();
  return app;
}
