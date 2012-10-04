#!/bin/sh
cd $(dirname "$0")
LD_LIBRARY_PATH=.
export LD_LIBRARY_PATH

lipc-set-prop com.lab126.powerd preventScreenSaver 1
./kindlevncviewer -config config.lua "$@"
lipc-set-prop com.lab126.powerd preventScreenSaver 0

# send menu key twice to refresh display
echo "send 139" > /proc/keypad
echo "send 139" > /proc/keypad
