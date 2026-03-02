#!/usr/bin/env bash
# -------------------------------------------------------
# deploy_pi.sh — Build & deploy TapLift backend to a
#                Raspberry Pi via SSH + Docker Compose.
#
# Usage:
#   ./scripts/deploy_pi.sh [pi-host] [pi-user]
#
# Defaults:
#   PI_HOST = raspberrypi.local
#   PI_USER = pi
#   REMOTE_DIR = ~/taplift-server
# -------------------------------------------------------
set -euo pipefail

PI_HOST="${1:-raspberrypi.local}"
PI_USER="${2:-pi}"
REMOTE_DIR="~/taplift-server"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVER_DIR="$PROJECT_DIR/server"

echo "==> Deploying TapLift backend to ${PI_USER}@${PI_HOST}"

# 1. Ensure the remote directory exists
echo "--- Creating remote directory"
ssh "${PI_USER}@${PI_HOST}" "mkdir -p ${REMOTE_DIR}"

# 2. Sync server files to Pi (exclude node_modules, dist, .env)
echo "--- Syncing server files"
rsync -avz --delete \
  --exclude 'node_modules' \
  --exclude 'dist' \
  --exclude '.env' \
  --exclude 'firebase-service-account.json' \
  "${SERVER_DIR}/" "${PI_USER}@${PI_HOST}:${REMOTE_DIR}/"

# 3. Copy the .env file if it exists locally
if [ -f "${SERVER_DIR}/.env" ]; then
  echo "--- Copying .env"
  scp "${SERVER_DIR}/.env" "${PI_USER}@${PI_HOST}:${REMOTE_DIR}/.env"
fi

# 4. Copy Firebase service account if it exists
if [ -f "${SERVER_DIR}/firebase-service-account.json" ]; then
  echo "--- Copying Firebase service account"
  scp "${SERVER_DIR}/firebase-service-account.json" \
    "${PI_USER}@${PI_HOST}:${REMOTE_DIR}/firebase-service-account.json"
fi

# 5. Build & start on Pi
echo "--- Building & starting Docker containers on Pi"
ssh "${PI_USER}@${PI_HOST}" "cd ${REMOTE_DIR} && docker compose pull && docker compose up -d --build"

# 6. Run Prisma migrations
echo "--- Running database migrations"
ssh "${PI_USER}@${PI_HOST}" "cd ${REMOTE_DIR} && docker compose exec api npx prisma migrate deploy"

# 7. Health check
echo "--- Checking health endpoint"
sleep 3
ssh "${PI_USER}@${PI_HOST}" "curl -sf http://localhost:3000/health" && echo " ✅ Server healthy" || echo " ❌ Health check failed"

echo "==> Deployment complete!"
