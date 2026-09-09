#!/system/bin/sh
# Modes: soft (default), recovery (Android-managed subsystem restart, root).
# Run AFTER wifi_diagnostic.sh has captured the failure.
set +x
umask 077
export LC_ALL=C
export PATH=/system/bin:/system/xbin:/vendor/bin:/product/bin:$PATH
MODE=${1:-soft}
case "$MODE" in soft|recovery) ;; *) echo 'Usage: sh wifi_repair.sh [soft|recovery]'; exit 1;; esac

BASE=/sdcard/Download/AYN-Thor-WiFi
mkdir -p "$BASE" || exit 1
OUT=$(mktemp -d "$BASE/repair-$(date +%Y%m%d-%H%M%S)-XXXXXX") || exit 1
LOG="$OUT/repair.txt"
exec 3>&1
exec > "$LOG" 2>&1
echo "Wi-Fi repair log: $LOG" >&3
command -v timeout >/dev/null 2>&1 || { echo 'STOP: timeout unavailable.'; exit 1; }
run() { timeout -k 2 20 "$@"; }
echo "Wi-Fi repair mode=$MODE. No saved network is deleted."
date -u
id
run cmd wifi help > "$OUT/cmd-wifi-help.txt" 2>&1
# AYN help returned 255 in the shell capture despite displaying this command.
grep -q '^  set-wifi-enabled enabled|disabled' "$OUT/cmd-wifi-help.txt" || {
    echo 'STOP: required command grammar not advertised.'; exit 1;
}

status() { run cmd wifi status; }
wait_state() {
    expected=$1
    count=0
    while [ "$count" -lt 15 ]; do
        state=$(status 2>&1)
        printf '%s\n' "$state"
        if printf '%s\n' "$state" | grep -q "^Wifi is $expected"; then return 0; fi
        sleep 2
        count=$((count + 1))
    done
    return 1
}

echo 'BEFORE'
status
run ip link show dev wlan0

# If interrupted after requesting OFF, attempt to restore ON before exiting.
RESTORE=0
cleanup() {
    if [ "$RESTORE" -eq 1 ]; then
        echo 'Final safeguard: requesting Wi-Fi enabled.'
        run cmd wifi set-wifi-enabled enabled
    fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

RESTORE=1
if [ "$MODE" = recovery ]; then
    [ "$(id -u)" = 0 ] || { echo 'STOP: recovery requires root.'; RESTORE=0; exit 1; }
    grep -q '^  trigger-recovery' "$OUT/cmd-wifi-help.txt" || {
        echo 'STOP: firmware does not advertise trigger-recovery.'; RESTORE=0; exit 1;
    }
    echo 'Requesting Android-managed Wi-Fi subsystem recovery.'
    run cmd wifi trigger-recovery || { echo 'Recovery request failed.'; exit 2; }
    sleep 10
else
echo 'Requesting Wi-Fi disabled.'
if ! run cmd wifi set-wifi-enabled disabled; then
    echo 'STOP: disable request failed; restore will be attempted.'
    exit 2
fi
if ! wait_state disabled; then
    echo 'STOP: disabled state not confirmed; restore will be attempted.'
    exit 2
fi
sleep 3
fi
echo 'Requesting Wi-Fi enabled.'
if ! run cmd wifi set-wifi-enabled enabled; then
    echo 'STOP: enable request failed; restore will be attempted.'
    exit 2
fi
if ! wait_state enabled; then
    echo 'STOP: enabled state not confirmed; restore will be attempted.'
    exit 2
fi
RESTORE=0

echo 'Waiting for saved-network autojoin (12 checks, 5-second intervals).'
count=0
CONNECTED=0
while [ "$count" -lt 12 ]; do
    state=$(status 2>&1)
    printf '%s\n' "$state"
    if printf '%s\n' "$state" | grep -q '^Wifi is connected to '; then
        CONNECTED=1
        break
    fi
    sleep 5
    count=$((count + 1))
done
echo 'AFTER'
run ip link show dev wlan0
run ip address show dev wlan0
run ip route show table all
run cmd wifi list-scan-results
if [ "$CONNECTED" -eq 1 ]; then
    echo 'Association reported by Android; inspect IP/routes. Internet not tested.'
    echo "Wi-Fi association reported. Verification log: $LOG" >&3
else
    echo "Repair mode=$MODE finished; no connection confirmed. Do not escalate automatically."
    echo "No Wi-Fi connection confirmed. Log: $LOG" >&3
    exit 3
fi
