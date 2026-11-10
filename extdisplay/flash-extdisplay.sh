#!/bin/bash
# flash-extdisplay.sh — one-shot: plug the Pixel in (fastboot or recovery) and walk away.
# 1) recovery: save last-boot logs  2) bootloader: vbmeta (verity off) + Magisk init_boot w/ overlay
# 3) fastbootd: hard-coded system_ext  4) wipe data (fresh setup on the monitor)  5) boot + verify
A=${ADB:-adb}; SN=${PIXEL_SERIAL:?set PIXEL_SERIAL to your phone serial (fastboot devices)}
X=~/pixel8-desktop/extdisplay; P=~/Downloads/pixel8-lineage/a16/payload
L=~/pixel8-desktop/logs/$(date +%m%d-%H%M); mkdir -p $L
fb() { fastboot -s $SN "$@"; }
in_fb() { fastboot devices | grep -q $SN; }
in_dev() { $A devices | grep -qE "^$SN.*device$"; }
in_rec() { $A devices | grep -qE "^$SN.*recovery$"; }
wait_for() { for i in $(seq $2); do $1 && return 0; sleep 2; done; return 1; }
echo "== waiting for phone $(date +%T)"
until in_fb || in_rec || $A devices | grep -qE "^$SN.*device$"; do sleep 2; done
echo "== seen $(date +%T)"
# --- 1. logs from the last Android boot (needs our vendor_boot with the PC key) ---
if in_fb; then sleep 3; fb reboot recovery; fi
if $A devices | grep -qE "^$SN.*device$"; then $A -s $SN reboot recovery; fi
if wait_for in_rec 90; then
  $A -s $SN shell 'mount | grep -q " /data " || mount /data' >/dev/null 2>&1
  for d in /sys/fs/pstore /data/local/tmp /data/tombstones /data/system/dropbox /data/misc/logd /data/anr; do
    $A -s $SN pull $d $L/ >/dev/null 2>&1 && echo "pulled $d"
  done
  $A -s $SN shell 'dmesg' > $L/recovery_dmesg.txt 2>&1
  $A -s $SN reboot bootloader
else
  echo "!! recovery adb not reachable, skipping log pull"
fi
wait_for in_fb 90 || { echo "!! no fastboot"; exit 1; }
sleep 2
# make sure we are in the bootloader, not fastbootd
fb getvar is-userspace 2>&1 | grep -q "yes" && { fb reboot bootloader; sleep 5; wait_for in_fb 60; }
SLOT=$(fb getvar current-slot 2>&1 | awk '/current-slot/{print $2}'); SLOT=${SLOT:-a}
echo "== bootloader, slot $SLOT, $(fb getvar battery-voltage 2>&1 | head -1)"
# --- 2. verity off (modified system_ext/product otherwise fail dm-verity) + Magisk overlay ---
fb --disable-verity --disable-verification flash vbmeta_$SLOT $P/vbmeta.img
fb flash init_boot_$SLOT $X/init_boot_extdisplay.img
# --- 3. hard-coded system_ext in fastbootd ---
fb reboot fastboot
for i in $(seq 60); do fb getvar is-userspace 2>&1 | grep -q "is-userspace: yes" && break; sleep 3; done
fb flash system_ext $P/system_ext_v3.img
# --- 4. fresh data (needed after changing verity flags) + clear any sideload BCB ---
fb -w
fb erase misc 2>/dev/null
fb reboot
echo "== rebooted $(date +%T); first boot takes ~3-5 min"
# --- 5. verify ---
if wait_for in_dev 200; then
  echo "== ADB UP $(date +%T)"
  $A -s $SN wait-for-device shell 'while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 2; done'
  sleep 20
  $A -s $SN shell 'cat /data/local/tmp/extdisplay.log; echo; getprop persist.vendor.usb.displayport.enabled; getprop sys.usb.config; ls /data/adb/modules; dumpsys display | grep -E "DisplayDeviceInfo" | head' 2>&1 | tee $L/after_flash.txt
else
  echo "!! adb did not come up within ~7 min"
fi
echo "logs: $L"; echo FLASH_EXTDISPLAY_DONE
