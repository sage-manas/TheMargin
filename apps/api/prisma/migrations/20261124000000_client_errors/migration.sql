-- CreateTable
CREATE TABLE "client_errors" (
    "id" UUID NOT NULL,
    "fingerprint" CHAR(64) NOT NULL,
    "source" VARCHAR(16) NOT NULL,
    "release" VARCHAR(40) NOT NULL,
    "message" VARCHAR(500) NOT NULL,
    "stack" VARCHAR(4000),
    "path" VARCHAR(200) NOT NULL,
    "user_agent" VARCHAR(256),
    "count" INTEGER NOT NULL DEFAULT 1,
    "first_seen" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_seen" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "client_errors_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "client_errors_fingerprint_key" ON "client_errors"("fingerprint");

-- CreateIndex
CREATE INDEX "client_errors_last_seen_idx" ON "client_errors"("last_seen");

