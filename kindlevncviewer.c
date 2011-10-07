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
int running = 1;

int inputfds[] = {-1, -1, -1};
char* inputdevices[] = { "/dev/input/event0", "/dev/input/event1", "/dev/input/event2" };

char *password = NULL;
char *config = NULL;

lua_State *L = NULL;

#define DELAY_REFRESH_BY_USECS 150000 // 150 msec
#define FORCE_PARTIAL_REFRESH_FOR_X_256TH_PXUP 512
#define DO_FULL_UPDATES 0
#define FULL_REFRESH_FOR_X_256TH_PXUP 256
#define ENDLESS_RECONNECT 1

char* passwordCallback(rfbClient* client) {
	if(password == NULL) {
		running = -1;
		fprintf(stderr,"got request for password, but no password was given on command line.\n");
		return strdup("");
	}
	return strdup(password);
}

void rfb16ToFramebuffer4(rfbClient* client, int x, int y, int w, int h) {
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
	rfb16ToFramebuffer4(client, cx, cy, cw, ch);
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

/* adapted from libVNCclient, extended by input device file descriptors: */
int myWaitForMessage(rfbClient* client, unsigned int usecs)
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
	rfbClient* cl;
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
		fprintf(stderr, "Error: 4BPP is supported for now\n");
		return 1;
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
		}
	}

	if(config != NULL) {
		/* set up Lua state */
		L = lua_open();
		if(L) {
			luaL_openlibs(L);
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
		cl = rfbGetClient(5,3,2); // 16bpp
		cl->GetPassword = passwordCallback;
		cl->canHandleNewFBSize = FALSE;
		cl->GotFrameBufferUpdate = updateFromRFB;
		cl->listenPort = LISTEN_PORT_OFFSET;

		/* connect */
		if (!rfbInitClient(cl,&argc,argv)) {
			goto quit;
		}
		refresh_full_at = ((cl->width*cl->height) >> 8) * FULL_REFRESH_FOR_X_256TH_PXUP;
		refresh_partial_force_at = ((cl->width*cl->height) >> 8) * FORCE_PARTIAL_REFRESH_FOR_X_256TH_PXUP;

		while (running > 0) {
			int n;

			rx1 = 1 << 15;
			ry1 = 1 << 15;
			rx2 = 0;
			ry2 = 0;
#define LONGLOOP 5*60*1000*1000
			n = myWaitForMessage(cl,LONGLOOP);
			if (n<0) {
				fprintf(stderr,"error while waiting for RFB message.\n");
				if(ENDLESS_RECONNECT) goto reconnect;
				goto quit;
			}
			while(n > 0) {
				if(!HandleRFBServerMessage(cl)) {
					fprintf(stderr,"error while handling RFB message.\n");
					if(ENDLESS_RECONNECT) goto reconnect;
					goto quit;
				}
				n = myWaitForMessage(cl,DELAY_REFRESH_BY_USECS);
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
		rfbClientCleanup(cl);
	}
quit:
	closeInputDevices();
	close(fd);
	if(L) lua_close(L);

	return -running;
}

