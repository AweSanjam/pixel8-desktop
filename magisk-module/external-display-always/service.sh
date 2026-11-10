#!/system/bin/sh
# Runs as root after boot. Keeps the external display as the primary experience.
until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 2; done
LOG=/data/local/tmp/external_display_always.log
{
date
setprop persist.vendor.usb.displayport.enabled 1
echo 1 > /sys/module/exynos_drm/parameters/dp_enabled 2>/dev/null
settings put global adb_enabled 1
settings put global stay_on_while_plugged_in 7
# desktop mode on external displays (falls back to mirroring if unsupported)
settings put global development_settings_enabled 1
settings put global enable_freeform_support 1
settings put global force_resizable_activities 1
settings put global enable_non_resizable_multi_window 1
settings put global force_desktop_mode_on_external_displays 1
# internal panel: as dark as possible, quick timeout, no lock screen
settings put system screen_brightness_mode 0
settings put system screen_brightness 1
settings put system screen_off_timeout 15000
locksettings set-disabled true
} >> $LOG 2>&1
# re-assert DP whenever a cable is (re)plugged
while true; do
  [ "$(getprop persist.vendor.usb.displayport.enabled)" = 1 ] || setprop persist.vendor.usb.displayport.enabled 1
  sleep 10
done
