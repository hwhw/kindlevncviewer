local ffi = require("ffi")
local bit = require("bit")
local BB = require("ffi/blitbuffer")

local dummy = require("ffi/linux_fb_h")
local dummy = require("ffi/posix_h")

local fb = {
	fd = -1,
	finfo = ffi.new("fb_fix_screeninfo"),
	vinfo = ffi.new("fb_var_screeninfo"),
	fb_size
}

function fb.open(device)
	fb.fd = ffi.C.open(device, O_RDWR)
	assert(fb.fd == 0, "cannot open framebuffer")

	-- Get fixed screen information
	assert(ffi.C.ioctl(fb.fd, ffi.C.FBIOGET_FSCREENINFO, fb.finfo) == 0,
		"cannot get screen info")

	assert(fb.finfo.type == ffi.C.FB_TYPE_PACKED_PIXELS,
		"video type not supported")

	if ffi.string(fb.finfo.id, 11) == "mxc_epdc_fb" then
		/* Kindle PaperWhite and KT with 5.1 or later firmware */
		einkUpdateFunc = &kindle51einkUpdate;
	elseif ffi.string(fb.finfo.id, 7) == "eink_fb" then
		if fb.vinfo.bits_per_pixel == 8 then
			/* kindle4 */
			einkUpdateFunc = &kindle4einkUpdate;
		else
			/* kindle2, 3, DXG */
			einkUpdateFunc = &kindle3einkUpdate;
		end
	else
		error("eink model not supported");
	end

	assert(ffi.C.ioctl(fb.fd, ffi.C.FBIOGET_VSCREENINFO, fb.vinfo) == 0,
		"cannot get variable screen info")

--[[
	if (fb->vinfo.bits_per_pixel == 16) {
		/* Only (known) platform using this is Kobo;
		 * since we can change the mode to 8bpp, at this time
		 * driving directly the screen at 16bpp is not supported.
		 * */
		fb->vinfo.bits_per_pixel = 8;
		fb->vinfo.grayscale = 1;
		fb->vinfo.rotate = 3; // 0 is landscape right handed, 3 is portrait
		if (ioctl(fb->fd, FBIOPUT_VSCREENINFO, &fb->vinfo)) {
			return luaL_error(L, "cannot change screen bpp");
		}
		/* at this point fb->finfo should be changed */
		if (ioctl(fb->fd, FBIOGET_FSCREENINFO, &fb->finfo)) {
			return luaL_error(L, "cannot get screen info");
		}
		if (fb->vinfo.bits_per_pixel == 16) {
			return luaL_error(L, "cannot change screen bpp");
		}
	}
--]]

	assert(fb.vinfo.grayscale ~= 0, "only grayscale is supported but framebuffer says it isn't")
	assert(fb.vinfo.xres > 0 and fb.vinfo.yres > 0,
		"invalid framebuffer resolution")

	/* mmap the framebuffer */
#ifndef KOBO_PLATFORM
	fb_map_address = mmap(0, fb->finfo.smem_len,
			PROT_READ | PROT_WRITE, MAP_SHARED, fb->fd, 0);
#else
	/* it seems that fb->finfo.smem_len is unreliable on kobo */
	// Figure out the size of the screen in bytes
	fb->fb_size = (fb->vinfo.xres_virtual * fb->vinfo.yres_virtual * fb->vinfo.bits_per_pixel / 8);
	fb_map_address = mmap(0, fb->fb_size,
       PROT_READ | PROT_WRITE, MAP_SHARED, fb->fd, 0);
