#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <errno.h>
#include <stdio.h>
#include <stropts.h>
#include <sys/select.h>
#include <rfb/rfbclient.h>

#include <linux/fb.h>
#include <linux/einkfb.h>
#include <linux/input.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

int fd = -1;
void *fbdata = NULL;
struct fb_fix_screeninfo finfo;
struct fb_var_screeninfo vinfo;
int rx1, rx2, ry1, ry2; // refresh rectangle
int refresh_pending = 0;
int refresh_full_counter = 0;
int refresh_partial_counter = 0;
int dithered = 0;
int framebuffer_bpp = 4;
int running = 1;

int inputfds[] = {-1, -1, -1};
char* inputdevices[] = { "/dev/input/event0", "/dev/input/event1", "/dev/input/event2" };

char *password = NULL;
char *config = NULL;

unsigned char *matrix;

lua_State *L = NULL;
rfbClient* client;

#define DELAY_REFRESH_BY_USECS 150000 // 150 msec
#define FORCE_PARTIAL_REFRESH_FOR_X_256TH_PXUP 512
#define DO_FULL_UPDATES 0
#define FULL_REFRESH_FOR_X_256TH_PXUP 256
#define ENDLESS_RECONNECT 1

char* passwordCallback() {
	if(password == NULL) {
		running = -1;
		fprintf(stderr,"got request for password, but no password was given on command line.\n");
		return strdup("");
	}
	return strdup(password);
}

/* Default mono halftone, lifted from Ghostscript. */
static unsigned char mono_ht[] =
{
	0x0E, 0x8E, 0x2E, 0xAE, 0x06, 0x86, 0x26, 0xA6, 0x0C, 0x8C, 0x2C, 0xAC, 0x04, 0x84, 0x24, 0xA4,
	0xCE, 0x4E, 0xEE, 0x6E, 0xC6, 0x46, 0xE6, 0x66, 0xCC, 0x4C, 0xEC, 0x6C, 0xC4, 0x44, 0xE4, 0x64,
	0x3E, 0xBE, 0x1E, 0x9E, 0x36, 0xB6, 0x16, 0x96, 0x3C, 0xBC, 0x1C, 0x9C, 0x34, 0xB4, 0x14, 0x94,
	0xFE, 0x7E, 0xDE, 0x5E, 0xF6, 0x76, 0xD6, 0x56, 0xFC, 0x7C, 0xDC, 0x5C, 0xF4, 0x74, 0xD4, 0x54,
	0x01, 0x81, 0x21, 0xA1, 0x09, 0x89, 0x29, 0xA9, 0x03, 0x83, 0x23, 0xA3, 0x0B, 0x8B, 0x2B, 0xAB,
	0xC1, 0x41, 0xE1, 0x61, 0xC9, 0x49, 0xE9, 0x69, 0xC3, 0x43, 0xE3, 0x63, 0xCB, 0x4B, 0xEB, 0x6B,
	0x31, 0xB1, 0x11, 0x91, 0x39, 0xB9, 0x19, 0x99, 0x33, 0xB3, 0x13, 0x93, 0x3B, 0xBB, 0x1B, 0x9B,
	0xF1, 0x71, 0xD1, 0x51, 0xF9, 0x79, 0xD9, 0x59, 0xF3, 0x73, 0xD3, 0x53, 0xFB, 0x7B, 0xDB, 0x5B,
	0x0D, 0x8D, 0x2D, 0xAD, 0x05, 0x85, 0x25, 0xA5, 0x0F, 0x8F, 0x2F, 0xAF, 0x07, 0x87, 0x27, 0xA7,
	0xCD, 0x4D, 0xED, 0x6D, 0xC5, 0x45, 0xE5, 0x65, 0xCF, 0x4F, 0xEF, 0x6F, 0xC7, 0x47, 0xE7, 0x67,
	0x3D, 0xBD, 0x1D, 0x9D, 0x35, 0xB5, 0x15, 0x95, 0x3F, 0xBF, 0x1F, 0x9F, 0x37, 0xB7, 0x17, 0x97,
	0xFD, 0x7D, 0xDD, 0x5D, 0xF5, 0x75, 0xD5, 0x55, 0xFF, 0x7F, 0xDF, 0x5F, 0xF7, 0x77, 0xD7, 0x57,
	0x02, 0x82, 0x22, 0xA2, 0x0A, 0x8A, 0x2A, 0xAA, 0x00, 0x80, 0x20, 0xA0, 0x08, 0x88, 0x28, 0xA8,
	0xC2, 0x42, 0xE2, 0x62, 0xCA, 0x4A, 0xEA, 0x6A, 0xC0, 0x40, 0xE0, 0x60, 0xC8, 0x48, 0xE8, 0x68,
	0x32, 0xB2, 0x12, 0x92, 0x3A, 0xBA, 0x1A, 0x9A, 0x30, 0xB0, 0x10, 0x90, 0x38, 0xB8, 0x18, 0x98,
	0xF2, 0x72, 0xD2, 0x52, 0xFA, 0x7A, 0xDA, 0x5A, 0xF0, 0x70, 0xD0, 0x50, 0xF8, 0x78, 0xD8, 0x58
};

