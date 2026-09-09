#!/system/bin/sh
# A dead background process must not permanently block future recovery.
# Only removes a stale operation marker; never touches saved networks or profiles.
thor_worker_alive() {
    for process in /proc/[0-9]*/cmdline; do
        [ -r "$process" ] || continue
        arguments=$(tr '\000' ' ' < "$process" 2>/dev/null) || continue
        case "$arguments" in
            *'/data/local/thor-wifi/bin/workflow.sh worker'*|*'/data/local/thor-wifi/bin/workflow.sh connect'*|*'/data/local/thor-wifi/bin/wifi_reconnect.sh'*) return 0;;
        esac
    done
    return 1
}
thor_clear_stale() {
    [ -f "$P/working" ] || return 0
    changed=$(stat -c %Y "$P/working" 2>/dev/null) || return 0
    case "$changed" in ''|*[!0-9]*) return 0;; esac
    # Protect the short interval between writing the marker and spawning a worker.
    [ $(($(date +%s) - changed)) -ge 15 ] || return 0
    thor_worker_alive && return 0
    [ "$(stat -c %Y "$P/working" 2>/dev/null)" = "$changed" ] || return 0
    rm -f "$P/working" "$P/worker.pid"
    printf '%s\n' WORKER_INTERRUPTED > "$P/status"
    printf '%s\n' WORKER_INTERRUPTED > "$P/connection-reason"
}
