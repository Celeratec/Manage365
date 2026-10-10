#!/usr/bin/env bash
# macOS/Linux dev-loop launcher.
#
# Proxyman trust is NOT applied by this script anymore — it lives in the compose files
# as optional CA mounts that turn on when build/.env sets them (written by
# build/tools/Export-ProxymanCert.ps1). Docker Compose auto-loads build/.env, so a plain
# `docker compose up` and a `docker restart` both keep Proxyman trust with no -f overlay
# to remember. This launcher just runs compose and reports whether trust is active.
#
# Usage (run from anywhere):
#   build/tools/Start-CippDev.sh                 # up --pull always --watch (default)
#   build/tools/Start-CippDev.sh up -d           # any `docker compose` args pass through
#   BASE_COMPOSE=docker-compose-no-frontend.yml build/tools/Start-CippDev.sh
#
# To turn Proxyman trust on: pwsh build/tools/Export-ProxymanCert.ps1
set -euo pipefail

# build/ dir holds the compose files, build/.env, and the relative ./config paths.
BUILD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BUILD_DIR"

BASE_COMPOSE="${BASE_COMPOSE:-docker-compose-all.yml}"

if [ -s .env ] && grep -q '^CIPP_API_CA_MOUNT=' .env; then
    echo "🔎 Proxyman trust ACTIVE (build/.env) — containers trust Proxyman's CA."
    echo "   (traffic already routes through Proxyman via the system proxy; this adds trust)"
else
    echo "ℹ️  Proxyman trust OFF — plain dev stack. Enable with: pwsh build/tools/Export-ProxymanCert.ps1"
fi

# Default action mirrors the documented header of docker-compose-all.yml; anything
# the caller passes (e.g. `up -d`, `down`, `logs -f`) overrides it verbatim.
if [ "$#" -eq 0 ]; then
    set -- up --pull always --watch
fi

set -x
exec docker compose -p cipp -f "$BASE_COMPOSE" "$@"
