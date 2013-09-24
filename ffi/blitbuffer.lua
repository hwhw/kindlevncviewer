--[[
Generic blitbuffer/GFX stuff that works on memory buffers
--]]

local ffi = require("ffi")

-- we will use this extensively
local floor = math.floor
local rshift = bit.rshift
local lshift = bit.lshift
local band = bit.band
local bor = bit.bor
local bxor = bit.bxor

ffi.cdef[[
typedef struct BlitBuffer4 {
        int w; 
        int h; 
        int pitch;
        uint8_t *data;
        uint8_t allocated;
} BlitBuffer4;
typedef struct BlitBuffer8 {
        int w; 
        int h; 
        int pitch;
        uint8_t *data;
        uint8_t allocated;
} BlitBuffer8;
typedef struct BlitBuffer16 {
        int w; 
        int h; 
        int pitch;
        uint8_t *data;
        uint8_t allocated;
} BlitBuffer16;
typedef struct BlitBufferRGB16 {
        int w; 
        int h; 
        int pitch;
        uint8_t *data;
        uint8_t allocated;
} BlitBufferRGB16;
typedef struct BlitBufferRGB24 {
        int w; 
        int h; 
        int pitch;
        uint8_t *data;
        uint8_t allocated;
} BlitBufferRGB24;
typedef struct BlitBufferRGB32 {
        int w; 
        int h; 
        int pitch;
        uint8_t *data;
        uint8_t allocated;
} BlitBufferRGB32;

typedef struct Color4L {
	uint8_t a;
} Color4L;
typedef struct Color4U {
	uint8_t a;
} Color4U;
typedef union Color8 {
	uint8_t a;
} Color8;
typedef struct Color16 {
	uint16_t a;
} Color16;
typedef struct ColorRGB16 {
	uint16_t v;
} ColorRGB16;
typedef struct ColorRGB24 {
	uint8_t r;
	uint8_t g;
	uint8_t b;
} ColorRGB24;
typedef struct ColorRGB32 {
	uint8_t r;
	uint8_t g;
	uint8_t b;
	uint8_t a;
} ColorRGB32;

void *malloc(int size);
void free(void *ptr);
void *memset(void *s, int c, int n);
]]

local BB = {}

-- this is only needed for casting userdata from the Lua/C API:
local BBtype = ffi.typeof("BlitBuffer4*")

local Color4U = ffi.typeof("Color4U")
local Color4L = ffi.typeof("Color4L")
local Color8 = ffi.typeof("Color8")
local Color16 = ffi.typeof("Color16")
local ColorRGB16 = ffi.typeof("ColorRGB16")
local ColorRGB24 = ffi.typeof("ColorRGB24")
local ColorRGB32 = ffi.typeof("ColorRGB32")
local P_Color4U = ffi.typeof("Color4U*")
local P_Color4L = ffi.typeof("Color4L*")
local P_Color8 = ffi.typeof("Color8*")
local P_Color16 = ffi.typeof("Color16*")
local P_ColorRGB16 = ffi.typeof("ColorRGB16*")
local P_ColorRGB24 = ffi.typeof("ColorRGB24*")
local P_ColorRGB32 = ffi.typeof("ColorRGB32*")

-- metatables for BlitBuffer objects:
local BB4_mt = {__index={}}
local BB8_mt = {__index={}}
local BB16_mt = {__index={}}
local BBRGB16_mt = {__index={}}
local BBRGB24_mt = {__index={}}
local BBRGB32_mt = {__index={}}
-- this is like a metatable for the others,
-- but we don't make it a metatable because LuaJIT
-- doesn't cope well with ctype metatables with
-- metatables on them
-- we just replicate what's in the following table
-- when we set the other metatables for their types
local BB_mt = {__index={}}

-- metatables for color types:
local Color4L_mt = {__index={}}
local Color4U_mt = {__index={}}
local Color8_mt = {__index={}}
local Color16_mt = {__index={}}
local ColorRGB16_mt = {__index={}}
local ColorRGB24_mt = {__index={}}
local ColorRGB32_mt = {__index={}}

-- getPixel routines
function BB4_mt.__index:getPixel(x, y)
	local p = self.data + self.pitch*y + rshift(x, 1)
	if band(x, 1) == 0 then 
		return ffi.cast(P_Color4U, p)
	else
		return ffi.cast(P_Color4L, p)
	end
