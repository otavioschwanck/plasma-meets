#!/usr/bin/env bash
set -euo pipefail

if command -v qdbus6 &>/dev/null; then
    _qdbus=qdbus6
elif command -v qdbus-qt6 &>/dev/null; then
    _qdbus=qdbus-qt6
else
    echo "qdbus6 or qdbus-qt6 not found" >&2
    exit 1
fi

wallet_service="${PLASMA_MEETS_WALLET_SERVICE:-org.kde.kwalletd6}"
wallet_path="${PLASMA_MEETS_WALLET_PATH:-/modules/kwalletd6}"
wallet_iface="${PLASMA_MEETS_WALLET_IFACE:-org.kde.KWallet}"
wallet_name="${PLASMA_MEETS_WALLET:-kdewallet}"
wallet_folder="${PLASMA_MEETS_FOLDER:-PlasmaMeets}"
wallet_app="${PLASMA_MEETS_APPID:-plasma-meets-helper}"

cmd="${1:-}"

wallet_handle() {
    $_qdbus "$wallet_service" "$wallet_path" "$wallet_iface.open" "$wallet_name" 0 "$wallet_app"
}

wallet_ensure_folder() {
    local handle="$1"
    local has_folder

    has_folder="$($_qdbus "$wallet_service" "$wallet_path" "$wallet_iface.hasFolder" "$handle" "$wallet_folder" "$wallet_app" | tr -d '\r')"
    if [[ "$has_folder" != "true" ]]; then
        $_qdbus "$wallet_service" "$wallet_path" "$wallet_iface.createFolder" "$handle" "$wallet_folder" "$wallet_app" >/dev/null
    fi
}

wallet_read() {
    local entry="$1"
    local handle
    local value

    handle="$(wallet_handle)"
    wallet_ensure_folder "$handle"
    value="$($_qdbus "$wallet_service" "$wallet_path" "$wallet_iface.readPassword" "$handle" "$wallet_folder" "$entry" "$wallet_app" 2>/dev/null || true)"
    printf '%s' "$value"
}

wallet_write() {
    local entry="$1"
    local value="$2"
    local handle

    handle="$(wallet_handle)"
    wallet_ensure_folder "$handle"
    $_qdbus "$wallet_service" "$wallet_path" "$wallet_iface.writePassword" "$handle" "$wallet_folder" "$entry" "$value" "$wallet_app" >/dev/null
}

wallet_clear() {
    local entry="$1"
    local handle

    handle="$(wallet_handle)"
    wallet_ensure_folder "$handle"
    $_qdbus "$wallet_service" "$wallet_path" "$wallet_iface.removeEntry" "$handle" "$wallet_folder" "$entry" "$wallet_app" >/dev/null 2>/dev/null || true
}

case "$cmd" in
    wallet-read)
        entry="${2:-}"
        wallet_read "$entry"
        ;;
    wallet-write)
        entry="${2:-}"
        value="${3:-}"
        wallet_write "$entry" "$value"
        ;;
    wallet-clear)
        entry="${2:-}"
        wallet_clear "$entry"
        ;;
    notify)
        title="${2:-}"
        body="${3:-}"
        $_qdbus org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications.Notify \
            "Plasma Meets" 0 "calendar" "$title" "$body" [] {} 10000 >/dev/null
        ;;
    oauth-revoke)
        token="${2:-}"
        curl -fsS -X POST -d "token=${token}" https://oauth2.googleapis.com/revoke >/dev/null || true
        ;;
    *)
        echo "Unknown command: $cmd" >&2
        exit 1
        ;;
esac
