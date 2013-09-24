local util = require("ffi/util")

if util.isEmulated() then
	return require("ffi/input_SDL")
else
	return require("ffi/input_kindle")
end
