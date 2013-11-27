ARCH?=arm-none-linux-gnueabi
CC=$(ARCH)-gcc
# for luajit:
HOST_CC="gcc -m32"

FFI_CDECL=../koreader-misc/ffi-cdecl/ffi-cdecl $(CC) -Ilibvncserver/
#VERSION=$(shell git describe HEAD)
VERSION=$(shell date +'%Y-%m-%d_%H-%m')

DISTRIBUTE=ffi config.lua keys.lua rfbkeys.lua kindlevncviewer.lua \
	luajit-2.0/src/luajit \
	libvncserver/libvncclient/.libs/libvncclient.so.0

all: dist/kindlevncviewer-$(ARCH)-$(VERSION).zip

clean:
	make -C luajit-2.0 clean
	make -C libvncserver clean

luajit-2.0/src/luajit:
	make -C luajit-2.0 HOST_CC=$(HOST_CC) CROSS=$(ARCH)-

libvncserver/libvncclient/.libs/libvncclient.so.0:

cdecl: \
	ffi/posix_h.lua \
	ffi/linux_fb_h.lua \
	ffi/einkfb_h.lua \
	ffi/mxcfb_kindle_h.lua \
	ffi/mxcfb_kobo_h.lua \
	ffi/linux_input_h.lua \
	ffi/rfbclient_h.lua

ffi/%_h.lua: ffi-cdecl/%_decl.c
	$(FFI_CDECL) $< > $@

dist/kindlevncviewer-$(ARCH)-$(VERSION).zip: $(DISTRIBUTE) cdecl
	-rm $@
	-rm -rf dist/$(ARCH)
	mkdir -p dist/$(ARCH)/kindlevncviewer
	echo 'return "$(VERSION)"' > dist/$(ARCH)/kindlevncviewer/version.lua
	cp -rL $(DISTRIBUTE) dist/$(ARCH)/kindlevncviewer/
	cd dist/$(ARCH) && zip -r9 ../../$@ kindlevncviewer

