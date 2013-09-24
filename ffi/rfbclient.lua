local ffi = require("ffi")

require("ffi/rfbclient_h")

local rfb = ffi.load("./libvncclient.so")

return rfb
