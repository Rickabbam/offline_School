#!/usr/bin/env bash
# scripts/dev-setup.sh
# Run once after cloning: bash scripts/dev-setup.sh
# Sets up all workspaces for local development on macOS and Linux.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC}  $*"; }
fail() { echo -e "${RED}✗${NC} $*"; exit 1; }
step() { echo -e "\n${CYAN}──${NC} $*"; }

echo -e "\n${CYAN}offline_School dev setup${NC}"
echo "Root: $ROOT"

# ─── Check prerequisites ─────────────────────────────────────────────────────
step "Checking prerequisites"

check_cmd() {
  if command -v "$1" &>/dev/null; then
    ok "$1 found: $(command -v "$1")"
  else
    warn "$1 not found. Install it and re-run this script."
    warn "  See README.md for install links."
  fi
}

check_node() {
  if command -v node &>/dev/null; then
    local ver
    ver=$(node --version)
    ok "Node.js $ver"
  else
    fail "Node.js is required. Install from https://nodejs.org"
  fi
}

check_node
check_cmd npm
check_cmd flutter
check_cmd docker
check_cmd git

# ─── Backend ─────────────────────────────────────────────────────────────────
step "Installing backend dependencies"
cd "$ROOT/backend"
npm install
ok "Backend npm install complete"

if [ ! -f "$ROOT/backend/.env" ]; then
  cp "$ROOT/backend/.env.example" "$ROOT/backend/.env"
  ok "Created backend/.env from .env.example — edit it with your local values"
else
  ok "backend/.env already exists"
fi

# ─── Flutter apps ────────────────────────────────────────────────────────────
if command -v flutter &>/dev/null; then
  step "Installing Flutter desktop app dependencies"
  cd "$ROOT/apps/desktop_app"
  flutter pub get
  ok "desktop_app pub get complete"

  step "Generating Drift database code"
  flutter pub run build_runner build --delete-conflicting-outputs 2>/dev/null \
    && ok "Drift code generation complete" \
    || warn "Drift code generation failed — run manually: flutter pub run build_runner build"
else
  warn "Flutter not found — skipping desktop_app and mobile_app setup."
  warn "Install Flutter from https://flutter.dev and re-run this script."
fi

# ─── Local services (Docker) ─────────────────────────────────────────────────
step "Starting local services (PostgreSQL + Redis)"
if command -v docker &>/dev/null; then
  cd "$ROOT/infra"
  docker compose up -d
  ok "PostgreSQL and Redis started (check 'docker compose ps' to confirm)"
else
  warn "Docker not found — start PostgreSQL and Redis manually."
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo "  Backend:  cd backend && npm run start:dev"
echo "  Desktop:  cd apps/desktop_app && flutter run -d windows"
echo "  Health:   curl http://localhost:3000/health"
echo ""
echo "  See README.md and docs/05-roadmap.md for next steps."
