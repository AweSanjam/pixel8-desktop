#!/system/bin/sh
# pixel8-extdisplay core — runs as root on every boot (Magisk module, Magisk overlay
# or the hard-coded system_ext service; whichever starts first wins the lock).
# Goal: broken-screen Pixel 8 that is fully usable on a USB-C DisplayPort monitor
# with a USB keyboard/mouse: DP on, internal screen mirrored (so the setup wizard
# and everything else shows on the monitor), ADB on, no lock screen, never sleeps.
#
# Mode file: /data/adb/extdisplay.conf   MODE=mirror (default) | desktop
#   mirror  = monitor shows the phone screen (use this for first setup)
#   desktop = Android desktop windowing on the monitor (takes effect after reboot)
LOCK=/dev/.pixel8_extdisplay
mkdir "$LOCK" 2>/dev/null || exit 0
LOG=/data/local/tmp/extdisplay.log
CONF=/data/adb/extdisplay.conf
log() { echo "$(date '+%F %T') [$1] $2" >> "$LOG" 2>/dev/null; }

# ---- early (post-fs-data): DisplayPort + USB debugging + trusted PC key ----
setprop persist.vendor.usb.displayport.enabled 1
echo 1 > /sys/module/exynos_drm/parameters/dp_enabled 2>/dev/null
case "$(getprop persist.sys.usb.config)" in *adb*) ;; *) setprop persist.sys.usb.config mtp,adb ;; esac
for k in /system_ext/etc/adb_keys /debug_ramdisk/adb_keys /sbin/adb_keys "$(dirname "$0")/adb_keys"; do
  if [ -s "$k" ]; then
    mkdir -p /data/misc/adb
    cat "$k" > /data/misc/adb/adb_keys
    chown 1000:2000 /data/misc/adb/adb_keys; chmod 0640 /data/misc/adb/adb_keys
    restorecon /data/misc/adb/adb_keys 2>/dev/null
    break
  fi
done
mkdir -p /data/local/tmp
log boot "start ($0) usb=$(getprop sys.usb.config) state=$(getprop sys.usb.state)"

until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 2; done
log boot "boot_completed adbd=$(getprop init.svc.adbd) usb=$(getprop sys.usb.config)"

MODE=mirror
[ -f "$CONF" ] && . "$CONF"
[ "$MODE" = desktop ] || MODE=mirror

# ---- system settings ----
settings put global adb_enabled 1
settings put global development_settings_enabled 1
settings put global stay_on_while_plugged_in 7
settings put system screen_off_timeout 1800000
settings put system screen_brightness_mode 0
settings put system screen_brightness 1
locksettings set-disabled true >/dev/null 2>&1
# windowing prerequisites (harmless in mirror mode)
settings put global enable_freeform_support 1
settings put global force_resizable_activities 1
settings put global enable_non_resizable_multi_window 1

apply_mode() {
  if [ "$MODE" = desktop ]; then
    settings put global force_desktop_mode_on_external_displays 1
    settings put global mirror_built_in_display 0
    settings put secure mirror_built_in_display 0
    setprop persist.wm.debug.desktop_mode_enforce_device_restrictions false
  else
    settings put global force_desktop_mode_on_external_displays 0
    settings put global mirror_built_in_display 1
    settings put secure mirror_built_in_display 1
  fi
  log mode "$MODE"
}
apply_mode

dp_connected() {
  for s in /sys/class/drm/card*-DP-*/status; do
    [ -f "$s" ] && { [ "$(cat "$s")" = connected ]; return; }
  done
  dumpsys display 2>/dev/null | grep -q "type EXTERNAL"
}

# Android 15+/16 asks "Mirror to external display?" on the phone screen (which is unreadable)
# before a new monitor is used: approve it automatically.
accept_display() {
  for id in $(dumpsys display 2>/dev/null | grep -oE 'mDisplayId=[0-9]+' | cut -d= -f2 | sort -u); do
    [ "$id" != 0 ] && cmd display enable-display "$id" >/dev/null 2>&1
  done
  uiautomator dump /data/local/tmp/xd_ui.xml >/dev/null 2>&1 || return
  b=$(grep -oE 'text="(Mirror display|Mirror|Extend|Use display|Allow|OK)"[^>]*bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' /data/local/tmp/xd_ui.xml | head -1 | grep -oE '\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]')
  if [ -n "$b" ]; then
    set -- $(echo "$b" | tr '[],' '   ')
    input tap $(( ($1+$3)/2 )) $(( ($2+$4)/2 ))
    log dp "approved external display dialog ($b)"
  fi
}

# make sure adbd is actually running (last boot: adb enabled but adbd never started)
if [ "$(getprop init.svc.adbd)" != running ]; then
  log usb "adbd=$(getprop init.svc.adbd) -> starting"; setprop ctl.start adbd
fi

# ---- watch for the monitor: on plug-in wake the phone and push to the monitor ----
was=0; n=0
while true; do
  [ "$(getprop persist.vendor.usb.displayport.enabled)" = 1 ] || setprop persist.vendor.usb.displayport.enabled 1
  if dp_connected; then
    if [ $was = 0 ]; then
      input keyevent KEYCODE_WAKEUP
      wm dismiss-keyguard 2>/dev/null
      settings put system screen_brightness 1
      log dp "monitor connected"
      dumpsys display 2>/dev/null | grep -E "DisplayDeviceInfo|mDisplayId=" | head -6 >> "$LOG"
      was=1; t=0
    fi
    # approve/enable the new display during the first ~45 s after plug-in
    [ ${t:-99} -lt 15 ] && { accept_display; t=$((t+1)); }
    # keep the mirrored source awake while the monitor is in use
    [ "$(dumpsys power | grep -m1 mWakefulness= | cut -d= -f2)" = Awake ] || input keyevent KEYCODE_WAKEUP
  elif [ $was = 1 ]; then
    log dp "monitor disconnected"; was=0
  fi
  n=$((n+1)); [ $((n % 100)) = 0 ] && log hb "usb=$(getprop sys.usb.state) cfg=$(getprop sys.usb.config) adbd=$(getprop init.svc.adbd) adb=$(settings get global adb_enabled)"
  sleep 3
done