inline unsigned char htValue(int x, int y) {
	return mono_ht[16*(y % 16) + (x % 16)];
}

void mkMatrix(int width, int height) {
	int y, x;
	unsigned char *mp;
	matrix = malloc(width * height);
	if(!matrix) {
		fprintf(stderr, "cannot create matrix\n");
		exit(1);
	}
	mp = matrix;
	for(y=0; y<height; y++) {
		for(x=0; x < width; x++) {
			*mp = htValue(x, y);
			mp++;
		}
	}
}

void rfb16ToHalftonedFramebuffer4(int x, int y, int w, int h) {
	int cx, cy;
	int len = w + (x & 1);
	uint8_t dval;

	x = x & (-2);

	/* we read single pixels */
	uint16_t *src = (uint16_t*)(client->frameBuffer) + client->width*y + x;
	/* but we write two pixels at once */
	uint8_t *dest = (uint8_t*)fbdata + finfo.line_length*y + (x >> 1);

	uint8_t *mp = matrix + y*vinfo.xres + x;

	for(cy = y; cy < y+h; cy++) {
		/*fprintf(stderr, "%p, %p\n", src, dest);*/
		for(cx = x; cx < x+len; cx++) {
			uint32_t c;
			uint16_t v;

			v = *src++;
#ifdef PERFECT_COLOR_CONVERSION
			c = ((v & 0x001F) * 77 // red
				+ ((v & 0x03E0) >> 5) * 151 // green
				+ ((v & 0x7C00) >> 10) * 28 // blue
			    ) >> 5;
#else
			c = ((v & 0x001F) // red
				+ (((v & 0x03E0) >> 5) << 1) // green counts 2x
				+ ((v & 0x7C00) >> 10) // blue
			    ) << 1;
#endif

			if(cx & 1) {
				dval = dval << 4;
			} else {
				dval = 0;
			}
			if(c < *mp++) {
				dval |= 0x0F;
			}
			if(cx & 1) {
				*dest++ = dval;
			}
		}
		dest += (finfo.line_length - (len >> 1));
		src += (client->width - len);
		mp += (vinfo.xres - len);
	}
}

void rfb16ToFramebuffer8(int x, int y, int w, int h) {
	int cx, cy;

	/* we read single pixels */
	uint16_t *src = (uint16_t*)(client->frameBuffer) + client->width*y + x;
	/* and we write single pixels */
	uint8_t *dest = (uint8_t*)fbdata + finfo.line_length*y + x;

	for(cy = 0; cy < h; cy++) {
		for(cx = 0; cx < w; cx++) {
			uint32_t c;
			uint16_t v;
			uint8_t dval;

			v = *(src + cx);
#ifdef PERFECT_COLOR_CONVERSION
			c = ((v & 0x001F) * 77 // red
				+ ((v & 0x03E0) >> 5) * 151 // green
				+ ((v & 0x7C00) >> 10) * 28 // blue
			    ) >> (8 /* from multipl. above */ + 1 /* 5 -> 4 */ );
#else
			c = ((v & 0x001F) // red
				+ (((v & 0x03E0) >> 5) << 1) // green counts 2x
				+ ((v & 0x7C00) >> 10) // blue
			    ) >> (2 /* from shifts above */ + 1 /* 5 -> 4 */ );
#endif
			*(dest+cx) = ((uint8_t)c << 4) + ((uint8_t)c & 0xF); /* repeat value in lower nibble */
		}
		dest += finfo.line_length;
		src += client->width;
	}
}

