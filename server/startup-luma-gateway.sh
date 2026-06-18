#!/usr/bin/env sh
set -eu

HOST="${LUMA_GATEWAY_HOST:-0.0.0.0}"
PORT="${LUMA_GATEWAY_PORT:-9000}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
GATEWAY_SCRIPT="${LUMA_GATEWAY_SCRIPT:-$SCRIPT_DIR/luma-gateway.py}"

detect_lan_ip() {
  if command -v ipconfig >/dev/null 2>&1; then
    ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true
  elif command -v hostname >/dev/null 2>&1; then
    hostname -I 2>/dev/null | awk '{print $1}' || true
  fi
}

LAN_IP="$(detect_lan_ip)"
if [ -z "$LAN_IP" ]; then
  LAN_IP="127.0.0.1"
fi

print_urls() {
  echo "Local: http://127.0.0.1:$PORT"
  echo "LAN:   http://$LAN_IP:$PORT"
}

if [ ! -f "$GATEWAY_SCRIPT" ]; then
  echo "Missing $GATEWAY_SCRIPT" >&2
  exit 1
fi

if curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
  echo "Luma Gateway already running."
  print_urls
  exit 0
fi

echo "Starting Luma Gateway..."
print_urls
exec python3 "$GATEWAY_SCRIPT" --host "$HOST" --port "$PORT"
