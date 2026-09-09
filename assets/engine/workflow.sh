#!/system/bin/sh
set +x
umask 077
export LC_ALL=C
export PATH=/system/bin:/system/xbin:/vendor/bin:$PATH
[ "$(id -u)" = 0 ] || exit 1
P=/data/local/thor-wifi
BIN="$P/bin"
CREDS="$P/credentials"
BOOT=$(cat /proc/sys/kernel/random/boot_id)
OP=${1:-status}
. "$BIN/workflow_guard.sh"
case "$OP" in worker) ;; *) thor_clear_stale;; esac
PUBLIC=/sdcard/Download/Thor-Scripts/WIFI_RESEAUX.txt
case "$OP" in status|import|reload|export-config|forget|forget-selected|forget-all|resume|worker|connect|companion-test) ;; *) exit 1;; esac
# AYN's native bridge can return its first stdout chunk before a multi-step
# script finishes. Buffer output until exit so a closed pipe cannot interrupt it.
exec 3>&1
exec > "$P/operation-$OP.txt" 2>&1
flush_output() { awk 'BEGIN { ORS="; " } { print } END { printf "\n" }' "$P/operation-$OP.txt" >&3; }
trap flush_output EXIT
run() { timeout -k 2 20 "$@"; }
state() { printf '%s\n' "$1" > "$P/status"; printf '%s\n' "$1"; }
export_public() {
    mkdir -p /sdcard/Download/Thor-Scripts || return 1
    {
        echo '# Configuration Wi-Fi locale. Mot de passe en clair, selon votre choix.'
        echo '# Pour ajouter un reseau, ajouter deux lignes SSID= et MOT_DE_PASSE=.'
        echo '# Les valeurs sont du texte litteral : ne pas ajouter de guillemets.'
        echo '# Connexions WPA2 / WPA3 automatiques. Les scripts lisent ce fichier sans executer son contenu.'
        while IFS= read -r ssid; do
            IFS= read -r secret || return 1
            printf '\nSSID=%s\nMOT_DE_PASSE=%s\n' "$ssid" "$secret"
            unset secret
        done < "$CREDS"
    } > "$PUBLIC"
}
load_public() {
    [ -f "$PUBLIC" ] || return 0
    tmp=$(mktemp "$P/.config-XXXXXX") || return 1
    cr=$(printf '\r')
    waiting=0; configured=0
    while IFS= read -r line || [ -n "$line" ]; do
        line=${line%"$cr"}
        case "$line" in
        ''|'#'*) continue;;
        SSID=*)
            [ "$waiting" = 0 ] || { rm -f "$tmp"; return 1; }
            ssid=${line#SSID=}
            [ -n "$ssid" ] && [ "${#ssid}" -le 32 ] || { rm -f "$tmp"; return 1; }
            waiting=1;;
        MOT_DE_PASSE=*)
            [ "$waiting" = 1 ] || { rm -f "$tmp"; return 1; }
            secret=${line#MOT_DE_PASSE=}
            [ "${#secret}" -ge 8 ] && [ "${#secret}" -le 63 ] || { rm -f "$tmp"; return 1; }
            printf '%s\n%s\n' "$ssid" "$secret" >> "$tmp"
            unset secret line
            waiting=0; configured=$((configured + 1));;
        *) rm -f "$tmp"; return 1;;
        esac
    done < "$PUBLIC"
    [ "$waiting" = 0 ] && [ "$configured" -gt 0 ] || { rm -f "$tmp"; return 1; }
    chmod 600 "$tmp" && mv -f "$tmp" "$CREDS"
}
validate() {
    [ ! -L "$P" ] && [ "$(stat -c '%u:%g:%a' "$P")" = 0:0:700 ] || return 1
    [ -f "$CREDS" ] && [ ! -L "$CREDS" ] && [ "$(stat -c '%u:%g:%a' "$CREDS")" = 0:0:600 ] || return 1
    rows=$(wc -l < "$CREDS")
    [ "$rows" -ge 2 ] && [ $((rows % 2)) -eq 0 ] || return 1
    while IFS= read -r ssid; do
        IFS= read -r secret || return 1
        [ -n "$ssid" ] && [ "${#ssid}" -le 32 ] && [ "${#secret}" -ge 8 ] && [ "${#secret}" -le 63 ] || return 1
        # list-networks pads columns; edge whitespace cannot be matched reliably.
        case "$ssid" in ' '*|*' '|*'	'*) return 1;; esac
        unset secret
    done < "$CREDS"
}
targets() {
    if [ "$OP" = forget-all ]; then
        awk '/^[[:space:]]*[0-9]+[[:space:]]/ {print $1}' "$1" | sort -u
        return
    fi
    while IFS= read -r ssid; do
        IFS= read -r secret || return 1
        unset secret
        THOR_SSID="$ssid" awk '
            /^[[:space:]]*[0-9]+[[:space:]]/ {
                id=$1; text=$0
                sub(/^[[:space:]]*[0-9]+[[:space:]]+/, "", text)
                sub(/[[:space:]]+[^[:space:]]+[[:space:]]*$/, "", text)
                sub(/[[:space:]]+$/, "", text)
                if (text == ENVIRON["THOR_SSID"]) print id
            }' "$1"
    done < "$CREDS" | sort -u
}
# Keep the reboot credential snapshot stable while an operation is pending.
case "$OP" in
reload|forget|forget-selected|forget-all|connect)
    [ ! -f "$P/pending" ] && [ ! -f "$P/working" ] || { echo STOP_WORKFLOW_ALREADY_PENDING; exit 1; };;
