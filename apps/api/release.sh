#!/bin/sh
# Runs before each deploy goes live (Fly release_command): migrate, then seed
# the reference data. Both are idempotent.
set -e
./node_modules/.bin/prisma migrate deploy
node --experimental-strip-types --disable-warning=ExperimentalWarning dist/seed.js