void rfb16ToFramebuffer4(int x, int y, int w, int h) {
	int cx, cy;
	int len = (w + (x & 1)) >> 1;

	/* we read single pixels */
	uint16_t *src = (uint16_t*)(client->frameBuffer) + client->width*y + (x & (-2)); /* is this portable?!? */
	/* but we write two pixels at once */
	uint8_t *dest = (uint8_t*)fbdata + finfo.line_length*y + (x >> 1);

	for(cy = 0; cy < h; cy++) {
		/*fprintf(stderr, "%p, %p\n", src, dest);*/
		for(cx = 0; cx < len; cx++) {
			uint32_t c;
			uint16_t v;
			uint8_t dval;

			v = *(src + cx*2);
#ifdef PERFECT_COLOR_CONVERSION
			c = ((v & 0x001F) * 77 // red
				+ ((v & 0x03E0) >> 5) * 151 // green
				+ ((v & 0x7C00) >> 10) * 28 // blue
			    ) >> (8 /* from multipl. above */ + 1 /* 5 -> 4 */ );
#else
			c = ((v & 0x001F) // red
				+ (((v & 0x03E0) >> 5) << 1) // green counts 2x
				+ ((v & 0x7C00) >> 10) // blue
			    ) >> (2 /* from shifts above */ + 1 /* 5 -> 4 */ );
#endif
			dval = (uint8_t)c << 4;

			v = *(src + cx*2 + 1);
#ifdef PERFECT_COLOR_CONVERSION
			c = ((v & 0x001F) * 77 // red
				+ ((v & 0x03E0) >> 5) * 151 // green
				+ ((v & 0x7C00) >> 10) * 28 // blue
			    ) >> (8 /* from multipl/adds above */ + 1 /* 5 -> 4 */ );
#else
			c = ((v & 0x001F) // red
				+ (((v & 0x03E0) >> 5) << 1) // green counts 2x
				+ ((v & 0x7C00) >> 10) // blue
			    ) >> (2 /* from shifts/adds above */ + 1 /* 5 -> 4 */ );
#endif
			dval |= (uint8_t)c;
			dval ^= 255; /* kindle is inverse */

			*(dest+cx) = dval;
		}
		dest += finfo.line_length;
		src += client->width*2 >> 1;
	}
}

void einkUpdate(fx_type which_fx) {
	// for Kindle e-ink display
	update_area_t myarea;

	if(fd == -1)
		return;

	if(which_fx == fx_update_full) {
		fprintf(stderr,"full update of eink display\n");
		ioctl(fd, FBIO_EINK_UPDATE_DISPLAY, fx_update_full);
		refresh_full_counter = 0;
		refresh_partial_counter = 0;
	} else {
		fprintf(stderr,"partially updating eink display (%d,%d)-(%d,%d)\n",rx1,ry1,rx2,ry2);
		myarea.x1 = rx1;
		myarea.x2 = rx2;
		myarea.y1 = ry1;
		myarea.y2 = ry2;
		myarea.buffer = NULL;
		myarea.which_fx = fx_update_partial;

		ioctl(fd, FBIO_EINK_UPDATE_DISPLAY_AREA, &myarea);
		refresh_partial_counter = 0;
	}
	refresh_pending = 0;
}

void updateFromRFB(rfbClient* client, int x, int y, int w, int h) {
	/*fprintf(stderr,"Received an update for %d,%d,%d,%d.\n",x,y,w,h);*/
	int cx = (x > vinfo.xres) ? vinfo.xres - 1 : x;
	int cy = (y > vinfo.yres) ? vinfo.yres - 1 : y;
	int cw = (x+w > vinfo.xres) ? vinfo.xres - (x+1) : w;
	int ch = (y+h > vinfo.yres) ? vinfo.yres - (y+1) : h;
	if(!dithered) {
		if(framebuffer_bpp==4) {
			rfb16ToFramebuffer4(cx, cy, cw, ch);
		} else {
			rfb16ToFramebuffer8(cx, cy, cw, ch);
		}
	} else {
		rfb16ToHalftonedFramebuffer4(cx, cy, cw, ch);
	}
	if(rx1 > cx) rx1 = cx;
	if(rx2 < cx+cw-1) rx2 = cx+cw-1;
	if(ry1 > cy) ry1 = cy;
	if(ry2 < cy+ch-1) ry2 = cy+ch-1;
	refresh_pending = 1;
	refresh_full_counter += cw*ch;
	refresh_partial_counter += cw*ch;
}

