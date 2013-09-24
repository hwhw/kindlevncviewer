local ffi = require("ffi")
local blitbuffer = require("ffi/blitbuffer_debug")
local fb = require("ffi/framebuffer").open()
local evloop = require("ffi/eventloop")
local input = require("ffi/input")
local posix = require("ffi/posix_h")
local rfb = require("ffi/rfbclient")

local password = nil
local client = nil
local rfbFramebuffer

-- this is a "public" API to be used by a "config" file
function SendKeyEvent(key, pressed)
	rfb.SendKeyEvent(client, key, pressed)
end
function SendPointerEvent(x, y, buttonMask)
	rfb.SendPointerEvent(client, x, y, buttonMask)
end
function Quit()
	os.exit(0)
end

-- open the "config" file
require("config")


local function updateFromRFB(client, x, y, w, h)
	io.stdout:write("update ", x, ",", y, " ", w, "x", h, "\n")
	fb.bb:blitFrom(rfbFramebuffer, x, y, x, y, w, h, blitbuffer.mod_invert)
	fb:refresh()
end

local function passwordCallback(client)
	if password then
		-- we need a copy that libvncclient can free()
		return ffi.C.strndup(ffi.cast("char*", password), 8192)
	end
	io.stderr:write("got request for password, but no password was configured.\n")
end

local function connect()
	local client = rfb.rfbGetClient(5,3,2) -- 16bpp

	client.GetPassword = passwordCallback
	client.canHandleNewFBSize = 0
	client.GotFrameBufferUpdate = updateFromRFB

	local argc = ffi.new("int[1]")
	argc[0] = #arg + 1
	local argv = ffi.new("char*[?]", #arg+1)
	argv[0] = ffi.cast("char*", "kindlevncviewer")
	for k, v in ipairs(arg) do
		argv[k] = ffi.cast("char*", v)
	end

	assert(rfb.rfbInitClient(client,argc,argv) ~= 0, "cannot initialize client")

	-- set "public" configuration parameters:
	client_width = client.width
	client_height = client.height

	rfbFramebuffer = blitbuffer.newBuffer(
		client.width, client.height, client.width*2,
		client.frameBuffer, 16, true)

	return client
end

local function usage()
	io.stderr:write([[
KindleVNCViewer
A VNC viewer for e-ink devices
This is free software (GPLv2)
(c) 2013 Hans-Werner Hilse <hilse@web.de>

Usage:
luajit kindlevncviewer.lua [options...] <server>:<display>

Server is the VNC server's domain name or its IP address
Display is the VNC display number (i.e. not the TCP port number)

Available options:
-password <password>
   specify a password
(and some more that stem from libvncclient, to be documented)

]])
	os.exit(1)
end

local function try_open_input(device)
	local ok, err = pcall(input.open, device)
	if not ok then
		io.stdout:write("could not open input device ", device, " (possibly harmless)\n")
	end
end

if #arg == 0 then usage() end
for i,value in ipairs(arg) do
	if value == "-h" or value == "-?" or value == "--help" then usage() end
	if value == "-password" and arg[i+1] then
		password = arg[i+1]
		arg[i+1] = ""
	end
end

try_open_input("/dev/input/event0")
try_open_input("/dev/input/event1")
try_open_input("/dev/input/event2")

client = connect()
-- register socket handlers
evloop.register_fd(client.sock, {
	read = function()
		assert(rfb.HandleRFBServerMessage(client) ~= 0, "Error handling RFB server message.")
	end,
	err = function()
		io.stderr:write("connection error, quitting.\n")
		os.exit(1)
	end,
	hup = function()
		io.stderr:write("remote party hung up, quitting.\n")
		os.exit(1)
	end
})

local running = true
while running do
	local event = input.waitForEvent()
	handleInput(0, event.type, event.code, event.value)
end
