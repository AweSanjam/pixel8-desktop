#!/bin/bash
# play_install.sh <adb-serial> <pkg>...  — open Play Store page and tap Install
S=$1; shift; A="$HOME/Android/Sdk/platform-tools/adb -s $S"
for P in "$@"; do
  if $A shell pm list packages | grep -qx "package:$P"; then echo "$P already installed"; continue; fi
  $A shell am start -a android.intent.action.VIEW -d "market://details?id=$P" -p com.android.vending >/dev/null 2>&1
  ok=0
  for i in $(seq 12); do
    sleep 2
    $A shell uiautomator dump /data/local/tmp/ps.xml >/dev/null 2>&1
    b=$($A shell cat /data/local/tmp/ps.xml | grep -oE '(text|content-desc)="Install"[^>]*bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | head -1 | grep -oE '\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]')
    if [ -n "$b" ]; then set -- $(echo "$b" | tr '[],' '   '); $A shell input tap $(( ($1+$3)/2 )) $(( ($2+$4)/2 )); ok=1; break; fi
  done
  [ $ok = 1 ] && echo "$P install tapped" || echo "$P NO install button"
  for i in $(seq 60); do $A shell pm list packages | grep -qx "package:$P" && { echo "$P installed"; break; }; sleep 3; done
done
