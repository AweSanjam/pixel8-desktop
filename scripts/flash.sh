#!/bin/bash
set -e
cd ~/Downloads/pixel8-lineage/a16
P=payload
until fastboot devices | grep -q fastboot; do sleep 2; done
echo "== in bootloader"; fastboot getvar battery-voltage 2>&1 | head -1; fastboot getvar current-slot 2>&1 | head -1
fastboot --set-active=a
fastboot flash boot_a $P/boot.img
fastboot flash dtbo_a $P/dtbo.img
fastboot flash vendor_kernel_boot_a $P/vendor_kernel_boot.img
fastboot flash vendor_boot_a vendor_boot_adb.img
fastboot flash init_boot_a ../magisk/init_boot_magisk_desktop.img
fastboot flash pvmfw_a $P/pvmfw.img
fastboot flash vbmeta_a $P/vbmeta.img
fastboot flash vbmeta_system_a $P/vbmeta_system.img
fastboot flash vbmeta_vendor_a $P/vbmeta_vendor.img
echo "== to fastbootd"; fastboot reboot fastboot
for i in $(seq 1 60); do fastboot getvar is-userspace 2>&1 | grep -q "is-userspace: yes" && break; sleep 3; done
fastboot getvar is-userspace 2>&1 | head -1
fastboot getvar snapshot-update-status 2>&1 | head -1 || true
fastboot snapshot-update cancel || true
for p in system system_ext product vendor vendor_dlkm system_dlkm; do fastboot flash $p $P/$p.img; done
echo "== wipe data"; fastboot -w || true
fastboot erase misc || echo "misc erase refused"
echo "== reboot recovery"; fastboot reboot recovery
echo DONE_FLASH
