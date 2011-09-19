#!/bin/sh
cd $(dirname "$0")
LD_LIBRARY_PATH=.
export LD_LIBRARY_PATH
exec ./kindlevncviewer "$@"
