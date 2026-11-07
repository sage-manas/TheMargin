# Database Design (PostgreSQL + Prisma)

## Normalisation decisions

| Data | Storage | Why |
|---|---|---|
| Users, profiles, sessions | Normalised tables | Relational, queried by key, security-sensitive |
| Chapter progress | Normalised `chapter_progress` | Queried for the chapters page and progression validation; small and fixed |
| Achievements | Definitions + join table | Classic many-to-many with unlock timestamps |
| Save snapshot | `game_saves.payload JSONB` | Opaque, versioned game document. The server validates the envelope but never queries inside it |
| Settings | `player_settings.payload JSONB` | Small, versioned, schemaless by design |

The brief's `chapters` entity is a **seeded table**, so chapter progress can use a real foreign key and unreleased chapters can be locked server-side.

## ER diagram

```mermaid
erDiagram
  users ||--|| player_profiles : has
  users ||--o{ sessions : has
  users ||--o{ game_saves : has
  users ||--o{ chapter_progress : has
  chapters ||--o{ chapter_progress : tracks
  users ||--o{ player_achievements : unlocks
  achievements ||--o{ player_achievements : "unlocked as"
  users ||--o| player_settings : has

  users { uuid id PK
          citext email UK
          text password_hash
          timestamptz created_at
          timestamptz updated_at }
  sessions { uuid id PK
             uuid user_id FK
             bytea token_hash UK
             timestamptz expires_at
             timestamptz created_at
             text user_agent }
  player_profiles { uuid id PK
                    uuid user_id FK,UK
                    text display_name
                    text avatar
                    timestamptz created_at
                    timestamptz updated_at }
  game_saves { uuid id PK
               uuid user_id FK
               text slot "main | backup-*"
               int save_version
               int revision
               jsonb payload
               timestamptz client_updated_at
               timestamptz updated_at }
  chapters { text id PK "ch01"
             int ordinal UK
             text title
             bool released }
  chapter_progress { uuid id PK
                     uuid user_id FK
                     text chapter_id FK
                     text status "locked|available|in_progress|completed"
                     timestamptz completed_at
                     timestamptz updated_at }
  achievements { uuid id PK
                 text code UK
                 text title
                 text description
                 jsonb metadata }
  player_achievements { uuid id PK
                        uuid user_id FK
                        uuid achievement_id FK
                        timestamptz unlocked_at }
  player_settings { uuid id PK
                    uuid user_id FK,UK
                    int settings_version
                    jsonb payload
                    timestamptz updated_at }
```

## Constraints and indexes

- `users.email` is `citext UNIQUE`.
- `sessions.token_hash UNIQUE`; index `(user_id)`; expired sessions are swept daily.
- `game_saves UNIQUE (user_id, slot)`; `CHECK (octet_length(payload::text) <= 65536)`.
- `chapter_progress UNIQUE (user_id, chapter_id)`.
- `player_achievements UNIQUE (user_id, achievement_id)`.
- All FKs to `users` use `ON DELETE CASCADE` (account deletion = full erasure, which supports GDPR requests).
- Seeds: chapters `ch01`–`ch07` (only `ch01` released) and the initial achievement set (`FIRST_SLIDE`, `FIRST_WORD`, `WONT_SHUT`, `CH01_COMPLETE`).

- `chapter_progress.status` is a Postgres enum, `chapter_status`.
- Connections are pinned to `TimeZone=UTC` (`apps/api/src/common/db.ts`): with a non-UTC server timezone, Prisma 7's `pg` adapter read `timestamptz` values shifted by the offset. The test database is set to `Asia/Kolkata` so this stays caught on UTC machines.

Migrations are Prisma Migrate SQL files committed under `apps/api/prisma/migrations` (Prisma 7, `prisma.config.ts`). The citext extension and the payload size CHECK are hand-written into the SQL because Prisma doesn't model them. CI validates them against a disposable Postgres 17: drop the schema, `prisma migrate deploy`, then `prisma migrate diff --from-config-datasource --to-schema prisma/schema.prisma --exit-code`. Seeds (`pnpm --filter @the-margin/api seed`) come from `CHAPTERS` and `ACHIEVEMENTS` in `packages/contracts` and are idempotent.