end
function BB8_mt.__index:getPixel(x, y) return ffi.cast(P_Color8, self.data + self.pitch*y + x) end
function BB16_mt.__index:getPixel(x, y) return ffi.cast(P_Color16, self.data + self.pitch*y + lshift(x,1)) end
function BBRGB16_mt.__index:getPixel(x, y) return ffi.cast(P_ColorRGB16, self.data + self.pitch*y + lshift(x,1)) end
function BBRGB24_mt.__index:getPixel(x, y) return ffi.cast(P_ColorRGB24, self.data + self.pitch*y + x*3) end
function BBRGB32_mt.__index:getPixel(x, y) return ffi.cast(P_ColorRGB32, self.data + self.pitch*y + lshift(x,2)) end

-- color conversions:
-- to Color4L:
function Color4L_mt.__index:getColor4L() return Color4L(band(self.a, 0x0F)) end
function Color4U_mt.__index:getColor4L() return Color4L(rshift(self.a, 4)) end
function Color8_mt.__index:getColor4L() return Color4L(rshift(self.a, 4)) end
function Color16_mt.__index:getColor4L() return Color4L(rshift(self.a, 12)) end
function ColorRGB16_mt.__index:getColor4L()
	return Color4L(rshift(self:getR() + lshift(self:getG(), 1) + self:getB(), 6))
end
ColorRGB24_mt.__index.getColor4L = ColorRGB16_mt.__index.getColor4L
ColorRGB32_mt.__index.getColor4L = ColorRGB16_mt.__index.getColor4L

-- to Color4U:
function Color4L_mt.__index:getColor4U() return Color4U(lshift(self.a, 4)) end
function Color4U_mt.__index:getColor4U() return Color4U(band(self.a, 0xF0)) end
function Color8_mt.__index:getColor4U() return Color4U(band(self.a, 0xF0)) end
function Color16_mt.__index:getColor4U() return Color4U(band(rshift(self.a,8),0xF0)) end
function ColorRGB16_mt.__index:getColor4U()
	return Color4U(band(rshift(self:getR() + lshift(self:getG(), 1) + self:getB(), 2), 0xF0))
end
ColorRGB24_mt.__index.getColor4U = ColorRGB16_mt.__index.getColor4U
ColorRGB32_mt.__index.getColor4U = ColorRGB16_mt.__index.getColor4U

-- to Color8:
function Color4L_mt.__index:getColor8()
	local v = band(self.a, 0x0F)
	return Color8(bor(lshift(v, 4), v))
end
function Color4U_mt.__index:getColor8()
	local v = band(self.a, 0xF0)
	return Color8(bor(rshift(v, 4), v))
end
function Color8_mt.__index:getColor8() return self end
function Color16_mt.__index:getColor8() return Color8(self.a) end
function ColorRGB16_mt.__index:getColor8()
	return Color8(rshift(self:getR() + lshift(self:getG(), 1) + self:getB(), 2))
end
function ColorRGB24_mt.__index:getColor8()
	return Color8(rshift(self.r + lshift(self.g, 1) + self.b, 2))
end
ColorRGB32_mt.__index.getColor8 = ColorRGB24_mt.__index.getColor8

-- to Color16:
function Color4L_mt.__index:getColor16()
	local v = self:getColor8().a
	return Color16(bor(v, lshift(v, 8)))
end
Color4U_mt.__index.getColor16 = Color4L_mt.__index.getColor16
Color8_mt.__index.getColor16 = Color4L_mt.__index.getColor16
function Color16_mt.__index.getColor16() return self end
ColorRGB16_mt.__index.getColor16 = Color4L_mt.__index.getColor16
ColorRGB24_mt.__index.getColor16 = Color4L_mt.__index.getColor16
ColorRGB32_mt.__index.getColor16 = Color4L_mt.__index.getColor16

-- to ColorRGB16:
function Color4L_mt.__index:getColorRGB16()
	local v = band(self.a, 0x0F)
	return ColorRGB16(lshift(v,11)+lshift(v,6)+lshift(v,1))
