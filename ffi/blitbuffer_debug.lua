local ffi = require("ffi")
local bit = require("bit")
local bb = require("ffi/blitbuffer")
local posix = require("ffi/posix_h")

--[[
Return ASCII char resembling hex notation of @value

@value an integer between 0 and 15
--]]
local function hexChar4(value)
	local offset = 0x30
	if value >= 10 then offset = 0x41 - 10 end
	ffi.C.fputc(offset+value, io.stdout)
end

local function hexChar8(value)
	hexChar4(bit.band(bit.rshift(value, 4), 0x0F))
	hexChar4(bit.band(value, 0x0F))
end

local function bbinfo(bb)
	ffi.C.fprintf(io.stdout, "BlitBuffer, width=%d, height=%d, pitch=%d\n", bb.w, bb.h, bb.pitch)
end

local function BB4dumpHex(bb)
	for y = 0, bb.h-1 do for x = 0, bb.w-1 do
		hexChar4(bb:getPixel(x, y)[0]:getGrayValue4())
		ffi.C.fputc(0x20, io.stdout)
	end ffi.C.fputc(0x0A, io.stdout) end
end

local function BB8dumpHex(bb)
	for y = 0, bb.h-1 do for x = 0, bb.w-1 do
		hexChar8(bb:getPixel(x, y)[0]:getGrayValue8())
		ffi.C.fputc(0x20, io.stdout)
	end ffi.C.fputc(0x0A, io.stdout) end
end

local function BBRGBdumpHex(bb)
	for y = 0, bb.h-1 do for x = 0, bb.w-1 do
		local p = bb:getPixel(x, y)
		hexChar8(p[0]:getR())
		hexChar8(p[0]:getG())
		hexChar8(p[0]:getB())
		ffi.C.fputc(0x20, io.stdout)
	end ffi.C.fputc(0x0A, io.stdout) end
end

--[[
Dump buffer as hex values for debugging
--]]
function bb.dumpHex(bb)
	bbinfo(bb)
	if bb:isRGB() then
		BBRGBdumpHex(bb)
	else
		local bpp = bb:getBpp()
		if bpp == 4 then
			BB4dumpHex(bb)
		else
			BB8dumpHex(bb)
		end
	end
end

return bb
