import { PrismaPg } from "@prisma/adapter-pg";

/**
 * The Postgres adapter for every Prisma client. Connections are pinned to UTC:
 * with a non-UTC server timezone the adapter read timestamptz values shifted
 * by the offset (an expired session looked valid for 5.5 hours in IST).
 */
export const pgAdapter = (connectionString: string) => new PrismaPg({ connectionString, options: "-c TimeZone=UTC" });
