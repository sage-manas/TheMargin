# API Contract (v1, proposal)

Base path `/v1`. JSON only. Authentication uses the session cookie `tm_session` (HttpOnly) plus a CSRF header `x-csrf-token` that must match the `tm_csrf` cookie on non-GET requests. Request/response schemas live in `packages/contracts` (Zod) and are published as OpenAPI from NestJS at `/v1/docs` (non-production only).

## Error envelope

```json
{ "error": { "code": "SAVE_CONFLICT", "message": "Human readable", "details": {} } }
```

Codes: `VALIDATION_FAILED` (400), `UNAUTHENTICATED` (401), `FORBIDDEN` (403), `NOT_FOUND` (404), `SAVE_CONFLICT` (409), `UNSUPPORTED_SAVE_VERSION` (422), `RATE_LIMITED` (429), `INTERNAL` (500). Internal details are never leaked.

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
| PUT | `/saves/main` | session | `{baseRevision, save}` → 200 `{revision}` or 409 `{server: {revision, save}}` |
| PUT | `/saves/backup-:ts` | session | Stores a conflict loser; the last 5 are kept |
| GET | `/progression` | session | `[{chapterId, title, status, completedAt}]` |
| POST | `/progression/:chapterId/complete` | session | Validated: the chapter must be released and its predecessor completed |
| GET | `/achievements` | optional | Definitions (+ `unlockedAt` when authenticated) |
| POST | `/achievements/:code/unlock` | session | Idempotent |
| GET | `/settings` | session | Settings payload |
| PUT | `/settings` | session | Full replace, validated against the settings schema |

## Versioning

The URL prefix carries the major version. Additive changes don't bump it. Removing or renaming fields requires `/v2` with a deprecation window of at least one release.