esac
case "$OP" in
status)
    echo WORKFLOW_VERSION=4
    if validate; then printf 'CONFIGURED_NETWORKS=%s\n' "$((rows / 2))"; else echo 'CONFIGURED_NETWORKS=0'; fi
    [ ! -f "$P/companion-tested" ] || echo COMPANION_ROOT_VERIFIED=1
    [ ! -f "$P/status" ] || cat "$P/status"
    [ ! -f "$P/connection-reason" ] || cat "$P/connection-reason"
    [ ! -f "$P/pending" ] || echo 'RESUME_PENDING=1'
    [ ! -f "$P/last-boot-receiver" ] || printf 'BOOT_RECEIVER_SEEN=%s\n' "$(cat "$P/last-boot-receiver")"
    exit 0;;
reload)
    load_public && validate || { state CONFIG_FILE_INVALID; exit 1; }
    state "CONFIG_FILE_OK_NETWORKS=$((rows / 2))"
    exit 0;;
export-config)
    validate || { state STOP_NO_VALID_PRIVATE_CREDENTIALS; exit 1; }
    export_public || { state EXPORT_FAILED; exit 1; }
    state CONFIG_FILE_READY
    exit 0;;
import)
    [ ! -f "$P/pending" ] && [ ! -f "$P/working" ] || { echo STOP_WORKFLOW_ALREADY_PENDING; exit 1; }
    /system/bin/sh "$BIN/wifi_save_credentials.sh" >/dev/null 2>&1 || { state IMPORT_FAILED; exit 1; }
    validate || { state IMPORT_INVALID; exit 1; }
    export_public || { state PUBLIC_EXPORT_FAILED; exit 1; }
    state "IMPORT_OK_NETWORKS=$((rows / 2))"
    exit 0;;
