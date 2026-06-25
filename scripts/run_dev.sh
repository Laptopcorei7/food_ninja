#!/usr/bin/env bash
# run_dev.sh — Detects local IP and runs Flutter with it as DEV_HOST.
# Usage:
#   bash scripts/run_dev.sh                     (auto-detect device)
#   bash scripts/run_dev.sh --emulator          (force emulator — uses 10.0.2.2)
#   bash scripts/run_dev.sh -d <device-id>      (target a specific device)

set -euo pipefail

HOST_IP=""
EXTRA_ARGS=()
DEVICE=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --emulator)
      HOST_IP="10.0.2.2"
      shift ;;
    -d)
      DEVICE="$2"
      shift 2 ;;
    *)
      EXTRA_ARGS+=("$1")
      shift ;;
  esac
done

if [[ -z "$HOST_IP" ]]; then
  # macOS
  if command -v ipconfig &>/dev/null && [[ "$(uname)" == "Darwin" ]]; then
    HOST_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)
  fi

  # Linux / WSL — prefer 'ip route' which gives the interface used to reach the internet
  if [[ -z "$HOST_IP" ]] && command -v ip &>/dev/null; then
    HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' || true)
  fi

  # Fallback: ifconfig
  if [[ -z "$HOST_IP" ]] && command -v ifconfig &>/dev/null; then
    HOST_IP=$(ifconfig | awk '/inet /{print $2}' | grep -v '127.0.0.1' | head -1 | sed 's/addr://')
  fi

  if [[ -z "$HOST_IP" ]]; then
    echo "ERROR: Could not detect local IP. Use --emulator flag or set DEV_HOST manually."
    exit 1
  fi

  echo "Detected IP: $HOST_IP"
fi

DEFINE="--dart-define=DEV_HOST=$HOST_IP"
echo "Running: flutter run $DEFINE ${DEVICE:+-d $DEVICE} ${EXTRA_ARGS[*]:-}"
echo ""

if [[ -n "$DEVICE" ]]; then
  flutter run "$DEFINE" -d "$DEVICE" "${EXTRA_ARGS[@]}"
else
  flutter run "$DEFINE" "${EXTRA_ARGS[@]}"
fi
