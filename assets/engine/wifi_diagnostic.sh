#!/system/bin/sh
# Passive diagnostic: only report files are written. No Wi-Fi state changes.
set +x
umask 077
export LC_ALL=C
export PATH=/system/bin:/system/xbin:/vendor/bin:/product/bin:$PATH

BASE=/sdcard/Download/AYN-Thor-WiFi
mkdir -p "$BASE" || { echo "Cannot create $BASE"; exit 1; }
OUT=$(mktemp -d "$BASE/diag-$(date +%Y%m%d-%H%M%S)-XXXXXX") || exit 1
REPORT="$OUT/diagnostic.txt"
HELP="$OUT/cmd-wifi-help.txt"
TIMEOUT=
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT=timeout
elif toybox timeout 2 /system/bin/sh -c ':' >/dev/null 2>&1; then
    TIMEOUT=toybox
fi

bounded() {
    if [ "$TIMEOUT" = timeout ]; then
        timeout -k 2 20 "$@"
    elif [ "$TIMEOUT" = toybox ]; then
        toybox timeout -k 2 20 "$@"
    else
        echo "SKIPPED: no timeout utility; refusing an unbounded system query."
        return 125
    fi
}

# Best-effort filtering, not a guarantee of anonymity. No raw intermediate logs.
filter() {
    awk -v mode="$1" '
    {
        line=tolower($0)
        if (mode == "wifi" && line !~ /wifi|wi-fi|wlan|supplicant|hostapd|wificond|cnss|qcacld|qca_cld|kiwi|wiphy|scan|qcom|qualcomm|firmware|dhcp|ipclient|networkmonitor|netd|cfg80211|mac80211|subsys|ssr|avc:|denied|error|failed|not found|not permitted|timed out|exit_code/) next
        if (line ~ /password|passphrase|presharedkey|connect-network|(^|[^a-z])(psk|pmk|ptk|gtk)[[:space:]]*[:=]/) {
            print "[line omitted: may contain credentials]"
            next
        }
        print
    }'
}

collect() {
    title=$1
    mode=$2
    shift 2
    printf '\n===== %s | %s =====\n' "$title" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$REPORT"
    # Each exit code is recorded before the filter so errors remain visible.
    { bounded "$@" 2>&1; printf '\n[exit_code=%s]\n' "$?"; } | filter "$mode" >> "$REPORT"
}

{
    echo 'AYN Thor - passive Wi-Fi snapshot'
    echo 'Only these report files are written; no scan, toggle, restart or reset.'
    echo 'Some commands may be denied under shell or SELinux; this is evidence.'
    echo 'Reports may contain SSIDs, MAC/IP addresses and other personal metadata.'
    echo 'Secret-line filtering is best effort; review before public sharing.'
    echo 'No saved-network credential files are read.'
    printf 'started_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'timeout_backend=%s\n' "${TIMEOUT:-unavailable}"
    id
} > "$REPORT"

echo "Diagnostic started. Output: $OUT"
collect 'Execution identity / SELinux' all /system/bin/sh -c 'id; id -Z; getenforce; cat /proc/self/attr/current; command -v su'
collect 'Firmware / uptime' all /system/bin/sh -c '
    for p in ro.product.manufacturer ro.product.model ro.product.device ro.build.display.id ro.build.fingerprint ro.build.version.release ro.build.version.sdk ro.build.version.security_patch ro.boot.hardware ro.hardware; do
        printf "%s=" "$p"; getprop "$p"
    done
    uname -a
    cat /proc/uptime
'

# Capture volatile log buffers early. -d reads and exits; it does not clear them.
collect 'Recent logcat: filtered from last 6000 lines' wifi logcat -b all -d -v threadtime -t 6000
collect 'Kernel ring buffer: filtered (may be restricted)' wifi dmesg

# Exact firmware command grammar, kept separately. Help contains no supplied secret.
bounded cmd wifi help > "$HELP" 2>&1
HELP_RC=$?
printf '\n===== cmd wifi help =====\nhelp_file=%s\nhelp_exit_code=%s\n' "$HELP" "$HELP_RC" >> "$REPORT"
cat "$HELP" >> "$REPORT"

collect 'Android Wi-Fi status' all cmd wifi status
collect 'Interfaces' all ip link show
collect 'Interface addresses' all ip address show
collect 'Routes in all tables' all ip route show table all
collect 'IPv6 routes in all tables' all ip -6 route show table all
collect 'Policy routing' all ip rule show
collect 'wlan0 interface state' all /system/bin/sh -c '
    if [ -d /sys/class/net/wlan0 ]; then
        echo "wlan0 present"
        ip link show dev wlan0
        for f in operstate carrier flags mtu; do
            printf "%s=" "$f"; cat "/sys/class/net/wlan0/$f"
        done
        readlink -f /sys/class/net/wlan0/device/driver
    else
        echo "wlan0 absent (alone this does not establish a driver fault)"
    fi
    ls -l /sys/class/net
    cat /proc/net/wireless
'
collect 'Wi-Fi and related properties' wifi getprop
collect 'Wi-Fi process names (without command arguments)' wifi ps -A -o USER,PID,PPID,NAME
collect 'Binder services' wifi service list
collect 'HIDL HAL inventory (AIDL HALs may appear only in Binder services)' wifi lshal
collect 'Relevant init service definitions' all /system/bin/sh -c '
    for f in /vendor/etc/init/*.rc /vendor/etc/init/hw/*.rc /odm/etc/init/*.rc /system/etc/init/*.rc /system/etc/init/hw/*.rc /system_ext/etc/init/*.rc; do
        [ -r "$f" ] || continue
        awk -v file="$f" '\''
            /^[^# \t]/ { keep=0 }
            /^service[ \t]/ && tolower($0) ~ /wifi|wlan|supplicant|hostapd|cnss/ { print "FILE: " file; keep=1 }
            keep { print }
        '\'' "$f"
    done
'
collect 'Loaded kernel modules' wifi cat /proc/modules
collect 'Wi-Fi requested state and airplane mode (read only)' all /system/bin/sh -c '
    printf "wifi_on="; settings get global wifi_on
    printf "airplane_mode_on="; settings get global airplane_mode_on
    printf "wifi_scan_always_enabled="; settings get global wifi_scan_always_enabled
'
collect 'Full Wi-Fi dumpsys with secret-line filtering' all dumpsys -t 15 wifi
collect 'System server thread CPU usage (look for WifiScanningSer)' all /system/bin/sh -c '
    server_pid=$(pidof system_server)
    case "$server_pid" in ""|*[!0-9]*) echo "Cannot resolve one system_server PID"; exit 1;; esac
    top -H -b -n 1 -p "$server_pid"
'
collect 'Wi-Fi scanner state (a dump timeout is significant)' all dumpsys -t 15 wifiscanner
collect 'Native wificond and kernel country code' all dumpsys -t 15 wifinl80211
collect 'Connectivity / DHCP / validation state' all dumpsys -t 15 connectivity
collect 'Network stack DHCP details (if service exists)' all dumpsys -t 15 network_stack

# This AYN firmware prints useful help but returns 255. Inspect content too.
if grep -q '^  list-scan-results' "$HELP"; then
    collect 'Cached scan results only; no new scan requested' all cmd wifi list-scan-results
fi
collect 'Final Wi-Fi status (detect change during collection)' all cmd wifi status
printf '\nfinished_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$REPORT"
echo "Diagnostic finished: $REPORT"
echo "Command reference: $HELP"
echo 'No repair attempted. Nonzero section exit codes require inspection.'