end
function Color4U_mt.__index:getColorRGB16()
	local v = band(self.a, 0xF0)
	return ColorRGB16(lshift(v,7)+lshift(v,2)+rshift(v,3))
end
function Color8_mt.__index:getColorRGB16()
	local v = rshift(self.a, 3)
	return ColorRGB16(lshift(v,10)+lshift(v,5)+v)
end
function Color16_mt.__index:getColorRGB16()
	local v = rshift(self.a, 11)
	return ColorRGB16(lshift(v,10)+lshift(v,5)+v)
end
function ColorRGB16_mt.__index:getColorRGB16() return self end
function ColorRGB24_mt.__index:getColorRGB16()
	return ColorRGB16(lshift(rshift(self.r,3),10) + lshift(rshift(self.g,3),5) + rshift(self.b,3))
end
ColorRGB32_mt.__index.getColorRGB16 = ColorRGB24_mt.__index.getColorRGB16

-- to ColorRGB24:
function Color4L_mt.__index:getColorRGB24()
	local v = self:getColor8()
	return ColorRGB24(v.a, v.a, v.a)
end
Color4U_mt.__index.getColorRGB24 = Color4L_mt.__index.getColorRGB24
Color8_mt.__index.getColorRGB24 = Color4L_mt.__index.getColorRGB24
Color16_mt.__index.getColorRGB24 = Color4L_mt.__index.getColorRGB24
function ColorRGB16_mt.__index:getColorRGB24()
	return ColorRGB24(self:getR(), self:getG(), self:getB())
end
function ColorRGB24_mt.__index:getColorRGB24() return self end
function ColorRGB32_mt.__index:getColorRGB24() return ColorRGB24(self.r, self.g, self.b) end

-- to ColorRGB32:
function Color4L_mt.__index:getColorRGB32()
	local v = self:getColor8()
	return ColorRGB32(v.a, v.a, v.a, 0)
end
Color4U_mt.__index.getColorRGB32 = Color4L_mt.__index.getColorRGB32
Color8_mt.__index.getColorRGB32 = Color4L_mt.__index.getColorRGB32
Color16_mt.__index.getColorRGB32 = Color4L_mt.__index.getColorRGB32
function ColorRGB16_mt.__index:getColorRGB32()
	return ColorRGB32(self:getR(), self:getG(), self:getB(), 0)
end
function ColorRGB24_mt.__index:getColorRGB32() return ColorRGB32(self.r, self.g, self.b) end
function ColorRGB32_mt.__index:getColorRGB32() return self end

-- RGB getters (special case for 4bpp mode)
Color4L_mt.__index.getR = Color4L_mt.__index.getColor8
Color4L_mt.__index.getG = Color4L_mt.__index.getColor8
Color4L_mt.__index.getB = Color4L_mt.__index.getColor8
Color4U_mt.__index.getR = Color4U_mt.__index.getColor8
Color4U_mt.__index.getG = Color4U_mt.__index.getColor8
Color4U_mt.__index.getB = Color4U_mt.__index.getColor8
Color8_mt.__index.getR = Color8_mt.__index.getColor8
Color8_mt.__index.getG = Color8_mt.__index.getColor8
Color8_mt.__index.getB = Color8_mt.__index.getColor8
Color16_mt.__index.getR = Color16_mt.__index.getColor8
Color16_mt.__index.getG = Color16_mt.__index.getColor8
Color16_mt.__index.getB = Color16_mt.__index.getColor8
function ColorRGB16_mt.__index:getR() return lshift(band(self.v, 0x001F),3) end
function ColorRGB16_mt.__index:getG() return rshift(band(self.v, 0x03E0),2) end
function ColorRGB16_mt.__index:getB() return rshift(band(self.v, 0x7C00),7) end
function ColorRGB24_mt.__index:getR() return self.r end
function ColorRGB24_mt.__index:getG() return self.g end
function ColorRGB24_mt.__index:getB() return self.b end
ColorRGB32_mt.__index.getR = ColorRGB24_mt.__index.getR
ColorRGB32_mt.__index.getG = ColorRGB24_mt.__index.getG
ColorRGB32_mt.__index.getB = ColorRGB24_mt.__index.getB

