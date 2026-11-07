# Deploying staging

Staging is one public URL with accounts on, for playtests and for checking releases before production (Phase 8). See ADR-0012 for why it is shaped this way.

```text
browser ──► Vercel: the-margin-staging.vercel.app
              ├─ the site (apps/web)
              ├─ /game/*  the Godot export, bundled into the deployment (same origin)
              └─ /v1/*    proxied ──► Fly.io: the-margin-api-staging.fly.dev (apps/api, Singapore)
                                         └─ Neon Postgres (Singapore), direct connection
```

The browser only ever talks to the site's origin. Cookies are first-party, so neither CORS nor cross-site cookies are involved, and the game's save lives on the site's origin like it does locally.

## Deploys

`.github/workflows/deploy-staging.yml` runs after CI passes on `main`, and can be run by hand (`gh workflow run "Deploy staging"`):

1. **api**: `flyctl deploy` builds `apps/api/Dockerfile` on Fly's builders. Before the new machines take traffic, the release command (`apps/api/release.sh`) runs `prisma migrate deploy` and the idempotent seed.
2. **web**: exports the game with the pinned Godot, copies it into `apps/web/public/game`, then `vercel build` and `vercel deploy --prebuilt --prod`.
3. **smoke**: `infrastructure/scripts/smoke.mjs` checks the landing and play pages, `/game/build.json`, that `/game/index.wasm` is served as `application/wasm`, and the API's health and session through the proxy.

The API image is also built and booted against Postgres on every PR (CI job `api-image`), so a broken Dockerfile shows up before it reaches a deploy.

## One-time setup

These need your accounts. Type secrets into the commands yourself; don't paste them into chats or commits.

1. **Neon.** Create a project (`the-margin-staging`, region AWS Asia Pacific, Singapore). Copy the **direct** connection string, not the pooled one: the pooler rejects the `options` startup parameter the API uses to pin connections to UTC (DATABASE.md).
2. **Fly.io.**
   ```sh
   brew install flyctl
   fly auth login
   fly apps create the-margin-api-staging
   fly secrets set -a the-margin-api-staging DATABASE_URL='postgresql://…?sslmode=require'
   fly deploy . --config apps/api/fly.toml --dockerfile apps/api/Dockerfile   # the first deploy, by hand
   fly tokens create deploy -a the-margin-api-staging                         # for CI: FLY_API_TOKEN
   ```
3. **Vercel.**
   ```sh
   vercel login
   vercel link                      # at the repo root: new project "the-margin-staging"
   ```
   In the project settings set **Root Directory** to `apps/web` (framework: Next.js). Then point the proxy at the API:
   ```sh
   vercel env add API_ORIGIN production     # https://the-margin-api-staging.fly.dev
   ```
   Create a token at vercel.com/account/tokens. The org and project ids are in `.vercel/project.json` (gitignored).
4. **GitHub.** Create an environment named `staging` with secrets `FLY_API_TOKEN`, `VERCEL_TOKEN`, `VERCEL_ORG_ID` and `VERCEL_PROJECT_ID`. Then set the repository variable `STAGING_URL` (`https://the-margin-staging.vercel.app`). It switches the workflow on: until it exists, deploys are skipped.
5. If Vercel gives the site a different URL, change `WEB_ORIGINS` in `apps/api/fly.toml` to match. The API refuses writes from any other origin.

## Rollback

- **Site and game:** `vercel rollback` (or promote an earlier deployment in the dashboard). The game build is part of the deployment, so they roll back together.
- **API:** `fly releases -a the-margin-api-staging`, then `fly deploy --image <earlier image>`. Migrations are forward-only: a rollback across a migration needs a new migration, not a revert.

## Costs and limits (staging)

- **Neon:** the free plan is enough.
- **Fly.io:** one shared-CPU 512 MB machine that stops when idle (`auto_stop_machines`), so the first request after a quiet spell takes a second or two longer.
- **Vercel:** Hobby allows static files up to 100 MB (the engine is 38 MB). Hobby is for non-commercial use, so production needs Pro.

## Known gaps

- `TRUST_PROXY=2` takes the client IP from `X-Forwarded-For`. Someone calling `the-margin-api-staging.fly.dev` directly, bypassing the site, can forge it and dodge the rate limits. The Phase 8 security review should restrict the API to the site's proxy (a shared secret header added by a route handler, or Fly private networking).
- Game files have no content hashes, so they are served with revalidation (`max-age=0`) rather than immutable caching. Repeat visits cost a 304 per file, not a re-download.
- There is no production environment yet. It will be the same shape with its own Fly app, Neon project and Vercel project.
