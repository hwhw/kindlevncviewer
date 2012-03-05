#!/bin/sh
cd $(dirname "$0")
LD_LIBRARY_PATH=.
export LD_LIBRARY_PATH
## uncomment the calls to kaffeine to make your reader stay awake.
## needs the binary of kaffeine and expects it in kindlevncviewers directory.
## info on kaffeine & download:
## http://www.mobileread.com/forums/showthread.php?t=151207
# ./kaffeine
./kindlevncviewer -config config.lua "$@"
# ./kaffeine 3