function Color4L_mt.__index:invert() return Color4L(bxor(self.a, 0x0F)) end
function Color4U_mt.__index:invert() return Color4U(bxor(self.a, 0xF0)) end
function Color8_mt.__index:invert() return Color8(bxor(self.a, 0xFF)) end
function Color16_mt.__index:invert() return Color16(bxor(self.a, 0xFFFF)) end
function ColorRGB16_mt.__index:invert() return ColorRGB16(bxor(self.v, 0x7FFF)) end
function ColorRGB24_mt.__index:invert()
	return ColorRGB24(bxor(self.r, 0xFF), bxor(self.g, 0xFF), bxor(self.b, 0xFF))
end
ColorRGB32_mt.__index.invert = ColorRGB24_mt.__index.invert

-- set pixel values
function BB4_mt.__index:setPixel(x, y, color)
	local p = self:getPixel(x, y)
	if band(x, 1) == 0 then
		p[0].a = bor(band(p[0].a, 0x0F), color:getColor4U().a)
	else
		p[0].a = bor(band(p[0].a, 0xF0), color:getColor4L().a)
	end
end
function BB8_mt.__index:setPixel(x, y, color)
	self:getPixel(x, y)[0].a = color:getColor8()
end
function BB16_mt.__index:setPixel(x, y, color)
	self:getPixel(x, y)[0].a = color:getColor16()
end
function BBRGB16_mt.__index:setPixel(x, y, color)
	self:getPixel(x, y)[0].v = color:getColorRGB16()
end
function BBRGB24_mt.__index:setPixel(x, y, color)
	self:getPixel(x, y)[0] = color:getColorRGB24()
end
function BBRGB32_mt.__index:setPixel(x, y, color)
	self:getPixel(x, y)[0] = color:getColorRGB32()
end

function BB4_mt.__index:getBpp() return 4 end
function BB8_mt.__index:getBpp() return 8 end
function BB16_mt.__index:getBpp() return 16 end
function BBRGB16_mt.__index:getBpp() return 16 end
function BBRGB24_mt.__index:getBpp() return 24 end
function BBRGB32_mt.__index:getBpp() return 32 end

function BB4_mt.__index:isRGB() return false end
function BB8_mt.__index:isRGB() return false end
function BB16_mt.__index:isRGB() return false end
function BBRGB16_mt.__index:isRGB() return true end
function BBRGB24_mt.__index:isRGB() return true end
function BBRGB32_mt.__index:isRGB() return true end

--[[
generic boundary check for copy operations

@param length length of copy operation
@param target_offset where to place part into target
@param source_offset where to take part from in source
@param target_size length of target buffer
@param source_size length of source buffer

@return adapted length that actually fits
@return adapted target offset, guaranteed within range 0..(target_size-1)
@return adapted source offset, guaranteed within range 0..(source_size-1)
--]]
local function checkBounds(length, target_offset, source_offset, target_size, source_size)
	if target_offset < 0 then
		length = length + target_offset
		source_offset = source_offset - target_offset
		target_offset = 0
	end
	if source_offset < 0 then
		length = length + source_offset
		target_offset = target_offset - source_offset
		source_offset = 0
	end
	local target_left = target_size - target_offset
	local source_left = source_size - source_offset
	if length <= target_left and length <= source_left then
		return length, target_offset, source_offset
	elseif target_left < length and target_left < source_left then
		return target_left, target_offset, source_offset
	else
		return source_left, target_offset, source_offset
	end
end


function BB_mt.__index:blitFromChecked(source, dest_x, dest_y, offs_x, offs_y, width, height, colormod)
	local o_y = offs_y
	for y = dest_y, dest_y+height-1 do
		local o_x = offs_x
		for x = dest_x, dest_x+width-1 do
			self:setPixel(x, y, colormod(source:getPixel(o_x, o_y)[0]))
			o_x = o_x + 1
		end
		o_y = o_y + 1
	end
end

local function no_color_mod(value) return value end

function BB.mod_invert(value)
	return value:invert()
end

