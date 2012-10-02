#!/bin/sh -xe

orientation=`ssh root@192.168.2.2 cat /sys/module/eink_fb_hal_broads/parameters/bs_orientation`
if [ $orientation == 1 ] ; then
	geometry=1200x824
else
	geometry=824x1200
fi

/usr/bin/Xvnc --SecurityTypes=None -geometry $geometry -depth 16 -dpi 160 -alwaysshared :1 &
sleep 1
DISPLAY=:1 xterm &
DISPLAY=:1 dwm &
vncviewer :1 &
x2vnc -west 127.0.0.1:1 &
ssh root@192.168.2.2 /mnt/us/kindlevncviewer/kvncviewer.sh 192.168.2.1:1

