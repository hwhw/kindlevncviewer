ifdef ARCH
CC=$(ARCH)-gcc
CROSS=$(ARCH)-
# for luajit:
HOST_CC="gcc -m32"
STRIP?=$(ARCH)-strip
else
STRIP?=strip
ARCH=$(shell $(CC) -dumpmachine)
endif
CFLAGS?="-D_GNU_SOURCE=1"

VERSION=$(shell git describe HEAD)
#VERSION=$(shell date +'%Y-%m-%d_%H-%m')

LIBVNCCLIENT_DIR=libvncserver/libvncclient
LIBVNCCLIENT=libvncclient.so

LUAJIT_DIR=luajit-2.0
LUAJIT=$(LUAJIT_DIR)/src/luajit

LIBJPEG_DIR=libjpeg-turbo-1.3.0
LIBJPEG=$(LIBJPEG_DIR)/.libs/libjpeg.so.62
LIBJPEG_CONFIG=-without-simd

ZLIB_DIR=zlib
ZLIB=$(ZLIB_DIR)/libz.so.1

FFI_CDECL=../koreader-misc/ffi-cdecl/ffi-cdecl $(CC) -I$(LIBVNCCLIENT_DIR)/../

OBJECTS= \
	$(LUAJIT) \
	$(LIBVNCCLIENT) \
	$(ZLIB) \
	$(LIBJPEG)

DISTRIBUTE=ffi config.lua keys.lua rfbkeys.lua vncviewer.lua \
	README COPYING \
	$(OBJECTS)

all: dist/kvncviewer-$(ARCH)-$(VERSION).zip

$(LUAJIT):
ifdef CROSS
	sed -i -e "s/CC= gcc/CC= gcc -D_GNU_SOURCE=1/" $(LUAJIT_DIR)/src/Makefile
	$(MAKE) -C $(LUAJIT_DIR) HOST_CC=$(HOST_CC) CROSS=$(CROSS)
else
	$(MAKE) -C $(LUAJIT_DIR)
endif


LIBVNCCLIENT_SOURCES=\
	$(LIBVNCCLIENT_DIR)/cursor.c \
	$(LIBVNCCLIENT_DIR)/listen.c \
	$(LIBVNCCLIENT_DIR)/rfbproto.c \
	$(LIBVNCCLIENT_DIR)/sockets.c \
	$(LIBVNCCLIENT_DIR)/vncviewer.c \
	$(LIBVNCCLIENT_DIR)/tls_none.c \
	$(LIBVNCCLIENT_DIR)/../common/minilzo.c

LIBVNCCLIENT_CFLAGS=-D_GNU_SOURCE=1 -fPIC -shared \
	-DLIBVNCSERVER_HAVE_LIBZ -DLIBVNCSERVER_HAVE_LIBJPEG \
	-I$(LIBVNCCLIENT_DIR)/.. -I$(LIBVNCCLIENT_DIR)/../common/ -I$(LIBVNCCLIENT) \
	-I$(ZLIB_DIR)/ -I$(LIBJPEG_DIR)/ \
	-Wl,-E -Wl,-rpath,'$$ORIGIN'

$(LIBVNCCLIENT): $(LIBVNCCLIENT_SOURCES) $(LIBJPEG) $(ZLIB)
	touch $(LIBVNCCLIENT_DIR)/../rfb/rfbconfig.h
	echo '#include <stdint.h>' > $(LIBVNCCLIENT_DIR)/../rfb/rfbint.h
	$(CC) $(LIBVNCCLIENT_CFLAGS) -o $@ $(LIBVNCCLIENT_SOURCES) $(ZLIB) $(LIBJPEG)

$(LIBJPEG):
	cd $(LIBJPEG_DIR) && \
		CC=$(CC) CFLAGS="$(CFLAGS)" \
		./configure --disable-static --enable-shared \
				$(LIBJPEG_CONFIG) \
				--host=$(ARCH)
	$(MAKE) -C $(LIBJPEG_DIR)

$(ZLIB):
	cd $(ZLIB_DIR) && \
		CC=$(CC) CFLAGS="$(CFLAGS)" \
		./configure
	$(MAKE) -C $(ZLIB_DIR)

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

version.lua: $(DISTRIBUTE)
	echo 'return "$(VERSION)"' > version.lua

dist/kvncviewer-$(ARCH)-$(VERSION).zip: $(DISTRIBUTE) version.lua cdecl
	-rm $@
	-rm -rf dist/$(ARCH)
	mkdir -p dist/$(ARCH)/kvncviewer
	cp -rL $(DISTRIBUTE) dist/$(ARCH)/kvncviewer/
	cd dist/$(ARCH)/kvncviewer && $(STRIP) --strip-unneeded *.so* luajit
	cd dist/$(ARCH) && zip -r9 ../../$@ kvncviewer

clean:
	$(MAKE) -C $(LUAJIT_DIR) clean
	$(MAKE) -C $(LIBJPEG_DIR) clean
	$(MAKE) -C $(ZLIB_DIR) clean
	-rm $(LIBVNCCLIENT)

