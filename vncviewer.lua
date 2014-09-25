#!./luajit
local ffi = require("ffi")
local blitbuffer = require("ffi/blitbuffer")
local fb = require("ffi/framebuffer").open("/dev/fb0")
local evloop = require("ffi/eventloop")
local input = require("ffi/input")
local posix = require("ffi/posix_h")
local rfb = require("ffi/rfbclient")

local password = nil
local client = nil
local rfbFramebuffer = nil
local configfile = "config.lua"

local waitRefresh = 250
local rotateFB = 0
local reconnecting = false
local debug = false
local blitfunc = nil

local update_x1 = nil
local update_x2 = 0
local update_y1 = 0
local update_y2 = 0

local refresh_full_every_256th_pxup = 512
local refresh_full_ctr = 0

-- this is just an ID value
local TIMER_REFRESH = 10

-- constants for screen updates
local WAVEFORM_MODE_INIT      = 0x0   -- Screen goes to white (clears)
local WAVEFORM_MODE_DU        = 0x1   -- Grey->white/grey->black
local WAVEFORM_MODE_GC16      = 0x2   -- High fidelity (flashing)
local WAVEFORM_MODE_GC4       = WAVEFORM_MODE_GC16 -- For compatibility
local WAVEFORM_MODE_GC16_FAST = 0x3   -- Medium fidelity
local WAVEFORM_MODE_A2        = 0x4   -- Faster but even lower fidelity
local WAVEFORM_MODE_GL16      = 0x5   -- High fidelity from white transition
local WAVEFORM_MODE_GL16_FAST = 0x6   -- Medium fidelity from white transition
local WAVEFORM_MODE_AUTO      = 0x101

local waveform_default_fast = WAVEFORM_MODE_GC16
local waveform_default_slow = WAVEFORM_MODE_GC16

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

local function do_refresh_full(w, h)
	-- return false when full refresh is disabled
	if refresh_full_every_256th_pxup == 0 then
		return false
	end
	-- otherwise count number of pixels updated
	refresh_full_ctr = refresh_full_ctr + w*h
	if refresh_full_ctr >= bit.rshift(fb.bb:getWidth() * fb.bb:getHeight() * refresh_full_every_256th_pxup, 8) then
		refresh_full_ctr = 0
		return true
	end
	return false
end

local function refreshTimerFunc()
	-- not sure how this could happen but it does.
	-- TODO: find race condition
	--if not update_x1 then return end

	local x = update_x1
	local y = update_y1
	local w = update_x2 - update_x1
	local h = update_y2 - update_y1

	if debug then
		io.stdout:write(
			"eink update ", x, ",", y, " ",
			w, "x", h, "\n")
	end

	fb.bb:blitFrom(rfbFramebuffer,
		x, y, x, y, w, h, blitfunc)

	if do_refresh_full(w, h) then
		if debug then
			io.stdout:write("slow eink refresh\n")
		end
		fb:refresh(1, waveform_default_slow)
	else
		if debug then
			io.stdout:write("fast eink refresh\n")
		end
		fb:refresh(0, waveform_default_fast, x, y, w, h)
	end
	update_x1 = nil
end

local function updateFromRFB(client, x, y, w, h)
	-- this would reset the timer, which we probably do not
	-- want since this might hold a eink refresh
	-- indefinitely:
	--evloop.unregister_timer(TIMER_REFRESH)

	if debug then
		io.stdout:write(
			"RFB update ", x, ",", y, " ",
			w, "x", h, "\n")
	end

	if not update_x1 then
		update_x1 = x
		update_x2 = x+w
		update_y1 = y
		update_y2 = y+h
	else
		if update_x1 > x then update_x1 = x end
		if update_x2 < x+w then update_x2 = x+w end
		if update_y1 > y then update_y1 = y end
		if update_y2 < y+h then update_y2 = y+h end
	end

	if not evloop.timer_running(TIMER_REFRESH) then
		evloop.register_timer_in_ms(waitRefresh,
			refreshTimerFunc, TIMER_REFRESH)
	end
end

local function passwordCallback(client)
	if password then
		-- we need a copy that libvncclient can free()
		return ffi.C.strndup(ffi.cast("char*", password), 8192)
	end
	io.stderr:write("got request for password, but no password was configured.\n")
	return nil
