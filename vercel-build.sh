#!/bin/bash

# Strict mode: exit on error, fail on unset variables, and print commands
set -euo pipefail
IFS=$'\n\t'

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "[${TIMESTAMP}] Starting Vercel build process..."

# ---- Step 1: Ensure required env variables ----
for var in DATABASE_URL NEXTAUTH_SECRET NEXTAUTH_URL; do
  if [ -z "${!var:-}" ]; then
    echo "❌ Error: $var is not set"
    exit 1
  fi
done

# ---- Step 2: Install dependencies ----
echo "🔧 Installing dependencies..."
pnpm install --frozen-lockfile --prefer-offline

# ---- Step 3: Generate Prisma client ----
echo "⚙️ Generating Prisma client..."
npx prisma generate

# ---- Step 4: Run database migrations (production-safe) ----
echo "🚀 Running production migrations..."
NODE_ENV=production npx prisma migrate deploy

# ---- Step 5: Verify database connection ----
echo "🔌 Verifying database connection..."
npx prisma db execute --stdin --url="$DATABASE_URL" <<< "SELECT 1 AS connection_test;"

# ---- Step 6: Build Next.js 15 app ----
echo "🏗️ Building Next.js app..."
pnpm run build

# ---- Step 7: Optional post-build (sitemap, etc.) ----
if grep -q "\"postbuild\"" package.json; then
  echo "🗺️ Running postbuild script..."
  pnpm run postbuild
fi

# ---- Step 8: Verify build output ----
if [ ! -d ".next" ]; then
  echo "❌ Error: Build failed - .next directory not found"
  exit 1
fi

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "✅ [${TIMESTAMP}] Vercel build completed successfully!"