function BB_mt.__index:blitFrom(source, dest_x, dest_y, offs_x, offs_y, width, height, colormod)
	width, height = width or source.w, height or source.h
	if not colormod then colormod = no_color_mod end

	width, dest_x, offs_x = checkBounds(width, dest_x or 0, offs_x or 0, self.w, source.w)
	height, dest_y, offs_y = checkBounds(height, dest_y or 0, offs_y or 0, self.h, source.h)

	return self:blitFromChecked(source, dest_x, dest_y, offs_x, offs_y, width, height, colormod)
end
BB_mt.__index.blitFullFrom = BB_mt.__index.blitFrom

--[[
paint a rectangle onto this buffer

@param x1 X coordinate
@param y1 Y coordinate
@param w width
@param h height
@param value color value
--]]
function BB_mt.__index:paintRect(x1, y1, w, h, value)
	if w <= 0 or h <= 0 then return end
	w, x1 = checkBounds(w, x1, 0, self.w, 0xFFFF)
	h, y1 = checkBounds(h, y1, 0, self.h, 0xFFFF)
	for y = y1, y1+h-1 do
		for x = x1, x1+w-1 do
			self:setPixel(x, y, value)
		end
	end
end
BB4_mt.__index.paintRect = BB_mt.__index.paintRect

--[[
paint a circle onto this buffer

@param x1 X coordinate of the circle's center
@param y1 Y coordinate of the circle's center
@param r radius
@param c color value (defaults to black)
@param w width of line (defaults to radius)
--]]
function BB_mt.__index:paintCircle(center_x, center_y, r, c, w)
	if w == nil then w = r end

	if center_x + r > self.w or center_x - r < 0
	or center_y + r > self.h or center_y - r < 0
	or r == 0
	then
		return
	end

	if w > r then w = r end

	-- for outer circle
	local x = 0
	local y = r
	local delta = 5/4 - r

	-- for inner circle
	local r2 = r - w
	local x2 = 0
	local y2 = r2
	local delta2 = 5/4 - r

	-- draw two axles
	for tmp_y = r, r2+1, -1 do
		self:setPixel(center_x+0, center_y+tmp_y, c)
		self:setPixel(center_x-0, center_y-tmp_y, c)
		self:setPixel(center_x+tmp_y, center_y+0, c)
		self:setPixel(center_x-tmp_y, center_y-0, c)
	end

	while x < y do
		-- decrease y if we are out of circle
		x = x + 1;
		if delta > 0 then
			y = y - 1
			delta = delta + 2*x - 2*y + 2
		else
			delta = delta + 2*x + 1
		end

		-- inner circle finished drawing, increase y linearly for filling
		if x2 > y2 then
			y2 = y2 + 1
			x2 = x2 + 1
		else
			x2 = x2 + 1
			if delta2 > 0 then
				y2 = y2 - 1
				delta2 = delta2 + 2*x2 - 2*y2 + 2
			else
				delta2 = delta2 + 2*x2 + 1
			end
		end

		for tmp_y = y, y2+1, -1 do
			self:setPixel(center_x+x, center_y+tmp_y, c)
			self:setPixel(center_x+tmp_y, center_y+x, c)

			self:setPixel(center_x+tmp_y, center_y-x, c)
			self:setPixel(center_x+x, center_y-tmp_y, c)

			self:setPixel(center_x-x, center_y-tmp_y, c)
			self:setPixel(center_x-tmp_y, center_y-x, c)

			self:setPixel(center_x-tmp_y, center_y+x, c)
			self:setPixel(center_x-x, center_y+tmp_y, c)
		end
	end
	if r == w then
		self:setPixel(center_x, center_y, c)
	end
end

