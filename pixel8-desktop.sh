#!/system/bin/sh
# pixel8-desktop: runs as root (su domain) at boot_completed on LineageOS userdebug.
LOG=/data/local/tmp/pixel8-desktop.log
{
echo "== $(date)"
setprop persist.vendor.usb.displayport.enabled 1
echo 1 > /sys/module/exynos_drm/parameters/dp_enabled
# USB debugging on, PC key trusted
settings put global adb_enabled 1
settings put global development_settings_enabled 1
svc usb setFunctions mtp,adb
# skip setup wizard
settings put global device_provisioned 1
settings put secure user_setup_complete 1
settings put secure tv_user_setup_complete 1
for p in org.lineageos.setupwizard com.google.android.setupwizard; do pm disable-user --user 0 $p; done
# desktop mode on the external display
settings put global enable_freeform_support 1
settings put global force_resizable_activities 1
settings put global enable_non_resizable_multi_window 1
settings put global force_desktop_mode_on_external_displays 1
setprop persist.wm.debug.desktop_mode_enforce_device_restrictions false
setprop persist.wm.debug.desktop_mode_enabled true
# internal panel dark, stay awake on power, no lock screen
settings put global stay_on_while_plugged_in 7
settings put system screen_brightness_mode 0
settings put system screen_brightness 1
locksettings set-disabled true
logcat -d -b all > /data/local/tmp/boot_logcat.txt
echo done
} >> $LOG 2>&1
while true; do
  [ "$(getprop persist.vendor.usb.displayport.enabled)" = 1 ] || setprop persist.vendor.usb.displayport.enabled 1
  [ "$(settings get global adb_enabled)" = 1 ] || { settings put global adb_enabled 1; svc usb setFunctions mtp,adb; }
  sleep 10
done
