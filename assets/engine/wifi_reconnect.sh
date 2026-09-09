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
WPA3_SUPPORTED=0
printf '%s\n' "$HELP" | grep -q '^  connect-network <ssid> .*wpa3' && WPA3_SUPPORTED=1
unset HELP
# Match the SSID literally between the first four columns and the final flags.
# Never interpret profile text as shell or awk source. Cached scans describe
# authentication only; they are not proof of current visibility or association.
security() {
    THOR_TARGET_SSID="$1" awk '
        /^[[:space:]]*[[:xdigit:]:]+[[:space:]]+[0-9]+[[:space:]]/ {
            age=$4; text=$0; flags=$NF
            for (i=0;i<4;i++) sub(/^[[:space:]]*[^[:space:]]+[[:space:]]+/, "", text)
            sub(/[[:space:]]+[^[:space:]]+[[:space:]]*$/, "", text)
            sub(/[[:space:]]+$/, "", text)
            if (text != ENVIRON["THOR_TARGET_SSID"]) next
            if (flags ~ /PSK/) psk=1
            else if (flags ~ /SAE/) sae=1
            else unsupported=1
        }
        END {if(psk) print "wpa2"; else if(sae) print "wpa3"; else if(unsupported) print "unsupported"}
    '
}
reason() { printf '%s\n' "$1" > "$PRIVATE/connection-reason"; }
security_key() { printf '%s' "$1" | sha256sum | cut -d ' ' -f 1; }
remember_security() {
    local auth key tmp
    auth=$(run cmd wifi list-scan-results 2>/dev/null | security "$1")
    case "$auth" in wpa2|wpa3) ;; *) return 1;; esac
    key=$(security_key "$1")
    [ ! -L "$PRIVATE/security-cache" ] || return 1
    mkdir -p "$PRIVATE/security-cache" && chmod 700 "$PRIVATE/security-cache" || return 1
    tmp=$(mktemp "$PRIVATE/security-cache/.new-XXXXXX") || return 1
    printf '%s\n%s\n' "$1" "$auth" > "$tmp"
    chmod 600 "$tmp" && mv -f "$tmp" "$PRIVATE/security-cache/$key" || return 1
}
cached_security() {
    local key name mode
    key=$(security_key "$1")
    [ ! -L "$PRIVATE/security-cache" ] && [ ! -L "$PRIVATE/security-cache/$key" ] || return 1
    [ -f "$PRIVATE/security-cache/$key" ] || return 1
    { IFS= read -r name; IFS= read -r mode; } < "$PRIVATE/security-cache/$key"
    [ "$name" = "$1" ] || return 1
    case "$mode" in wpa2|wpa3) printf '%s\n' "$mode";; *) return 1;; esac
}
if [ "${1:-}" = --remember-security ]; then
    while IFS= read -r SSID; do
        IFS= read -r PASSWORD || exit 1
        unset PASSWORD
        remember_security "$SSID" || :
        mode=$(cached_security "$SSID") || { echo SECURITY_UNKNOWN_NO_REBOOT; exit 1; }
        [ "$mode" != wpa3 ] || [ "$WPA3_SUPPORTED" = 1 ] || { echo STOP_UNSUPPORTED_FIRMWARE; exit 1; }
    done < "$CREDS"
    echo SECURITY_SNAPSHOT_OK
    exit 0
fi
reason CONNECTION_PENDING

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
# A scan refresh does not forget any network or toggle Wi-Fi off.
run cmd wifi start-scan >/dev/null 2>&1 || :
sleep 4
NETWORK_NUMBER=0
while IFS= read -r SSID; do
IFS= read -r PASSWORD || { echo 'Incomplete credential pair.'; exit 1; }
NETWORK_NUMBER=$((NETWORK_NUMBER + 1))
echo "Trying configured network number $NETWORK_NUMBER."
[ -n "$SSID" ] && [ "${#PASSWORD}" -ge 8 ] && [ "${#PASSWORD}" -le 63 ] || { unset PASSWORD; echo 'Invalid credentials file.'; exit 1; }
# Do not echo this command or its output. The password is still briefly an argv
# argument visible to privileged observers; firmware logging cannot be guaranteed.
AUTH=""
for scan_attempt in 1 2 3; do
    AUTH=$(run cmd wifi list-scan-results 2>/dev/null | security "$SSID")
    [ -z "$AUTH" ] || break
    run cmd wifi start-scan >/dev/null 2>&1 || :
    sleep 3
done
case "$AUTH" in
    wpa2|wpa3) remember_security "$SSID" || :;;
    '') AUTH=$(cached_security "$SSID"); [ -z "$AUTH" ] || echo 'Using previously observed authentication; association is still to be verified.';;
esac
case "$AUTH" in
    wpa2) ;;
    wpa3) [ "$WPA3_SUPPORTED" = 1 ] || { unset PASSWORD; reason WPA3_UNSUPPORTED; echo 'WPA3 is not advertised by this firmware.'; continue; };;
    unsupported) unset PASSWORD; reason SECURITY_UNSUPPORTED; echo 'This visible network does not advertise WPA2-PSK or WPA3-SAE.'; continue;;
    *) unset PASSWORD; reason NETWORK_NOT_VISIBLE; echo 'Selected network not found in a recent scan.'; continue;;
esac
echo "Detected authentication: $AUTH."
reason CONNECTION_PENDING
run cmd wifi connect-network "$SSID" "$AUTH" "$PASSWORD" >/dev/null 2>&1
CONNECT_RC=$?
unset PASSWORD
echo "Connection request exit code: $CONNECT_RC (not proof of connection)."
if [ "$CONNECT_RC" -ne 0 ]; then reason CONNECTION_REQUEST_FAILED; echo 'Connection request failed; trying next configured network.'; continue; fi

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
            reason CONNECTED_WITH_IP
            exit 0
        fi
    fi
    sleep 5
    count=$((count + 1))
done
reason ASSOCIATION_OR_IP_FAILED
echo 'This SSID plus an IP address were not confirmed within 18 checks.'
done < "$CREDS"
echo 'None of the configured networks was confirmed with an IP address.'
echo 'Keep the log and rerun the passive diagnostic. No network was deleted.'
echo "Reconnection not confirmed. Log: $OUT/reconnect.txt" >&3
exit 3