forget|forget-selected|forget-all)
    [ "$OP" != forget ] || load_public || { state CONFIG_FILE_INVALID_NO_REBOOT; exit 1; }
    validate || { state STOP_NO_VALID_PRIVATE_CREDENTIALS; exit 1; }
    [ ! -f "$P/pending" ] && [ ! -f "$P/working" ] || { echo 'STOP_WORKFLOW_ALREADY_PENDING'; exit 1; }
    run pm path local.thor.wifiresume >/dev/null 2>&1 || { state STOP_RESUME_APP_MISSING; exit 1; }
    [ -f "$P/companion-tested" ] || { state STOP_RESUME_APP_UNVERIFIED; exit 1; }
    run /system/bin/sh "$BIN/wifi_reconnect.sh" --remember-security >/dev/null 2>&1 || { state SECURITY_UNKNOWN_NO_REBOOT; exit 1; }
    run cmd wifi help > "$P/help" 2>&1
    grep -q '^  forget-network <networkId>' "$P/help" && grep -q '^  connect-network <ssid> .*wpa2' "$P/help" || { state STOP_UNSUPPORTED_FIRMWARE; exit 1; }
    run cmd wifi list-networks > "$P/networks-before" 2>/dev/null || { state STOP_LIST_FAILED; exit 1; }
    targets "$P/networks-before" > "$P/target-ids"
    [ "$OP" = forget-all ] || [ -s "$P/target-ids" ] || { state STOP_NO_MATCHING_SAVED_NETWORK; exit 1; }
    # Entire target plan is resolved before changing any saved network.
    while IFS= read -r netid; do
        case "$netid" in ''|*[!0-9]*) state STOP_INVALID_NETWORK_ID; exit 1;; esac
    done < "$P/target-ids"
    if [ "$OP" = forget-all ]; then state FORGETTING_ALL_SAVED_NETWORKS; else state FORGETTING_CONFIGURED_NETWORKS; fi
    while IFS= read -r netid; do
        run cmd wifi list-networks > "$P/networks-current" 2>/dev/null || { state LIST_FAILED_NO_REBOOT; exit 1; }
        targets "$P/networks-current" > "$P/current-target-ids"
        grep -x -q "$netid" "$P/current-target-ids" || { state TARGET_CHANGED_NO_REBOOT; exit 1; }
        run cmd wifi forget-network "$netid" >/dev/null 2>&1 || { state FORGET_FAILED_NO_REBOOT; exit 1; }
    done < "$P/target-ids"
    left=1
    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        run cmd wifi list-networks > "$P/networks-after" 2>/dev/null || { state VERIFY_FAILED_NO_REBOOT; exit 1; }
        targets "$P/networks-after" > "$P/remaining-ids"
        if [ ! -s "$P/remaining-ids" ]; then left=0; break; fi
        sleep 1
    done
    [ "$left" = 0 ] || { state FORGET_NOT_CONFIRMED_NO_REBOOT; exit 1; }
    printf '%s\n' "$BOOT" > "$P/pending"
    state REBOOT_REQUESTED
    sync
    reboot
    exit 0;;
resume)
    printf '%s\n' "$BOOT" > "$P/last-boot-receiver"
    [ -f "$P/pending" ] || { echo NO_PENDING_ACTION; exit 0; }
    [ "$(cat "$P/pending")" != "$BOOT" ] || { echo WAITING_FOR_REBOOT; exit 0; }
    validate || { state RESUME_INVALID_CREDENTIALS; exit 1; }
    # Atomic rename gives one consumer even if the PC and boot receiver race.
    mv "$P/pending" "$P/working" 2>/dev/null || { echo ALREADY_CLAIMED; exit 0; }
    touch "$P/working"
    nohup /system/bin/sh "$BIN/workflow.sh" worker </dev/null >/dev/null 2>&1 &
    echo RESUME_DISPATCHED
    exit 0;;
worker|connect)
    printf '%s\n' "$$" > "$P/worker.pid"
    worker_cleanup() {
        if [ "$(cat "$P/worker.pid" 2>/dev/null)" = "$$" ]; then
            rm -f "$P/working" "$P/worker.pid"
            if [ "$(cat "$P/status" 2>/dev/null)" = RECONNECTING ]; then state WORKER_INTERRUPTED; fi
        fi
    }
    # Cleanup on normal/error/signal exits; SIGKILL is handled by the stale guard.
    trap 'worker_cleanup; flush_output' EXIT
    trap 'exit 143' TERM HUP
    trap 'exit 130' INT
    if [ "$OP" = connect ]; then load_public || { state CONFIG_FILE_INVALID; exit 1; }; fi
    validate || { state STOP_NO_VALID_PRIVATE_CREDENTIALS; exit 1; }
    if [ "$OP" = connect ]; then printf '%s\n' "$BOOT" > "$P/working"; fi
    state RECONNECTING
    budget=$((150 * rows / 2))
    timeout -k 2 "$budget" /system/bin/sh "$BIN/wifi_reconnect.sh" > "$P/last-connect-result" 2>&1
    rc=$?
    if [ "$rc" = 0 ]; then state CONNECTED_WITH_IP; else state "RECONNECT_NOT_CONFIRMED_RC=$rc"; fi
    exit "$rc";;
companion-test)
    date -u > "$P/companion-tested"
    echo COMPANION_ROOT_OK
    exit 0;;
*) echo UNSUPPORTED_OPERATION; exit 1;;
esac
