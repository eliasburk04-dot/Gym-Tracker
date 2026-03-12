#!/usr/bin/env bash
# -------------------------------------------------------
# deploy_pi.sh — Build & deploy TapLift backend to a
#                Raspberry Pi via SSH + Docker Compose.
#
# Usage:
#   ./scripts/deploy_pi.sh [pi-host] [pi-user] [remote-dir] [project-name] [api-port]
#
# Defaults:
#   PI_HOST = raspberrypi.local
#   PI_USER = pi
#   REMOTE_DIR = /opt/taplift-auth
#   PROJECT_NAME = taplift-auth
#   API_PORT = 3001
# -------------------------------------------------------
set -euo pipefail

PI_HOST="${1:-raspberrypi.local}"
PI_USER="${2:-pi}"
REMOTE_DIR="${3:-/opt/taplift-auth}"
PROJECT_NAME="${4:-taplift-auth}"
API_PORT="${5:-3001}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVER_DIR="$PROJECT_DIR/server"

echo "==> Deploying TapLift backend to ${PI_USER}@${PI_HOST}"
echo "    remote_dir=${REMOTE_DIR}"
echo "    project_name=${PROJECT_NAME}"
echo "    api_port=${API_PORT}"

# 1. Ensure the remote directory exists
echo "--- Creating remote directory"
ssh "${PI_USER}@${PI_HOST}" "sudo -n mkdir -p ${REMOTE_DIR} && sudo -n chown -R ${PI_USER}:${PI_USER} ${REMOTE_DIR}"

# 2. Sync server files to Pi (exclude node_modules, dist, .env)
echo "--- Syncing server files"
rsync -avz --delete \
  --exclude 'node_modules' \
  --exclude 'dist' \
  --exclude '.env' \
  --exclude 'data' \
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

# 4b. Ensure API_PORT in remote .env matches requested port
echo "--- Ensuring API_PORT=${API_PORT} in remote .env"
ssh "${PI_USER}@${PI_HOST}" "if [ -f ${REMOTE_DIR}/.env ]; then grep -q '^API_PORT=' ${REMOTE_DIR}/.env && sed -i 's/^API_PORT=.*/API_PORT=${API_PORT}/' ${REMOTE_DIR}/.env || echo 'API_PORT=${API_PORT}' >> ${REMOTE_DIR}/.env; else echo 'API_PORT=${API_PORT}' > ${REMOTE_DIR}/.env; fi"

# 4c. Ensure Firebase auth fail-fast is enabled for production deploys
echo "--- Ensuring REQUIRE_FIREBASE_AUTH=true in remote .env"
ssh "${PI_USER}@${PI_HOST}" "grep -q '^REQUIRE_FIREBASE_AUTH=' ${REMOTE_DIR}/.env && sed -i 's/^REQUIRE_FIREBASE_AUTH=.*/REQUIRE_FIREBASE_AUTH=true/' ${REMOTE_DIR}/.env || echo 'REQUIRE_FIREBASE_AUTH=true' >> ${REMOTE_DIR}/.env"

# 5. Build & start on Pi
echo "--- Building & starting Docker containers on Pi"
ssh "${PI_USER}@${PI_HOST}" "cd ${REMOTE_DIR} && sudo -n docker compose -p ${PROJECT_NAME} pull && sudo -n docker compose -p ${PROJECT_NAME} up -d --build"

# 6. Run Prisma migrations
echo "--- Running database migrations"
ssh "${PI_USER}@${PI_HOST}" "cd ${REMOTE_DIR} && sudo -n docker compose -p ${PROJECT_NAME} exec -T api npx prisma migrate deploy"

# 7. Health check
echo "--- Checking health endpoint"
sleep 3
ssh "${PI_USER}@${PI_HOST}" "curl -sf http://localhost:${API_PORT}/health" && echo " ✅ Server healthy" || echo " ❌ Health check failed"

echo "==> Deployment complete!"
