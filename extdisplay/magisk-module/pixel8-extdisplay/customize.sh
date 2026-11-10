SKIPUNZIP=0
[ -f /data/adb/extdisplay.conf ] || echo "MODE=mirror" > /data/adb/extdisplay.conf
set_perm_recursive $MODPATH 0 0 0755 0644
set_perm $MODPATH/extdisplay.sh 0 0 0755
ui_print "- Pixel 8 External Display installed (mode: mirror)"
