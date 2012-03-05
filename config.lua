require "keys"
require "rfbkeys"

-- comment out the following line on a KDX
set_k3_keycodes()


-- variables client_width and client_height will be available when handleInput() is called
client_width = 0
client_height = 0

--[[
   you have also the following API functions:

   Quit( [status] )
      will quit the application. optional: return code (must be positive)

   SendKeyEvent( keyCode, pressed )
      sends a key event to the rfb server. "pressed" is a bool value
      telling whether the key was pressed (true) or released (false)

   SendPointerEvent( x, y, buttonMask )
      sends a pointer event to the rfb server
]]--


-- globals for remembering key state
shift = false
sym = false

-- this handler will be called upon key presses (input events, actually)
function handleInput(channel, itype, code, value)
	--print("input:", channel, itype, code, value)
	if itype == EV_KEY then
		local pressed = false
		if value == EVENT_VALUE_KEY_PRESS then
			pressed = true
		elseif value == EVENT_VALUE_KEY_RELEASE then
			pressed = false
		else
			return -- we don't know how to handle this.
		end

		-- will toggle state 
		if code == KEY_SYM then sym = pressed
		elseif code == KEY_SHIFT then shift = pressed

		-- number keys, not present on K3
		elseif code == KEY_1 then SendKeyEvent(XK_1, pressed)
		elseif code == KEY_2 then SendKeyEvent(XK_2, pressed)
		elseif code == KEY_3 then SendKeyEvent(XK_3, pressed)
		elseif code == KEY_4 then SendKeyEvent(XK_4, pressed)
		elseif code == KEY_5 then SendKeyEvent(XK_5, pressed)
		elseif code == KEY_6 then SendKeyEvent(XK_6, pressed)
		elseif code == KEY_7 then SendKeyEvent(XK_7, pressed)
		elseif code == KEY_8 then SendKeyEvent(XK_8, pressed)
		elseif code == KEY_9 then SendKeyEvent(XK_9, pressed)
		elseif code == KEY_0 then SendKeyEvent(XK_0, pressed)

		-- letter keys
		elseif not shift and code == KEY_Q then SendKeyEvent(XK_q, pressed)
		elseif not shift and code == KEY_W then SendKeyEvent(XK_w, pressed)
		elseif not shift and code == KEY_E then SendKeyEvent(XK_e, pressed)
		elseif not shift and code == KEY_R then SendKeyEvent(XK_r, pressed)
		elseif not shift and code == KEY_T then SendKeyEvent(XK_t, pressed)
		elseif not shift and code == KEY_Y then SendKeyEvent(XK_y, pressed)
		elseif not shift and code == KEY_U then SendKeyEvent(XK_u, pressed)
		elseif not shift and code == KEY_I then SendKeyEvent(XK_i, pressed)
		elseif not shift and code == KEY_O then SendKeyEvent(XK_o, pressed)
		elseif not shift and code == KEY_P then SendKeyEvent(XK_p, pressed)
		elseif not shift and code == KEY_A then SendKeyEvent(XK_a, pressed)
		elseif not shift and code == KEY_S then SendKeyEvent(XK_s, pressed)
		elseif not shift and code == KEY_D then SendKeyEvent(XK_d, pressed)
		elseif not shift and code == KEY_F then SendKeyEvent(XK_f, pressed)
		elseif not shift and code == KEY_G then SendKeyEvent(XK_g, pressed)
		elseif not shift and code == KEY_H then SendKeyEvent(XK_h, pressed)
		elseif not shift and code == KEY_J then SendKeyEvent(XK_j, pressed)
		elseif not shift and code == KEY_K then SendKeyEvent(XK_k, pressed)
		elseif not shift and code == KEY_L then SendKeyEvent(XK_l, pressed)
		elseif not shift and code == KEY_Z then SendKeyEvent(XK_z, pressed)
		elseif not shift and code == KEY_X then SendKeyEvent(XK_x, pressed)
		elseif not shift and code == KEY_C then SendKeyEvent(XK_c, pressed)
		elseif not shift and code == KEY_V then SendKeyEvent(XK_v, pressed)
		elseif not shift and code == KEY_B then SendKeyEvent(XK_b, pressed)
		elseif not shift and code == KEY_N then SendKeyEvent(XK_n, pressed)
		elseif not shift and code == KEY_M then SendKeyEvent(XK_m, pressed)
		elseif shift and code == KEY_Q then SendKeyEvent(XK_Q, pressed)
		elseif shift and code == KEY_W then SendKeyEvent(XK_W, pressed)
		elseif shift and code == KEY_E then SendKeyEvent(XK_E, pressed)
		elseif shift and code == KEY_R then SendKeyEvent(XK_R, pressed)
		elseif shift and code == KEY_T then SendKeyEvent(XK_T, pressed)
		elseif shift and code == KEY_Y then SendKeyEvent(XK_Y, pressed)
		elseif shift and code == KEY_U then SendKeyEvent(XK_U, pressed)
		elseif shift and code == KEY_I then SendKeyEvent(XK_I, pressed)
		elseif shift and code == KEY_O then SendKeyEvent(XK_O, pressed)
		elseif shift and code == KEY_P then SendKeyEvent(XK_P, pressed)
		elseif shift and code == KEY_A then SendKeyEvent(XK_A, pressed)
		elseif shift and code == KEY_S then SendKeyEvent(XK_S, pressed)
		elseif shift and code == KEY_D then SendKeyEvent(XK_D, pressed)
		elseif shift and code == KEY_F then SendKeyEvent(XK_F, pressed)
		elseif shift and code == KEY_G then SendKeyEvent(XK_G, pressed)
		elseif shift and code == KEY_H then SendKeyEvent(XK_H, pressed)
		elseif shift and code == KEY_J then SendKeyEvent(XK_J, pressed)
		elseif shift and code == KEY_K then SendKeyEvent(XK_K, pressed)
		elseif shift and code == KEY_L then SendKeyEvent(XK_L, pressed)
		elseif shift and code == KEY_Z then SendKeyEvent(XK_Z, pressed)
		elseif shift and code == KEY_X then SendKeyEvent(XK_X, pressed)
		elseif shift and code == KEY_C then SendKeyEvent(XK_C, pressed)
		elseif shift and code == KEY_V then SendKeyEvent(XK_V, pressed)
		elseif shift and code == KEY_B then SendKeyEvent(XK_B, pressed)
		elseif shift and code == KEY_N then SendKeyEvent(XK_N, pressed)
		elseif shift and code == KEY_M then SendKeyEvent(XK_M, pressed)

		-- other keys
		elseif not shift and code == KEY_DEL then SendKeyEvent(XK_Delete, pressed)
		elseif shift and code == KEY_DEL then SendKeyEvent(XK_BackSpace, pressed)
		elseif code == KEY_DOT then SendKeyEvent(XK_period, pressed)
		elseif code == KEY_SLASH then SendKeyEvent(XK_slash, pressed)
		elseif code == KEY_ENTER then SendKeyEvent(XK_Return, pressed)
		elseif code == KEY_SPACE then SendKeyEvent(XK_space, pressed)

		elseif code == KEY_ALT then SendKeyEvent(XK_Alt_L, pressed)
		elseif code == KEY_AA then SendKeyEvent(XK_Control_L, pressed)

		-- special keys
		--elseif code == KEY_VPLUS then SendKeyEvent(XK_, pressed)
		--elseif code == KEY_VMINUS then SendKeyEvent(XK_, pressed)
		elseif code == KEY_HOME then
			Quit()
		elseif code == KEY_PGBCK then SendKeyEvent(XK_Escape, pressed)
		elseif code == KEY_PGFWD then SendKeyEvent(XK_Tab, pressed)
		-- the following two exist only on K3
		elseif code == KEY_LPGBCK then SendKeyEvent(XK_Escape, pressed)
		elseif code == KEY_LPGFWD then SendKeyEvent(XK_Tab, pressed)
		--elseif code == KEY_MENU then SendKeyEvent(XK_, pressed)
		--elseif code == KEY_BACK then SendKeyEvent(XK_, pressed)
		elseif code == KEY_FW_LEFT then SendKeyEvent(XK_Left, pressed)
		elseif code == KEY_FW_RIGHT then SendKeyEvent(XK_Right, pressed)
		elseif code == KEY_FW_UP then SendKeyEvent(XK_Up, pressed)
		elseif code == KEY_FW_DOWN then SendKeyEvent(XK_Down, pressed)
		elseif code == KEY_FW_PRESS then SendKeyEvent(XK_Return, pressed)
		end
	end
end