void handleInput(int chan, int fd) {
	struct input_event input;
	int n;
	rfbClientLog("event on fd #%d\n", fd);
	n = read(fd, &input, sizeof(struct input_event));
	if(n < sizeof(struct input_event))
		return;

	lua_getglobal(L, "handleInput");
	if(lua_isfunction(L, -1)) {
		lua_pushinteger(L, chan);
		lua_pushinteger(L, (int) input.type);
		lua_pushinteger(L, (int) input.code);
		lua_pushinteger(L, (int) input.value);
		if(lua_pcall(L, 4, 0, 0)) {
			rfbClientLog("lua error: %s\n", lua_tostring(L, -1));
		}
	}
}

int luaSendKeyEvent(lua_State *L) {
	int key = luaL_checkint(L, 1);
	int pressed = lua_toboolean(L, 2);

	SendKeyEvent(client, (uint32_t) key, pressed);

	return 0;
}

int luaSendPointerEvent(lua_State *L) {
	int x = luaL_checkint(L, 1);
	int y = luaL_checkint(L, 2);
	int buttonMask = luaL_checkint(L, 3);

	SendPointerEvent(client, x, y, buttonMask);

	return 0;
}

int luaQuit(lua_State *L) {
	running = 0 - luaL_optint(L, 1, 0);
	return 0;
}

/* adapted from libVNCclient, extended by input device file descriptors: */
int myWaitForMessage(unsigned int usecs)
{
	fd_set fds;
	struct timeval timeout;
	int i, num, nfds;

	if(client->serverPort == -1)
		/* playing back vncrec file */
		return 1;

	timeout.tv_sec = (usecs/1000000);
	timeout.tv_usec = (usecs%1000000);

	nfds = client->sock + 1;

	FD_ZERO(&fds);
	FD_SET(client->sock, &fds);
	if(L) {
		for(i=0; i<3; i++) {
			if(inputfds[i] != -1)
				FD_SET(inputfds[i], &fds);
			if(inputfds[i] + 1 > nfds)
				nfds = inputfds[i] + 1;
		}
	}

	num = select(nfds, &fds, NULL, NULL, &timeout);
	if(num < 0) {
		rfbClientLog("Waiting for message failed: %d (%s)\n", errno, strerror(errno));
		return num;
	}

	if(L) {
		for(i=0; i<3; i++) {
			if(inputfds[i] != -1 && FD_ISSET(inputfds[i], &fds)) {
				handleInput(i, inputfds[i]);
			}
		}
	}

	if(FD_ISSET(client->sock, &fds)) {
		return num;
	}

	return 0;
}

void openInputDevices() {
	int i;
	for(i=0; i<3; i++) {
		inputfds[i] = open(inputdevices[i], O_RDONLY | O_NONBLOCK, 0);
		if(inputfds[i] != -1)
			ioctl(inputfds[i], EVIOCGRAB, 1);
	}
}

void closeInputDevices() {
	int i;
	for(i=0; i<3; i++) {
		if(inputfds[i] != -1) {
			ioctl(inputfds[i], EVIOCGRAB, 0);
			close(i);
		}
	}
}

