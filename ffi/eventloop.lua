-- dependencies
local ffi = require("ffi")
local bit = require("bit")
local posix = require("ffi/posix_h")

-- this module
local events = {}

-- Lua table storing file descriptors and callbacks
local fds = {}
-- Lua table storing timers and their callbacks
local timers = nil

-- C array for poll()
local poll_fds = nil
-- counter for that C array
local open_fds = 0

-- flag for the event loop
local running = true

--[[
register a file descriptor to get monitored

expects a table with functions that are called
upon events for the given file descriptor
all functions are optional, however you should
define at least "read" or "write".

function names:
  read: will get called when data can be read
  write: will get called when data can be written
  err: will get called upon errors
  hup: will get called upon a hangup

@parm fd file descriptor (integer)
@parm callback table
--]]
function events.register_fd(fd, callbacks)
	assert(not fds[fd], "fd is already registered")
	fds[fd] = callbacks
	-- invalidate cache
	poll_fds = nil
end

--[[
register a timer

registers a callback to be called at a given time.
the time is given as a "struct timeval"
--]]
function events.register_timer(timeval, callback, id)
	-- append to the end of the list
	-- this is needed to properly calculate times
	-- in the loop: new timers must be taken into account
	local timer = { next = nil, tv = timeval, cb = callback, id = id }
	if not timers then
		timers = timer
	else
		local tail = timers
		while tail.next do tail = tail.next end
		tail.next = timer
	end
end

--[[
register a timer to fire in n milliseconds

this is a convenience wrapper that does all the calculating
--]]
function events.register_timer_in_ms(milliseconds, callback, id)
	local tv = ffi.new("struct timeval")
	ffi.C.gettimeofday(tv, nil)
	while milliseconds > 1000 do
		tv.tv_sec = tv.tv_sec + 1
		milliseconds = milliseconds - 1000
	end
	tv.tv_usec = tv.tv_usec + milliseconds * 1000
	if tv.tv_usec > 1000000 then
		tv.tv_sec = tv.tv_sec + 1
		tv.tv_usec = tv.tv_usec - 1000000
	end
	events.register_timer(tv, callback, id)
end

--[[
check if a timer exists (and is running)
--]]
function events.timer_running(id)
	if not timers then return false end
	local tail = timers
	repeat
		if tail.id == id then return true end
		tail = tail.next
	until not tail
	return false
end

--[[
remove a filedescriptor from being monitored
--]]
function events.unregister_fd(fd)
	assert(fds[fd], "fd is not registered, cannot unregister")
	table.remove(fds, fd)
	poll_fds = nil
end

--[[
remove a named timer
--]]
function events.unregister_timer(id)
	assert(id, "only timers with ID can be unregistered")
	local prev = nil
	local timer = timers
	while timer do
		if timer.id == id then
			if not prev then timers = timer.next else prev.next = timer.next end
			break
		end
		prev = timer
		timer = timer.next
	end
end

-- internal helper to recreate poll_fd array
local function check_poll_fds()
	-- check if we have a valid cache
	if poll_fds then return end
	-- otherwise, rescan
	poll_fds = nil
	open_fds = 0
	for _, _ in pairs(fds) do open_fds = open_fds + 1 end
	if open_fds > 0 then
		poll_fds = ffi.new("struct pollfd[?]", open_fds)
		local c = 0
		for fd, callbacks in pairs(fds) do
			poll_fds[c].fd = fd
			if callbacks.read then
				poll_fds[c].events = bit.bor(poll_fds[c].events, ffi.C.POLLIN)
			end
			if callbacks.write then
				poll_fds[c].events = bit.bor(poll_fds[c].events, ffi.C.POLLOUT)
			end
			c = c + 1
		end
	end
end

--[[
convenience wrapper that exits after a timeout
--]]
function events.loopusecs(timeout)
	return events.loop(timeout / 1000)
end

--[[
abort routine that will stop the event loop
--]]
function events.abort_loop()
	running = false
end

-- allocate these only once
local now = ffi.new("struct timeval")
local up_to = ffi.new("struct timeval")

--[[
main event loop
--]]
function events.loop(timeout)
	if timeout then
		events.register_timer_in_ms(timeout, events.abort_loop)
	end
	running = true
	local poll_duration
	while running do
		-- check and update poll_fd cache
		check_poll_fds()
		
		-- get time to check timers
		ffi.C.gettimeofday(now, nil)
		up_to.tv_sec = 0
		local timer = timers
		local prev = nil
		while timer do
			if now.tv_sec > timer.tv.tv_sec
			or ( now.tv_sec == timer.tv.tv_sec and now.tv_usec >= timer.tv.tv_usec) then
				timer.cb()
				-- remove from list
				if not prev then timers = timer.next else prev.next = timer.next end
			else
				if up_to.tv_sec == 0
				or timer.tv.tv_sec < up_to.tv_sec
				or (timer.tv.tv_sec == up_to.tv_sec and timer.tv.tv_usec < up_to.tv_usec) then
					up_to.tv_sec = timer.tv.tv_sec
					up_to.tv_usec = timer.tv.tv_usec
				end
				prev = timer
			end
			timer = timer.next
		end

		-- intermediate check after doing the timer work
		if not running then break end

		-- calculate wait time
		if up_to.tv_sec == 0 then
			if open_fds == 0 then
				error("got no timers waiting, got no input fds")
			end
			poll_duration = -1
		else
			poll_duration = (up_to.tv_usec - now.tv_usec) / 1000
			poll_duration = poll_duration + (up_to.tv_sec - now.tv_sec) * 1000 + 1
		end

		-- do the poll()
		local ret = ffi.C.poll(poll_fds, open_fds, poll_duration)
		if ret > 0 then
			for i = 0, open_fds-1 do
				local fd = poll_fds[i].fd
				if bit.band(poll_fds[i].revents, ffi.C.POLLIN) ~= 0 then
					fds[fd].read(fd)
				end
				if bit.band(poll_fds[i].revents, ffi.C.POLLOUT) ~= 0 then
					fds[fd].write(fd)
				end
				if bit.band(poll_fds[i].revents, ffi.C.POLLERR) ~= 0 then
					if fds[fd].err then fds[fd].err(fd) end
				end
				if bit.band(poll_fds[i].revents, ffi.C.POLLHUP) ~= 0 then
					if fds[fd].hup then fds[fd].hup(fd) end
				end
			end
		elseif ret < 0 then
			local errno = ffi.errno()
			if errno == ffi.C.EINTR then
				-- unhandled signal, ignore this for now...
			else
				error("poll(): " .. ffi.string(ffi.C.strerror(errno)))
			end
		end
	end
end

return events
