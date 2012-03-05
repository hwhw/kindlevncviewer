--[[
    This file contains settings related to key codes

    Copyright (C) 2010 Andy M. aka h1uke	h1ukeguy @ gmail.com
    Copyright (C) 2012 Hans-Werner Hilse <hilse@web.de>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
]]--

KEY_1 = 2
KEY_2 = 3
KEY_3 = 4
KEY_4 = 5
KEY_5 = 6
KEY_6 = 7
KEY_7 = 8
KEY_8 = 9
KEY_9 = 10
KEY_0 = 11
KEY_Q = 16
KEY_W = 17
KEY_E = 18
KEY_R = 19
KEY_T = 20
KEY_Y = 21
KEY_U = 22
KEY_I = 23
KEY_O = 24
KEY_P = 25
KEY_A = 30
KEY_S = 31
KEY_D = 32
KEY_F = 33
KEY_G = 34
KEY_H = 35
KEY_J = 36
KEY_K = 37
KEY_L = 38
KEY_DEL = 14
KEY_Z = 44
KEY_X = 45
KEY_C = 46
KEY_V = 47
KEY_B = 48
KEY_N = 49
KEY_M = 50
KEY_DOT = 52
KEY_SLASH = 53
KEY_ENTER = 28
KEY_SHIFT = 42
KEY_ALT = 56
KEY_SPACE = 57
KEY_AA = 90
KEY_SYM = 94
KEY_VPLUS = 115
KEY_VMINUS = 114
KEY_HOME = 98
KEY_PGBCK = 109
KEY_PGFWD = 124
KEY_MENU = 139
KEY_BACK = 91
KEY_FW_LEFT = 105
KEY_FW_RIGHT = 106
KEY_FW_UP = 122
KEY_FW_DOWN = 123
KEY_FW_PRESS = 92

-- constants from <linux/input.h>
EV_KEY = 1

-- event values
EVENT_VALUE_KEY_PRESS = 1
EVENT_VALUE_KEY_REPEAT = 2
EVENT_VALUE_KEY_RELEASE = 0
 
function set_k3_keycodes()
	KEY_AA = 190
	KEY_SYM = 126
	KEY_HOME = 102
	KEY_BACK = 158
	KEY_PGFWD = 191
	KEY_LPGBCK = 193
	KEY_LPGFWD = 104
	KEY_VPLUS = 115
	KEY_VMINUS = 114
	KEY_FW_UP = 103
	KEY_FW_DOWN = 108
	KEY_FW_PRESS = 194
end

