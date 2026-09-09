#!/system/bin/sh
# Import a credential pair supplied locally over USB. Does not change Wi-Fi state.
set +x
umask 077
export PATH=/system/bin:/system/xbin:/vendor/bin:$PATH
[ "$(id -u)" = 0 ] || { echo 'Root required.'; exit 1; }
REPORT_BASE=/sdcard/Download/AYN-Thor-WiFi
mkdir -p "$REPORT_BASE" || exit 1
REPORT_DIR=$(mktemp -d "$REPORT_BASE/credentials-import-$(date +%Y%m%d-%H%M%S)-XXXXXX") || exit 1
echo "Credential import status: $REPORT_DIR/status.txt"
exec > "$REPORT_DIR/status.txt" 2>&1
date -u
PRIVATE=/data/local/thor-wifi
STAGE=/data/local/tmp/thor-wifi-credentials.in
[ ! -L "$PRIVATE" ] || { echo 'Unsafe private directory.'; exit 1; }
if [ ! -d "$PRIVATE" ]; then mkdir -m 700 "$PRIVATE" || exit 1; fi
[ "$(stat -c '%u:%g:%a' "$PRIVATE")" = '0:0:700' ] || { echo 'Private directory must be root:root 700.'; exit 1; }
[ -f "$STAGE" ] && [ ! -L "$STAGE" ] || { echo 'First run CONFIGURER_RESEAU.ps1 on the PC.'; exit 1; }
[ "$(stat -c '%u:%a' "$STAGE")" = '2000:600' ] || { echo 'Staging file must be shell-owned, mode 600.'; exit 1; }
LINES=$(wc -l < "$STAGE" | tr -d ' ')
[ "$LINES" -ge 2 ] && [ $((LINES % 2)) -eq 0 ] || { echo 'Invalid credential format.'; exit 1; }
COUNT=0
while IFS= read -r SSID; do
    IFS= read -r PASSWORD || { echo 'Incomplete credential pair.'; exit 1; }
    [ "${#SSID}" -ge 1 ] && [ "${#SSID}" -le 32 ] || { echo 'Invalid SSID length.'; exit 1; }
    [ "${#PASSWORD}" -ge 8 ] && [ "${#PASSWORD}" -le 63 ] || { echo 'Expected WPA2 passphrases of 8-63 characters.'; exit 1; }
    COUNT=$((COUNT + 1))
done < "$STAGE"
unset SSID PASSWORD
TEMP=$(mktemp "$PRIVATE/.credentials-XXXXXX") || exit 1
if ! cat "$STAGE" > "$TEMP" || ! chmod 600 "$TEMP" || ! mv -f "$TEMP" "$PRIVATE/credentials"; then
    rm -f "$TEMP"
    echo 'Credential import failed.'
    exit 1
fi
rm -f "$STAGE" || { echo 'Imported, but temporary input could not be removed.'; exit 1; }
echo "$COUNT network credential pairs saved in private root storage; temporary input removed."
echo 'Wi-Fi unchanged. You may now voluntarily forget the network and reboot.'
