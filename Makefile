LUADIR=../lua-5.1.4
CFLAGS=`pkg-config --cflags libvncclient` -I$(LUADIR)/src
LDFLAGS=`pkg-config --libs libvncclient` -lm -ldl
PKG_CONFIG_PATH=/home/hw/x-tools/arm-unknown-linux-gnueabi/arm-unknown-linux-gnueabi/sys-root/usr/lib/pkgconfig/
CC=arm-unknown-linux-gnueabi-gcc

kindlevncviewer: kindlevncviewer.o
	$(CC) $(LDFLAGS) kindlevncviewer.o $(LUADIR)/src/liblua.a -o kindlevncviewer

kindlevncviewer.o: kindlevncviewer.c
