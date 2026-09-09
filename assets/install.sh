#!/system/bin/sh
set +x
umask 077
[ "$(id -u)" = 0 ] || exit 1
P=/data/local/thor-wifi
SRC=/data/user/0/local.thor.wifiresume/files/bootstrap
[ ! -L "$P" ] || exit 1
mkdir -p "$P" || exit 1
[ "$(stat -c '%u:%g' "$P")" = 0:0 ] || exit 1
chmod 700 "$P" || exit 1
. "$SRC/engine/workflow_guard.sh"
thor_clear_stale
[ ! -f "$P/pending" ] && [ ! -f "$P/working" ] || { echo BUSY; exit 1; }
[ ! -L "$P/bin" ] || exit 1
mkdir -p "$P/bin" || exit 1
chmod 700 "$P/bin"
for name in workflow workflow_guard wifi_reconnect wifi_save_credentials wifi_diagnostic wifi_repair app_api; do
    /system/bin/sh -n "$SRC/engine/$name.sh" || { echo INVALID_SCRIPT; exit 1; }
done
for name in workflow workflow_guard wifi_reconnect wifi_save_credentials wifi_diagnostic wifi_repair app_api; do
    cp "$SRC/engine/$name.sh" "$P/bin/.$name.new" && chmod 500 "$P/bin/.$name.new" && mv "$P/bin/.$name.new" "$P/bin/$name.sh" || exit 1
done
mkdir -p /sdcard/Download/Thor-Scripts || exit 1
for launcher in "$SRC"/launchers/*.sh; do
    cp "$launcher" /sdcard/Download/Thor-Scripts/ || exit 1
done
if [ ! -f /sdcard/Download/Thor-Scripts/WIFI_RESEAUX.txt ]; then
    if [ -s "$P/credentials" ]; then
        /system/bin/sh "$P/bin/workflow.sh" export-config >/dev/null 2>&1 || exit 1
    else
        printf '# Thor Wi-Fi : ajouter des reseaux depuis l application.\n' > /sdcard/Download/Thor-Scripts/WIFI_RESEAUX.txt || exit 1
    fi
fi
date -u > "$P/companion-tested"
echo INSTALL_OK
