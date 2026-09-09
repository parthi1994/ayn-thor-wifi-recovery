#!/system/bin/sh
# App-private files carry credentials; Binder commands contain fixed paths only.
set +x
umask 077
export LC_ALL=C
export PATH=/system/bin:/system/xbin:/vendor/bin:$PATH
[ "$(id -u)" = 0 ] || exit 1
P=/data/local/thor-wifi
A=/data/user/0/local.thor.wifiresume/files/exchange
PUBLIC=/sdcard/Download/Thor-Scripts/WIFI_RESEAUX.txt
OP=${1:-snapshot}
case "$OP" in snapshot|save|connect|forget) ;; *) exit 1;; esac
[ -d "$A" ] && [ ! -L "$A" ] || exit 1
OWNER=$(stat -c '%u:%g' "$A") || exit 1
run() { timeout -k 2 15 "$@"; }
deliver() { chown "$OWNER" "$A/$1" && chmod 600 "$A/$1"; }
if [ "$OP" = snapshot ]; then
    cp "$PUBLIC" "$A/catalog.txt" || { echo CATALOG_READ_FAILED; exit 1; }
    run cmd wifi list-networks > "$A/known.txt" 2>/dev/null || :
    run cmd wifi status > "$A/wifi.txt" 2>/dev/null || :
    /system/bin/sh "$P/bin/workflow.sh" status > "$A/status.txt" 2>/dev/null
    for file in catalog.txt known.txt wifi.txt status.txt; do deliver "$file" || exit 1; done
    echo SNAPSHOT_OK
    exit 0
fi
mkdir "$P/app-lock" 2>/dev/null || { echo BUSY; exit 1; }
trap 'rm -f "$P/.app-parsed"; rmdir "$P/app-lock"' EXIT
[ ! -f "$P/pending" ] && [ ! -f "$P/working" ] || { echo BUSY; exit 1; }
# Parse into private paired lines; never execute configuration contents.
parse() {
    local waiting=0 configured=0 line ssid secret cr
    cr=$(printf '\r')
    : > "$P/.app-parsed"
    while IFS= read -r line || [ -n "$line" ]; do
        line=${line%"$cr"}
        case "$line" in
        ''|'#'*) continue;;
        SSID=*)
            [ "$waiting" = 0 ] || return 1
            ssid=${line#SSID=}
            [ -n "$ssid" ] && [ "${#ssid}" -le 32 ] || return 1
            case "$ssid" in ' '*|*' ' |*'	'*) return 1;; esac
            waiting=1;;
        MOT_DE_PASSE=*)
            [ "$waiting" = 1 ] || return 1
            secret=${line#MOT_DE_PASSE=}
            [ "${#secret}" -ge 8 ] && [ "${#secret}" -le 63 ] || return 1
            printf '%s\n%s\n' "$ssid" "$secret" >> "$P/.app-parsed"
            unset secret line
            waiting=0; configured=$((configured + 1));;
        *) return 1;;
        esac
    done < "$1"
    [ "$waiting" = 0 ] || return 1
    COUNT=$configured
}
if [ "$OP" = save ]; then
    parse "$A/catalog-request.txt" || { echo INVALID_CONFIG; exit 1; }
    cp "$A/catalog-request.txt" /sdcard/Download/Thor-Scripts/.WIFI_RESEAUX.tmp && mv /sdcard/Download/Thor-Scripts/.WIFI_RESEAUX.tmp "$PUBLIC" || { echo SAVE_FAILED; exit 1; }
    if [ "$COUNT" = 0 ]; then
        rm -f "$P/credentials"
    else
        chmod 600 "$P/.app-parsed" && mv "$P/.app-parsed" "$P/credentials" || exit 1
    fi
    rm -f "$A/catalog-request.txt"
    echo SAVE_OK
    exit 0
fi
parse "$A/selection-request.txt" && [ "$COUNT" = 1 ] || { echo INVALID_SELECTION; exit 1; }
chmod 600 "$P/.app-parsed" && mv "$P/.app-parsed" "$P/credentials" || exit 1
rm -f "$A/selection-request.txt"
if [ "$OP" = connect ]; then
    cat /proc/sys/kernel/random/boot_id > "$P/working"
    echo RECONNECTING > "$P/status"
    nohup /system/bin/sh "$P/bin/workflow.sh" worker </dev/null >/dev/null 2>&1 &
    echo CONNECT_STARTED
else
    # Selection deliberately bypasses the public catalog: only this SSID is forgotten.
    /system/bin/sh "$P/bin/workflow.sh" forget-selected
fi
