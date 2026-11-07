-- Case-insensitive emails (users.email). Not modelled by Prisma.
CREATE EXTENSION IF NOT EXISTS citext;

-- CreateEnum
CREATE TYPE "chapter_status" AS ENUM ('locked', 'available', 'in_progress', 'completed');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "email" CITEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sessions" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "token_hash" BYTEA NOT NULL,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "user_agent" TEXT,

    CONSTRAINT "sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "player_profiles" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "display_name" TEXT NOT NULL,
    "avatar" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "player_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "game_saves" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "slot" TEXT NOT NULL,
    "save_version" INTEGER NOT NULL,
    "revision" INTEGER NOT NULL,
    "payload" JSONB NOT NULL,
    "client_updated_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "game_saves_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "chapters" (
    "id" TEXT NOT NULL,
    "ordinal" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "released" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "chapters_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "chapter_progress" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "chapter_id" TEXT NOT NULL,
    "status" "chapter_status" NOT NULL,
    "completed_at" TIMESTAMPTZ(3),
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "chapter_progress_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "achievements" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "metadata" JSONB NOT NULL DEFAULT '{}',

    CONSTRAINT "achievements_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "player_achievements" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "achievement_id" UUID NOT NULL,
    "unlocked_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "player_achievements_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "player_settings" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "settings_version" INTEGER NOT NULL,
    "payload" JSONB NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "player_settings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "sessions_token_hash_key" ON "sessions"("token_hash");

-- CreateIndex
CREATE INDEX "sessions_user_id_idx" ON "sessions"("user_id");

-- CreateIndex
CREATE INDEX "sessions_expires_at_idx" ON "sessions"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "player_profiles_user_id_key" ON "player_profiles"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "game_saves_user_id_slot_key" ON "game_saves"("user_id", "slot");

-- CreateIndex
CREATE UNIQUE INDEX "chapters_ordinal_key" ON "chapters"("ordinal");

-- CreateIndex
CREATE UNIQUE INDEX "chapter_progress_user_id_chapter_id_key" ON "chapter_progress"("user_id", "chapter_id");

-- CreateIndex
CREATE UNIQUE INDEX "achievements_code_key" ON "achievements"("code");

-- CreateIndex
CREATE UNIQUE INDEX "player_achievements_user_id_achievement_id_key" ON "player_achievements"("user_id", "achievement_id");

-- CreateIndex
CREATE UNIQUE INDEX "player_settings_user_id_key" ON "player_settings"("user_id");

-- AddForeignKey
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "player_profiles" ADD CONSTRAINT "player_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "game_saves" ADD CONSTRAINT "game_saves_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "chapter_progress" ADD CONSTRAINT "chapter_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "chapter_progress" ADD CONSTRAINT "chapter_progress_chapter_id_fkey" FOREIGN KEY ("chapter_id") REFERENCES "chapters"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "player_achievements" ADD CONSTRAINT "player_achievements_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "player_achievements" ADD CONSTRAINT "player_achievements_achievement_id_fkey" FOREIGN KEY ("achievement_id") REFERENCES "achievements"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "player_settings" ADD CONSTRAINT "player_settings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Saves are at most 64 KB (SAVE_SCHEMA §2). Not modelled by Prisma.
ALTER TABLE "game_saves" ADD CONSTRAINT "game_saves_payload_size" CHECK (octet_length("payload"::text) <= 65536);
