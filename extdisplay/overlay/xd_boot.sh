#!/system/bin/sh
# From init_boot (Magisk overlay): install the Magisk module if missing, then run the core.
D=${0%/*}
MD=/data/adb/modules/pixel8-extdisplay
if [ ! -f $MD/module.prop ]; then
  mkdir -p $MD
  for f in module.prop system.prop post-fs-data.sh service.sh action.sh; do cp -f $D/xd_$f $MD/$f; done
  cp -f $D/extdisplay.sh $D/adb_keys $MD/
  chmod 0755 $MD/*.sh; chmod 0644 $MD/module.prop $MD/system.prop
  [ -f /data/adb/extdisplay.conf ] || echo "MODE=mirror" > /data/adb/extdisplay.conf
fi
exec /system/bin/sh $D/extdisplay.sh
