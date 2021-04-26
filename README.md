## About

This is a VNC viewer for eReaders.
Copyright (c) 2013 Hans-Werner Hilse <hilse@web.de>

It works on the framebuffer, using the einkfb API from e-ink devices (einkfb.h) to do screen refreshes.
This is based on LibVNCClient, part of the [LibVNCServer project](https://libvnc.github.io/).


There is a discussion thread on MobileRead:
http://www.mobileread.com/forums/showthread.php?t=150434

Note that the current version is a major rewrite of the original version.
The current version is implemented in Lua, targeted at LuaJIT.


## Configuration

Input handling is configurable/customizable in "config.lua".

kVNCviewer supports many options that determine various settings. Run it without arguments to show a list of supported options. In addition, LibVNCClient parses options, which allows for additional configuration. Look into the [documentation of LibVNCClient](https://libvnc.github.io/doc/html/group__libvncclient__api.html#gabb2299d1644f3cf38544eb97d2356475) to see the options it accepts.


## Building

In order to build kVNCViewer, you can use GNU make. A Kindle (and other eReaders)-specific toolchain can be found at [@koreader/koxtoolchain](https://github.com/koreader/koxtoolchain). Specify a toolchain prefix as the "ARCH" variable, and it should build luajit, zlib, libjpeg and finally libvncclient. E.g., for legacy Kindles:

```
make ARCH=arm-kindle-linux-gnueabi
```

You can find the result in the "dist/<ARCH>" subdirectory. Also, a .zip file is created for distribution.


## Running

You need to copy the program and the libraries it needs onto your eReader (you can try running it without and it will show you which libraries are missing). Then, from a launcher app or shell, call:

```
./luajit vncviewer.lua 192.168.1.1:5900
```

You will need to enter the correct server address or name and screen number.


## Licensing/Copying

This software is licensed under the GPLv2 (see file COPYING).
