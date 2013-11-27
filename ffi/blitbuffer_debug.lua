local ffi = require("ffi")
local bit = require("bit")
local bb = require("ffi/blitbuffer")
local posix = require("ffi/posix_h")

--[[
Return ASCII char resembling hex notation of @value

@value an integer between 0 and 15
--]]
local function bbinfo(bb)
	io.stdout:write("BlitBuffer, bpp=", bb:getBpp(), ", width=", bb:getWidth(), ", height=", bb:getHeight(), ", config=0x", bit.tohex(bb.config, 2), "\n")
end

local function BBdumpHex(bb)
	for y = 0, bb:getHeight()-1 do for x = 0, bb:getWidth()-1 do
		io.stdout:write(bit.tohex(bb:getPixel(x, y):getR(), bb:getBpp()/4), " ")
	end io.stdout:write("\n") end
end

local function BBRGBdumpHex(bb)
	for y = 0, bb:getHeight()-1 do for x = 0, bb:getWidth()-1 do
		local p = bb:getPixel(x, y)
		io.stdout:write(bit.tohex(p:getR(), 2), bit.tohex(p:getG(), 2), bit.tohex(p:getB(), 2), " ")
	end io.stdout:write("\n") end
end

--[[
Dump buffer as hex values for debugging
--]]
function bb.dumpHex(bb)
	bbinfo(bb)
	if bb:isRGB() then
		BBRGBdumpHex(bb)
	else
		BBdumpHex(bb)
	end
end

return bb
