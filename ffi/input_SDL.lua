local ffi = require("ffi")
local evloop = require("ffi/eventloop")

local dummy = require("ffi/posix_h")
local dummy = require("ffi/linux_input_h")

local SDL = require("ffi/SDL")

-- this module
local input = {}

-- the input event buffer
local input_queue = {}

local poll_time = 50 -- 50 ms
local event = ffi.new("union SDL_Event")

local function genEmuEvent(evtype, code, value)
	local ev = ffi.new("struct input_event")
	ev.type = evtype
	ev.code = code
	ev.value = value
	ffi.C.gettimeofday(ev.time, nil)
	table.insert(input_queue, ev)
end

local is_in_touch = false
function input.poller()
	local got_event = SDL.SDL.SDL_PollEvent(event)
	if got_event == 0 then
		evloop.register_timer_in_ms(poll_time, input.poller)
	else
		while got_event > 0 do
			-- if we got an event, examine it here and generate
			-- events for koreader
			if event.type == SDL.SDL.SDL_KEYDOWN then
				genEmuEvent(ffi.C.EV_KEY, event.key.keysym.scancode, 1)
			elseif event.type == SDL.SDL.SDL_KEYUP then
				genEmuEvent(ffi.C.EV_KEY, event.key.keysym.scancode, 0)
			elseif event.type == SDL.SDL.SDL_MOUSEMOTION then
				if is_in_touch then
					if event.motion.xrel ~= 0 then
						genEmuEvent(ffi.C.EV_ABS, ffi.C.ABS_MT_POSITION_X, event.button.x)
					end
					if event.motion.yrel ~= 0 then
						genEmuEvent(ffi.C.EV_ABS, ffi.C.ABS_MT_POSITION_Y, event.button.y)
					end
					genEmuEvent(ffi.C.EV_SYN, ffi.C.SYN_REPORT, 0)
				end
			elseif event.type == SDL.SDL.SDL_MOUSEBUTTONUP then
				is_in_touch = false;
				genEmuEvent(ffi.C.EV_ABS, ffi.C.ABS_MT_TRACKING_ID, -1)
				genEmuEvent(ffi.C.EV_SYN, ffi.C.SYN_REPORT, 0)
			elseif event.type == SDL.SDL.SDL_MOUSEBUTTONDOWN then
				-- use mouse click to simulate single tap
				is_in_touch = true
				genEmuEvent(ffi.C.EV_ABS, ffi.C.ABS_MT_TRACKING_ID, 0)
				genEmuEvent(ffi.C.EV_ABS, ffi.C.ABS_MT_POSITION_X, event.button.x)
				genEmuEvent(ffi.C.EV_ABS, ffi.C.ABS_MT_POSITION_Y, event.button.y)
				genEmuEvent(ffi.C.EV_SYN, ffi.C.SYN_REPORT, 0)
			elseif event.type == SDL.SDL.SDL_QUIT then
				error("application forced to quit")
			end

			-- check if there are more events to flush
			got_event = SDL.SDL.SDL_PollEvent(event)
		end
		evloop.abort_loop()
	end
end

function input.open()
	SDL.open()
end

function input.waitForEvent()
	while #input_queue == 0 do
		evloop.register_timer_in_ms(poll_time, input.poller)
		evloop.loop()
	end
	return table.remove(input_queue, 1)
end

return input
