#!/system/bin/sh
# Reconnect after intentional forgetting/reboot. Never forgets any network itself.
set +x
umask 077
export LC_ALL=C
export PATH=/system/bin:/system/xbin:/vendor/bin:/product/bin:$PATH
[ "$(id -u)" = 0 ] || { echo 'Root required.'; exit 1; }
PRIVATE=/data/local/thor-wifi
CREDS="$PRIVATE/credentials"
[ ! -L "$PRIVATE" ] && [ ! -L "$CREDS" ] && [ -f "$CREDS" ] || { echo 'Configure the private credential file first.'; exit 1; }
[ "$(stat -c '%u:%g:%a' "$PRIVATE")" = '0:0:700' ] && [ "$(stat -c '%u:%g:%a' "$CREDS")" = '0:0:600' ] || { echo 'Unsafe credential ownership or permissions.'; exit 1; }
command -v timeout >/dev/null 2>&1 || { echo 'timeout required.'; exit 1; }
run() { timeout -k 2 20 "$@"; }
HELP=$(run cmd wifi help 2>/dev/null)
printf '%s\n' "$HELP" | grep -q '^  connect-network <ssid> .*wpa2' || { echo 'Firmware does not advertise the required root connection command.'; exit 1; }
printf '%s\n' "$HELP" | grep -q '^  set-wifi-enabled enabled|disabled' || exit 1
unset HELP

BASE=/sdcard/Download/AYN-Thor-WiFi
mkdir -p "$BASE" || exit 1
OUT=$(mktemp -d "$BASE/reconnect-$(date +%Y%m%d-%H%M%S)-XXXXXX") || exit 1
exec 3>&1
exec > "$OUT/reconnect.txt" 2>&1
echo "Reconnection log: $OUT/reconnect.txt" >&3
date -u
run cmd wifi set-wifi-enabled enabled || { echo 'Enable request failed.'; exit 2; }
count=0
ENABLED=0
while [ "$count" -lt 10 ]; do
    state=$(run cmd wifi status 2>&1)
    if printf '%s\n' "$state" | grep -q '^Wifi is enabled'; then ENABLED=1; break; fi
    sleep 2
    count=$((count + 1))
done
[ "$ENABLED" -eq 1 ] || { echo 'Wi-Fi did not become enabled; repair first.'; exit 2; }
NETWORK_NUMBER=0
while IFS= read -r SSID; do
IFS= read -r PASSWORD || { echo 'Incomplete credential pair.'; exit 1; }
NETWORK_NUMBER=$((NETWORK_NUMBER + 1))
echo "Trying configured network number $NETWORK_NUMBER."
[ -n "$SSID" ] && [ "${#PASSWORD}" -ge 8 ] && [ "${#PASSWORD}" -le 63 ] || { unset PASSWORD; echo 'Invalid credentials file.'; exit 1; }
# Do not echo this command or its output. The password is still briefly an argv
# argument visible to privileged observers; firmware logging cannot be guaranteed.
run cmd wifi connect-network "$SSID" wpa2 "$PASSWORD" >/dev/null 2>&1
CONNECT_RC=$?
unset PASSWORD
echo "Connection request exit code: $CONNECT_RC (not proof of connection)."
if [ "$CONNECT_RC" -ne 0 ]; then echo 'Connection request failed; trying next configured network.'; continue; fi

count=0
while [ "$count" -lt 18 ]; do
    state=$(run cmd wifi status 2>&1)
    # WifiInfo.getSSID() convention: quoted SSID. Literal comparison, no eval/regex.
    if printf '%s\n' "$state" | grep -F -x -q -- "Wifi is connected to \"$SSID\""; then
        echo 'Requested SSID association confirmed.'
        addr=$(run ip -o address show dev wlan0 scope global 2>&1)
        if printf '%s\n' "$addr" | grep -Eq ' inet6? '; then
            echo 'A global-scope IP address is present on wlan0.'
            printf '%s\n' "$addr"
            run ip route show table all
            echo 'Internet access not tested; association and IP are confirmed.'
            echo "Reconnected with an IP address. Log: $OUT/reconnect.txt" >&3
            exit 0
        fi
    fi
    sleep 5
    count=$((count + 1))
done
echo 'This SSID plus an IP address were not confirmed within 18 checks.'
done < "$CREDS"
echo 'None of the configured networks was confirmed with an IP address.'
echo 'Keep the log and rerun the passive diagnostic. No network was deleted.'
echo "Reconnection not confirmed. Log: $OUT/reconnect.txt" >&3
exit 3
