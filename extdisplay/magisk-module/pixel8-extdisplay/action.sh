#!/system/bin/sh
# Magisk "Action" button: toggle mirror <-> desktop, then reboot to apply.
CONF=/data/adb/extdisplay.conf
MODE=mirror; [ -f $CONF ] && . $CONF
[ "$MODE" = desktop ] && MODE=mirror || MODE=desktop
echo "MODE=$MODE" > $CONF
echo "External display mode -> $MODE. Rebooting in 5 s..."
sleep 5; reboot