#endif
	if(fb_map_address == MAP_FAILED) {
		return luaL_error(L, "cannot mmap framebuffer");
	}

	if (fb->vinfo.bits_per_pixel == 8) {
		/* for 8bpp K4, PaperWhite, we create a shadow 4bpp blitbuffer.
		 * These models use 16 scale 8bpp framebuffer, so they are
		 * actually fake 8bpp FB. Therefore, we still treat them as 4bpp
		 *
		 * For PaperWhite, the screen width is 758, but FB's line_length
		 * is 768. So when doing the screen update, you still need to
		 * fill 768 pixels per line, but the trailing 10 px for each
		 * line is actually ignored by driver.
		 * */
		fb->buf->pitch = fb->vinfo.xres / 2;

		fb->buf->data = (uint8_t *)calloc(fb->buf->pitch * fb->vinfo.yres, sizeof(uint8_t));
		if (!fb->buf->data) {
			return luaL_error(L, "failed to allocate memory for framebuffer's shadow blitbuffer!");
		}
		fb->buf->allocated = 1;

		/* now setup framebuffer map */
		fb->real_buf = (BlitBuffer *)malloc(sizeof(BlitBuffer));
		if (!fb->buf->data) {
			return luaL_error(L, "failed to allocate memory for framebuffer's blitbuffer!");
		}
		fb->real_buf->pitch = fb->finfo.line_length;
		fb->real_buf->w = fb->vinfo.xres;
		fb->real_buf->h = fb->vinfo.yres;
		fb->real_buf->allocated = 0;
		fb->real_buf->data = fb_map_address;
	} else {
		fb->buf->pitch = fb->finfo.line_length;
		/* for K2, K3 and DXG, we map framebuffer to fb->buf->data directly */
		fb->real_buf = NULL;
		fb->buf->data = fb_map_address;
		fb->buf->allocated = 0;
	}

	-- we present this buffer to the outside
	fb.bb = BB.new(SDL.screen.w, SDL.screen.h)
	return fb
end

function fb:getOrientation()
	local mode = ffi.new("int")
	ffi.C.ioctl(self.fd, ffi.C.FBIO_EINK_GET_DISPLAY_ORIENTATION, mode)

	-- adjust ioctl's rotate mode definition to KPV's
	-- refer to screen.lua
	if mode == 2 then
		return 1
	elseif mode == 1 then
		return 2
	end
	return mode
end

function fb:setOrientation(mode)
	mode = ffi.cast("int", mode or 0)
	if mode < 0 or mode > 3 then
		error("Wrong rotation mode given!")
	end

	--[[
         ioctl has a different definition for rotation mode.
	 	          1
	 	   +--------------+
	 	   | +----------+ |
	 	   | |          | |
	 	   | | Freedom! | |
	 	   | |          | |
	 	   | |          | |
	 	 3 | |          | | 2
	 	   | |          | |
	 	   | |          | |
	 	   | +----------+ |
	 	   |              |
	 	   |              |
	 	   +--------------+
	 	          0
	--]] 
	if mode == 1 then
		mode = 2
	elseif mode == 2 then
		mode = 1
	end

	ffi.C.ioctl(fb.fd, ffi.C.FBIO_EINK_SET_DISPLAY_ORIENTATION, mode)
end

function fb:refresh(refreshtype, x1, y1, w, h)
	if x1 == nil then x1 = 0 end
	if y1 == nil then y1 = 0 end
	if w == nil then w = SDL.screen.w - x1 end
	if h == nil then h = SDL.screen.h - y1 end
	
	if SDL.LockSurface(SDL.screen) < 0 then
		error("Locking screen surface")
	end
	local screendata = ffi.cast("uint32_t*", SDL.screen.pixels)
	local screenpitch = bit.rshift(SDL.screen.pitch, 2)
	local screenformat = SDL.screen.format
	for y = y1, y1+h-1 do
		for x = x1, x1+w-1 do
			local value = self.bb:getPixel(x, y)
			value = 255 - bit.bor(value, bit.lshift(value, 4))
			screendata[y*screenpitch + x] = SDL.MapRGB(screenformat, value, value, value)
		end
	end
	SDL.UnlockSurface(SDL.screen)
	SDL.Flip(SDL.screen)
end

function fb:getSize()
	return self.bb.w, self.bb.h
end

function fb:getPitch()
	return self.bb.pitch
end

function fb:close()
	-- for now, we do nothing when in emulator mode
end

return fb
