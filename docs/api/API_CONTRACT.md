# API Contract (v1)

Base path `/v1`. JSON only. Implemented in `apps/api` (Phase 6); request and response schemas live in `packages/contracts/src/api.ts` (Zod) and are what the API validates against. (OpenAPI at `/v1/docs` is deferred.)

**Sessions and CSRF.** The session is an opaque token in the `tm_session` cookie (HttpOnly, SameSite=Lax, Secure outside local development, 30-day sliding expiry). Every `POST`/`PUT`/`PATCH`/`DELETE`, including register and login, needs an `x-csrf-token` header equal to the `tm_csrf` cookie. Both cookies are HttpOnly, so a client gets the token from `GET /auth/session` and keeps it in memory. A browser `Origin` outside `WEB_ORIGINS` is refused (403) even with a valid token. CORS allows only `WEB_ORIGINS`, with credentials.

## Error envelope

```json
{ "error": { "code": "SAVE_CONFLICT", "message": "Human readable", "details": {} } }
```

Codes: `VALIDATION_FAILED` (400, or 413 for a body over the limit; `details.issues` lists `{path, message}`), `UNAUTHENTICATED` (401), `FORBIDDEN` (403), `NOT_FOUND` (404), `EMAIL_TAKEN` (409), `SAVE_CONFLICT` (409), `UNSUPPORTED_SAVE_VERSION` (422), `RATE_LIMITED` (429), `INTERNAL` (500). Internal details are never leaked.

## Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/health` | none | Liveness + DB ping |
| POST | `/auth/register` | none | `{email, password, displayName}` → 201, sets session. Rate limited 5/min/IP. |
| POST | `/auth/login` | none | `{email, password}` → 200, sets session. Rate limited 10/min/IP; constant-time failures. |
| POST | `/auth/logout` | session | Revokes the session, clears cookies |
| GET | `/auth/session` | optional | `{user | null, csrfToken}` |
| GET | `/me` | session | Account + profile |
| PATCH | `/me/profile` | session | `{displayName?, avatar?}` |
| GET | `/saves/main` | session | `{revision, save, updatedAt}`, or 404 if none |
| PUT | `/saves/main` | session | `{baseRevision, save}` → 200 `{revision}`, or 409 `SAVE_CONFLICT` with `details: {server: {revision, save, updatedAt}}`. 422 for a save with `version` above 1; 400 for an invalid one or over 64 KB |
| PUT | `/saves/backup-:ts` | session | `{save}` → 200 `{slot}`. Stores a conflict loser (`ts` = unix ms); the newest 5 are kept |
| GET | `/progression` | session | `[{chapterId, title, status, completedAt}]`. `status` is `locked` (unreleased, or the previous chapter isn't done), `available`, `in_progress` (the cloud save is in it) or `completed` |
| POST | `/progression/:chapterId/complete` | session | Validated: the chapter must be released (403) and its predecessor completed (403). Idempotent, keeps the first `completedAt`, and awards the chapter's achievement |
| GET | `/achievements` | optional | Definitions (+ `unlockedAt` when authenticated) |
| POST | `/achievements/:code/unlock` | session | Idempotent. 403 for chapter achievements, which only the server awards |
| GET | `/settings` | session | Settings payload (the defaults until first set) |
| PUT | `/settings` | session | Full replace, validated against the settings schema |

## Versioning

The URL prefix carries the major version. Additive changes don't bump it. Removing or renaming fields requires `/v2` with a deprecation window of at least one release.

## Saves: revisions and conflicts

The server's `revision` counts accepted cloud writes to a slot; it is not the save's own `revision` (which counts local writes). A `PUT` lands only if `baseRevision` equals the current cloud revision (`null` when there is no cloud save yet), as an atomic compare-and-swap, so of two devices writing from the same base exactly one wins. The other gets the server's copy in the 409 and resolves the conflict on the client (SAVE_SCHEMA §5); the server never merges.

