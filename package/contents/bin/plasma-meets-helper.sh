#!/usr/bin/env bash
set -uo pipefail

# Exit codes:
#   0 — success (stdout is the value; may be empty for missing entries)
#   1 — usage / generic failure
#   2 — wallet backend not ready (kwalletd unreachable, disabled, or wallet closed)

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

qdbus_call() {
    # Usage: qdbus_call METHOD [ARGS...]
    # Returns trimmed stdout on success, empty on failure. Always returns 0.
    local method="$1"; shift
    local out
    out="$($_qdbus "$wallet_service" "$wallet_path" "$wallet_iface.$method" "$@" 2>/dev/null || true)"
    printf '%s' "$out" | tr -d '\r'
}

wallet_is_ready() {
    # Returns 0 if kwalletd reachable, wallet enabled, and target wallet open.
    # Returns 2 otherwise (distinct from "entry missing").
    local enabled is_open
    enabled="$(qdbus_call isEnabled)"
    [[ "$enabled" != "true" ]] && return 2
    is_open="$(qdbus_call isOpen "$wallet_name")"
    [[ "$is_open" != "true" ]] && return 2
    return 0
}

wallet_handle() {
    qdbus_call open "$wallet_name" 0 "$wallet_app"
}

wallet_ensure_folder() {
    local handle="$1"
    local has_folder
    has_folder="$(qdbus_call hasFolder "$handle" "$wallet_folder" "$wallet_app")"
    if [[ "$has_folder" != "true" ]]; then
        qdbus_call createFolder "$handle" "$wallet_folder" "$wallet_app" >/dev/null
    fi
}

wallet_read() {
    local entry="$1"
    local handle value

    if ! wallet_is_ready; then
        echo "wallet not ready" >&2
        exit 2
    fi

    handle="$(wallet_handle)"
    if [[ -z "$handle" || "$handle" == "-1" ]]; then
        echo "wallet open failed" >&2
        exit 2
    fi

    wallet_ensure_folder "$handle"
    value="$(qdbus_call readPassword "$handle" "$wallet_folder" "$entry" "$wallet_app")"
    printf '%s' "$value"
}

wallet_write() {
    local entry="$1"
    local value="$2"
    local handle

    if ! wallet_is_ready; then
        # Attempt to open (may prompt user); only fail hard if that fails too.
        handle="$(wallet_handle)"
        if [[ -z "$handle" || "$handle" == "-1" ]]; then
            echo "wallet open failed" >&2
            exit 2
        fi
    else
        handle="$(wallet_handle)"
    fi

    wallet_ensure_folder "$handle"
    qdbus_call writePassword "$handle" "$wallet_folder" "$entry" "$value" "$wallet_app" >/dev/null
}

wallet_clear() {
    local entry="$1"
    local handle

    if ! wallet_is_ready; then
        # Silent no-op: if the wallet isn't reachable there's nothing to clear.
        return 0
    fi

    handle="$(wallet_handle)"
    [[ -z "$handle" || "$handle" == "-1" ]] && return 0
    wallet_ensure_folder "$handle"
    qdbus_call removeEntry "$handle" "$wallet_folder" "$entry" "$wallet_app" >/dev/null
}

case "$cmd" in
    wallet-ready)
        if wallet_is_ready; then
            printf 'ready'
        else
            printf 'unavailable'
            exit 2
        fi
        ;;
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
