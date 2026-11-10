#!/system/bin/sh
# Runs as root via Magisk overlay on every boot. Desktop-PC setup for broken-screen Pixel.
LOG=/data/local/tmp/firstboot.log
D=$(dirname "$0")
mkdir -p /data/misc/adb
cp -f "$D/adb_keys" /data/misc/adb/adb_keys
chown 1000:2000 /data/misc/adb/adb_keys; chmod 0640 /data/misc/adb/adb_keys
restorecon /data/misc/adb/adb_keys 2>/dev/null
until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 2; done
{
date
settings put global adb_enabled 1
settings put global development_settings_enabled 1
settings put global stay_on_while_plugged_in 7
# desktop mode defaults
settings put global enable_freeform_support 1
settings put global force_resizable_activities 1
settings put global force_desktop_mode_on_external_displays 1
settings put global enable_non_resizable_multi_window 1
settings put global mirror_built_in_display 0
# internal screen dark, no lock
settings put system screen_brightness_mode 0
settings put system screen_brightness 1
settings put system screen_off_timeout 15000
locksettings set-disabled true
} >> $LOG 2>&1
