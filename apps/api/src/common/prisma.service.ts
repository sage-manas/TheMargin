import { Inject, Injectable, type OnModuleDestroy } from "@nestjs/common";
import { PrismaClient } from "../generated/prisma/client.js";
import { CONFIG, type Config } from "../config.js";
import { pgAdapter } from "./db.js";

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleDestroy {
  constructor(@Inject(CONFIG) config: Config) {
    super({ adapter: pgAdapter(config.databaseUrl) });
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
