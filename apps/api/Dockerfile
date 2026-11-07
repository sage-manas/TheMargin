# The API image. Build from the repository root:
#   docker build -f apps/api/Dockerfile .
# It keeps the workspace layout because the API loads packages/contracts as
# TypeScript source at runtime (ADR-0011).
FROM node:22-slim

# OpenSSL for Prisma's schema engine (migrations run in this image).
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates && rm -rf /var/lib/apt/lists/*
ENV PNPM_HOME=/pnpm COREPACK_HOME=/corepack PATH=/pnpm:$PATH CI=true
RUN corepack enable && mkdir -p /corepack && chmod 777 /corepack

WORKDIR /repo
# Manifests first, so dependency installs are cached across source changes.
# Every workspace manifest is copied because the lockfile names them all.
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/api/package.json apps/api/
COPY apps/web/package.json apps/web/
COPY packages/contracts/package.json packages/contracts/
COPY tests/e2e/package.json tests/e2e/
RUN corepack install && pnpm install --frozen-lockfile --filter "@the-margin/api..."

COPY packages/contracts packages/contracts
COPY apps/api apps/api
RUN pnpm --filter @the-margin/api build && chown -R node:node /repo/apps/api

WORKDIR /repo/apps/api
USER node
ENV NODE_ENV=production PORT=4000
EXPOSE 4000
CMD ["node", "--experimental-strip-types", "--disable-warning=ExperimentalWarning", "dist/main.js"]
