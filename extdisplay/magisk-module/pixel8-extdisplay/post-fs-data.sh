#!/system/bin/sh
MODDIR=${0%/*}
resetprop -n persist.vendor.usb.displayport.enabled 1
/system/bin/sh "$MODDIR/extdisplay.sh" &