function BB_mt.__index:paintRoundedCorner(off_x, off_y, w, h, bw, r, c)
	if 2*r > h
	or 2*r > w
	or r == 0
	then
		return
	end

	r = math.min(r, h, w)
	if bw > r then
		bw = r
	end

	-- for outer circle
	local x = 0
	local y = r
	local delta = 5/4 - r

	-- for inner circle
	local r2 = r - bw
	local x2 = 0
	local y2 = r2
	local delta2 = 5/4 - r

	while x < y do
		-- decrease y if we are out of circle
		x = x + 1
		if delta > 0 then
			y = y - 1
			delta = delta + 2*x - 2*y + 2
		else
			delta = delta + 2*x + 1
		end

		-- inner circle finished drawing, increase y linearly for filling
		if x2 > y2 then
			y2 = y2 + 1
			x2 = x2 + 1
		else
			x2 = x2 + 1
			if delta2 > 0 then
				y2 = y2 - 1
				delta2 = delta2 + 2*x2 - 2*y2 + 2
			else
				delta2 = delta2 + 2*x2 + 1
			end
		end

		for tmp_y = y, y2+1, -1 do
			self:setPixel((w-r)+off_x+x-1, (h-r)+off_y+tmp_y-1, c)
			self:setPixel((w-r)+off_x+tmp_y-1, (h-r)+off_y+x-1, c)

			self:setPixel((w-r)+off_x+tmp_y-1, (r)+off_y-x, c)
			self:setPixel((w-r)+off_x+x-1, (r)+off_y-tmp_y, c)

			self:setPixel((r)+off_x-x, (r)+off_y-tmp_y, c)
			self:setPixel((r)+off_x-tmp_y, (r)+off_y-x, c)

			self:setPixel((r)+off_x-tmp_y, (h-r)+off_y+x-1, c)
			self:setPixel((r)+off_x-x, (h-r)+off_y+tmp_y-1, c)
		end
	end
end

--[[
explicit unset

will free immediately
--]]
function BB_mt.__index:free()
	if self.allocated ~= 0 then
		self.allocated = 0
		ffi.C.free(self.data)
	end
end

--[[
memory management
--]]
BB_mt.__gc = BB_mt.__index.free

--[[
Draw a border

@x:  start position in x axis
@y:  start position in y axis
@w:  width of the border
@h:  height of the border
@bw: line width of the border
@c:  color for loading bar
@r:  radius of for border's corner (nil or 0 means right corner border)
--]]
function BB_mt.__index:paintBorder(x, y, w, h, bw, c, r)
	x, y = math.ceil(x), math.ceil(y)
	h, w = math.ceil(h), math.ceil(w)
	if not r or r == 0 then
		self:paintRect(x, y, w, bw, c)
		self:paintRect(x, y+h-bw, w, bw, c)
		self:paintRect(x, y+bw, bw, h - 2*bw, c)
		self:paintRect(x+w-bw, y+bw, bw, h - 2*bw, c)
	else
		if h < 2*r then r = math.floor(h/2) end
		if w < 2*r then r = math.floor(w/2) end
		self:paintRoundedCorner(x, y, w, h, bw, r, c)
		self:paintRect(r+x, y, w-2*r, bw, c)
		self:paintRect(r+x, y+h-bw, w-2*r, bw, c)
		self:paintRect(x, r+y, bw, h-2*r, c)
		self:paintRect(x+w-bw, r+y, bw, h-2*r, c)
	end
end


--[[
Fill a rounded corner rectangular area

@x:  start position in x axis
@y:  start position in y axis
@w:  width of the area
@h:  height of the area
@c:  color used to fill the area
@r:  radius of for four corners
--]]
function BB_mt.__index:paintRoundedRect(x, y, w, h, c, r)
	x, y = math.ceil(x), math.ceil(y)
	h, w = math.ceil(h), math.ceil(w)
	if not r or r == 0 then
		self:paintRect(x, y, w, h, c)
	else
		if h < 2*r then r = math.floor(h/2) end
		if w < 2*r then r = math.floor(w/2) end
		self:paintBorder(x, y, w, h, r, c, r)
		self:paintRect(x+r, y+r, w-2*r, h-2*r, c)
	end
end


--[[
Draw a progress bar according to following args:

@x:  start position in x axis
@y:  start position in y axis
@w:  width for progress bar
@h:  height for progress bar
@load_m_w: width margin for loading bar
@load_m_h: height margin for loading bar
@load_percent: progress in percent
@c:  color for loading bar
--]]
function BB_mt.__index:progressBar(x, y, w, h,
								load_m_w, load_m_h, load_percent, c)
	if load_m_h*2 > h then
		load_m_h = h/2
	end
	self:paintBorder(x, y, w, h, 2, 15)
	self:paintRect(x+load_m_w, y+load_m_h,
				(w-2*load_m_w)*load_percent, (h-2*load_m_h), c)
end

