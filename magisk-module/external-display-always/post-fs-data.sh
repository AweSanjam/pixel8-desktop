#!/system/bin/sh
resetprop -n persist.vendor.usb.displayport.enabled 1
resetprop -n persist.sys.usb.config mtp,adb
