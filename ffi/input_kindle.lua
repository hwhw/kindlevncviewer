local ffi = require("ffi")
local evloop = require("ffi/eventloop")

local dummy = require("ffi/posix_h")
local dummy = require("ffi/linux_input_h")

-- this module
local input = {}

-- the input event buffer
local input_queue = {}

function input.read(fd)
	local event = ffi.new("struct input_event")
	local n = ffi.C.read(fd, event, ffi.sizeof(event))
	if n ~= ffi.sizeof(event) then error("could not read full input_event") end
	table.insert(input_queue, event)
	evloop.abort_loop()
end

function input.err(fd)
	io.stderr:write("problem reading from fd "..fd..", closing.\n")
	evloop.unregister_fd(fd)
end

function input.hup(fd)
	io.stderr:write("hangup on fd "..fd..", closing.\n")
	evloop.unregister_fd(fd)
end

function input.open(device)
	local fd = ffi.C.open(device, bit.bor(ffi.C.O_RDONLY, ffi.C.O_NONBLOCK))
	if fd == -1 then
		error("cannot open device " .. device .. ", error " .. ffi.errno())
	end
	ffi.C.ioctl(fd, ffi.C.EVIOCGRAB, 1)
	evloop.register_fd(fd, input)
end

function input.waitForEvent()
	if #input_queue == 0 then
		evloop.loop()
	end
	assert(#input_queue > 0, "no input events could be aquired")
	return table.remove(input_queue, 1)
end

return input