for name, func in pairs(BB_mt.__index) do
	if not BB4_mt.__index[name] then BB4_mt.__index[name] = func end
	if not BB8_mt.__index[name] then BB8_mt.__index[name] = func end
	if not BB16_mt.__index[name] then BB16_mt.__index[name] = func end
	if not BBRGB16_mt.__index[name] then BBRGB16_mt.__index[name] = func end
	if not BBRGB24_mt.__index[name] then BBRGB24_mt.__index[name] = func end
	if not BBRGB32_mt.__index[name] then BBRGB32_mt.__index[name] = func end
end
local BlitBuffer4 = ffi.metatype("BlitBuffer4", BB4_mt)
local BlitBuffer8 = ffi.metatype("BlitBuffer8", BB8_mt)
local BlitBuffer16 = ffi.metatype("BlitBuffer16", BB16_mt)
local BlitBufferRGB16 = ffi.metatype("BlitBufferRGB16", BBRGB16_mt)
local BlitBufferRGB24 = ffi.metatype("BlitBufferRGB24", BBRGB24_mt)
local BlitBufferRGB32 = ffi.metatype("BlitBufferRGB32", BBRGB32_mt)

ffi.metatype("Color4L", Color4L_mt)
ffi.metatype("Color4U", Color4U_mt)
ffi.metatype("Color8", Color8_mt)
ffi.metatype("Color16", Color16_mt)
ffi.metatype("ColorRGB16", ColorRGB16_mt)
ffi.metatype("ColorRGB24", ColorRGB24_mt)
ffi.metatype("ColorRGB32", ColorRGB32_mt)

function BB.newBuffer(width, height, pitch, buffer, bpp, is_rgb)
	local allocated = 0
	if buffer == nil then
		if pitch == nil then
			local bits = width * bpp
			pitch = bit.rshift(bits, 3)
			if bits % 8 > 0 then pitch = pitch + 1 end
		end
		buffer = ffi.C.malloc(pitch * height)
		if buffer == nil then
			error("cannot allocate buffer")
		end
		ffi.fill(buffer, pitch * height)
		allocated = 1
	end
	if bpp == 4 then
		return BlitBuffer4(width, height, pitch, buffer, allocated)
	elseif bpp == 8 then
		return BlitBuffer8(width, height, pitch, buffer, allocated)
	elseif bpp == 16 and is_rgb == true then
		return BlitBufferRGB16(width, height, pitch, buffer, allocated)
	elseif bpp == 16 and is_rgb == false then
		return BlitBuffer16(width, height, pitch, buffer, allocated)
	elseif bpp == 24 and is_rgb == true then
		return BlitBufferRGB24(width, height, pitch, buffer, allocated)
	elseif bpp == 32 and is_rgb == true then
		return BlitBufferRGB32(width, height, pitch, buffer, allocated)
	else
		error("unsupported format")
	end
end
function BB.new(width, height, pitch, buffer)
	return BB.newBuffer(width, height, pitch, buffer, 4, false)
end

BB.Color4 = Color4L
BB.Color4L = Color4L
BB.Color4U = Color4U
BB.Color8 = Color8
BB.Color16 = Color16
BB.ColorRGB16 = ColorRGB16
BB.ColorRGB24 = ColorRGB24
BB.ColorRGB32 = ColorRGB32

function BB.test()
	local function print_bits(value)
		local function print_iter(value)
			if value > 0 then
				print_iter(rshift(value, 1))
				if band(value, 1) == 1 then io.stdout:write("1") else io.stdout:write("0") end
			else
				io.stdout:write("0b0")
			end
		end
		print_iter(value)
		io.stdout:write("\n")
	end

	local cRGB32 = ColorRGB32(0xFF, 0xAA, 0x55, 0)
	local cRGB24 = ColorRGB24(0xFF, 0xAA, 0x55)

	local cRGB24_32 = cRGB32:getColorRGB24()
	local cRGB16_32 = cRGB32:getColorRGB16()
	local c16_32 = cRGB32:getColor16()
	local c8_32 = cRGB32:getColor8()
	local c4l_32 = cRGB32:getColor4L()
	local c4u_32 = cRGB32:getColor4U()

	print_bits(cRGB16_32.v)
	print(c16_32.a)
	print(c8_32.a)
	print(c4l_32.a)
	print(c4u_32.a)
end

return BB