int main(int argc, char **argv) {
	int refresh_partial_force_at;
	int refresh_full_at;
	int i;

	/* open framebuffer */
	fd = open("/dev/fb0", O_RDWR);
	if (fd == -1) {
		perror("framebuffer");
		return 1;
	}

	/* initialize data structures */
	memset(&finfo, 0, sizeof(finfo));
	memset(&vinfo, 0, sizeof(vinfo));

	/* Get fixed screen information */
	if (ioctl(fd, FBIOGET_FSCREENINFO, &finfo)) {
		perror("Error: get screen info");
		return 1;
	}

	if (finfo.type != FB_TYPE_PACKED_PIXELS) {
		fprintf(stderr, "Error: video type not supported\n");
		return 1;
	}

	if (ioctl(fd, FBIOGET_VSCREENINFO, &vinfo)) {
		perror("Error: get variable screen info");
		return 1;
	}

	if (!vinfo.grayscale) {
		fprintf(stderr, "Error: only grayscale is supported\n");
		return 1;
	}

	if (vinfo.bits_per_pixel != 4) {
		if (vinfo.bits_per_pixel != 8) {
			fprintf(stderr, "Error: 4BPP or 8BPP is supported for now\n");
			return 1;
		}
		framebuffer_bpp = 8;
	} else {
		framebuffer_bpp = 4;
	}

	if (vinfo.xres <= 0 || vinfo.yres <= 0) {
		fprintf(stderr, "Error: checking resolution, cannot use %dx%d.\n", vinfo.xres, vinfo.yres);
	}

	/* mmap the framebuffer */
	fbdata = mmap(0, finfo.smem_len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if(fbdata == MAP_FAILED) {
		perror("mmap framebuffer");
		return 1;
	}
	memset(fbdata, 0, finfo.line_length*vinfo.yres);

	/* option parsing, but note that libvncclient does its own parsing, too */
	for(i=1; i < argc; i++) {
		if(strcmp("-password", argv[i]) == 0 && (i+1) < argc) {
			/* password given on command line */
			password = strdup(argv[i+1]);
			i++;
		} else if(strcmp("-readpassword", argv[i]) == 0) {
			char pwdstring[256];
			/* read password from stdin */
			password = fgets(pwdstring, sizeof(pwdstring), stdin);
			if(password == NULL) {
				fprintf(stderr, "error when reading password from stdin.\n");
				running = -1;
			} else {
				if(password[strlen(password)-1] == '\n')
					password[strlen(password)-1] = '\0';
				if(strlen(password) == 0) {
					fprintf(stderr, "got zero-length password from stdin.\n");
					running = -1;
				} else {
					password = strdup(pwdstring);
				}
			}
		} else if(strcmp("-config", argv[i]) == 0 && (i+1) < argc) {
			/* config file */
			config = strdup(argv[i+1]);
			i++;
		} else if(strcmp("-dithered", argv[i]) == 0) {
			if(framebuffer_bpp == 4) {
				mkMatrix(vinfo.xres, vinfo.yres);
				dithered = 1;
			} else {
				fprintf(stderr, "dithering is only supported for 4bpp displays for now, sorry.\n");
			}
		}
	}

	if(config != NULL) {
		/* set up Lua state */
		L = lua_open();
		if(L) {
			luaL_openlibs(L);
			lua_pushcfunction(L, luaSendKeyEvent);
			lua_setglobal(L, "SendKeyEvent");
			lua_pushcfunction(L, luaSendPointerEvent);
			lua_setglobal(L, "SendPointerEvent");
			lua_pushcfunction(L, luaQuit);
			lua_setglobal(L, "Quit");
			if(luaL_dofile(L, config)) {
				fprintf(stderr, "lua config error: %s", lua_tostring(L, -1));
				lua_close(L);
				L=NULL;
			}
		}
	}


	openInputDevices();

	while(running > 0) {
		/* initialize rfbClient */
		client = rfbGetClient(5,3,2); // 16bpp
		client->GetPassword = passwordCallback;
		client->canHandleNewFBSize = FALSE;
		client->GotFrameBufferUpdate = updateFromRFB;
		client->listenPort = LISTEN_PORT_OFFSET;

		/* connect */
		if (!rfbInitClient(client,&argc,argv)) {
			goto quit;
		}
		refresh_full_at = ((client->width*client->height) >> 8) * FULL_REFRESH_FOR_X_256TH_PXUP;
		refresh_partial_force_at = ((client->width*client->height) >> 8) * FORCE_PARTIAL_REFRESH_FOR_X_256TH_PXUP;

		if(L) {
			lua_pushinteger(L, client->width);
			lua_setglobal(L, "client_width");
			lua_pushinteger(L, client->height);
			lua_setglobal(L, "client_height");
		}

		while (running > 0) {
			int n;

			rx1 = 1 << 15;
			ry1 = 1 << 15;
			rx2 = 0;
			ry2 = 0;
#define LONGLOOP 5*60*1000*1000
			n = myWaitForMessage(LONGLOOP);
			if (n<0) {
				fprintf(stderr,"error while waiting for RFB message.\n");
				if(ENDLESS_RECONNECT) goto reconnect;
				goto quit;
			}
			while(n > 0) {
				if(!HandleRFBServerMessage(client)) {
					fprintf(stderr,"error while handling RFB message.\n");
					if(ENDLESS_RECONNECT) goto reconnect;
					goto quit;
				}
				n = myWaitForMessage(DELAY_REFRESH_BY_USECS);
				if (n<0) {
					fprintf(stderr,"error while waiting for RFB message.\n");
					if(ENDLESS_RECONNECT) goto reconnect;
					goto quit;
				}
				if(refresh_partial_counter >= refresh_partial_force_at) {
					break;
				}
			}
			if(refresh_pending) {
				if(DO_FULL_UPDATES && (refresh_full_counter >= refresh_full_at)) {
					einkUpdate(fx_update_full);
				} else {
					einkUpdate(fx_update_partial);
				}
			}
		}
reconnect:
		rfbClientCleanup(client);
	}
quit:
	closeInputDevices();
	close(fd);
	if(L) lua_close(L);

	return -running;
}