end

local function connect()
	local client = rfb.rfbGetClient(8,3,4) -- 24bpp

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

	rfbFramebuffer = blitbuffer.new(
		client.width, client.height,
		blitbuffer.TYPE_BBBGR32,
		client.frameBuffer)
	rfbFramebuffer:invert()

	return client
end

local function usage()
	io.stderr:write([[
kVNCViewer
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

-config <file>
   load configuration from <file>. Default is "config.lua".

-rotateFB <degree>
   rotate local framebuffer by <degree> degrees (multiple of 90)

-waitRefresh <milliseconds>
   wait specified number of milliseconds after receiving an update
   before refreshing the screen. Default value is 150.

-refreshFullAfterPixels <n>
   after updating <n> times the screen's pixels, a full eink
   refresh is issued. Default is 2.0
   If you specify 0 here, it won't do a full refresh at all.

-dither_bw
   dither to black/white (speeds up display on eink, but looks ugly)

-medium
   a bit lower quality, but also a tad bit faster

-fast
   low quality but fast

-debug
   output some debug information

-reconnecting
   always try to reconnect when we get connection errors

-version
   output version number

(and some more that stem from libvncclient, to be documented)

]])
	os.exit(1)
end

local function try_open_input(device)
	local ok, err = pcall(input.open, device)
	if not ok then
		io.stderr:write("could not open input device ", device, " (possibly harmless)\n")
	end
end

if #arg == 0 then usage() end
for i,value in ipairs(arg) do
	if value == "-h" or value == "-?" or value == "--help" then usage() end
	if value == "-password" and arg[i+1] then
		password = arg[i+1]
		arg[i+1] = ""
	elseif value == "-config" and arg[i+1] then
		configfile = arg[i+1]
		arg[i+1] = ""
	elseif value == "-rotateFB" and arg[i+1] then
		rotateFB = tonumber(arg[i+1])
		arg[i+1] = ""
	elseif value == "-waitRefresh" and arg[i+1] then
		waitRefresh = tonumber(arg[i+1])
		arg[i+1] = ""
	elseif value == "-refreshFullAfterPixels" and arg[i+1] then
		refresh_full_every_256th_pxup = 256 * tonumber(arg[i+1])
		arg[i+1] = ""
	elseif value == "-fast" then
		local waveform_default_fast = WAVEFORM_MODE_A2
		local waveform_default_slow = WAVEFORM_MODE_GL16
	elseif value == "-medium" then
		local waveform_default_fast = WAVEFORM_MODE_GL16
		local waveform_default_slow = WAVEFORM_MODE_GL16
	elseif value == "-dither_bw" then
		blitfunc = fb.bb.setPixelDithered
	elseif value == "-debug" then
		debug = true
	elseif value == "-reconnecting" then
		reconnecting = true
	elseif value == "-version" then
		io.stdout:write("KindleVNCviewer version ", require("version"), "\n",
				"see http://github.com/hwhw/kindlevncviewer for source code\n")
		os.exit(0)
	end
end

-- open the "config" file
dofile(configfile)

fb.bb:rotate(rotateFB)

try_open_input("/dev/input/event0")
try_open_input("/dev/input/event1")
try_open_input("/dev/input/event2")

repeat
	client = connect()

	local running = true

	-- register socket handlers
	evloop.register_fd(client.sock, {
		read = function()
			assert(rfb.HandleRFBServerMessage(client) ~= 0, "Error handling RFB server message.")
		end,
		err = function()
			if not reconnecting then
				io.stderr:write("connection error, quitting.\n")
				os.exit(1)
			else
				io.stderr:write("connection error, retrying in 1s...\n")
				running = false
			end
		end,
		hup = function()
			if not reconnecting then
				io.stderr:write("remote party hung up, quitting.\n")
				os.exit(1)
			else
				io.stderr:write("remote party hung up, retrying in 1s...\n")
				running = false
			end
		end
	})

	while running do
		local event = input.waitForEvent()
		handleInput(0, event.type, event.code, event.value)
	end

	ffi.C.sleep(1) -- so we don't hammer when the connection is down
until not reconnecting
