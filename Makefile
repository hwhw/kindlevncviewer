FFI_CDECL=../koreader-misc/ffi-cdecl/ffi-cdecl gcc -Ilibvncserver/

LUADIR=../lua-5.1.4
CFLAGS=`pkg-config --cflags libvncclient` -I$(LUADIR)/src
LDFLAGS=`pkg-config --libs libvncclient` -lm -ldl
PKG_CONFIG_PATH=/home/hw/x-tools/arm-unknown-linux-gnueabi/arm-unknown-linux-gnueabi/sys-root/usr/lib/pkgconfig/
CC=arm-unknown-linux-gnueabi-gcc

cdecl: \
	ffi/posix_h.lua \
	ffi/linux_fb_h.lua \
	ffi/linux_input_h.lua \
	ffi/rfbclient_h.lua

ffi/%_h.lua: ffi-cdecl/%_decl.c
	$(FFI_CDECL) $< > $@

kindlevncviewer: kindlevncviewer.o
	$(CC) $(LDFLAGS) kindlevncviewer.o $(LUADIR)/src/liblua.a -o kindlevncviewer

kindlevncviewer.o: kindlevncviewer.c
