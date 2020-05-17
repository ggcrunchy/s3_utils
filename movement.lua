--- Functionality related to movement, as allowed by local tiles.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local abs = math.abs
local assert = assert
local max = math.max
local min = math.min
local next = next

-- Plugins --
local bit = require("plugin.bit")

-- Cached module references --
local _CanGo_
local _GetDirectionFlag_
local _NextDirection_

-- Exports --
local M = {}

--
--
--

-- Direction lookup --
local Directions = {
	left = { to_left = "down", to_right = "up", backward = "right", flag = 0x1 },
	right = { to_left = "up", to_right = "down", backward = "left", flag = 0x2 },
	up = { to_left = "left", to_right = "right", backward = "down", flag = 0x4 },
	down = { to_left = "right", to_right = "left", backward = "up", flag = 0x8 }
}

---
-- @uint flags Tile flags.
-- @string dir Direction to query.
-- @treturn boolean Can we move to the next tile, going this way?
--
-- Note that this does not say that we can get back from the next tile, i.e. it doesn't
-- guarantee that the tiles are connected, or even that there is a next tile.
--
-- In addition, it does not say whether we can move within this tile, e.g if there is a
-- path from one side to the center.
-- @see NextDirection
function M.CanGo (flags, dir)
	return bit.band(flags or 0, _GetDirectionFlag_(dir)) ~= 0
end

local function AuxDirectionsFromFlags (flags, dir)
	for k in next, Directions, dir do
		if _CanGo_(flags, k) then
			return k
		end
	end
end

--- Iterate over the directions open on a given tile.
-- @int index
-- @treturn iterator Supplies direction.
function M.DirectionsFromFlags (flags)
	return AuxDirectionsFromFlags, flags or 0
end

--- DOCME
function M.GetDirectionFlag (dir)
	return assert(Directions[dir], "Invalid direction").flag
end

---
-- @string dir One of **"left"**, **"right"**, **"up"**, **"down"**.
-- @uint ncols Column count.
-- @treturn uint Index delta to the next tile.
function M.GetTileDelta (dir, ncols)
	local delta = (dir == "up" or dir == "down") and ncols or 1

	return (dir == "up" or dir == "left") and -delta or delta
end

local function Add (v, dist, comp)
	v = v + dist

	return comp and min(comp, v) or v
end

local function Sub (v, dist, comp)
	v = v - dist

	return comp and max(comp, v) or v
end

--- Move by a given amount, from a given position, in a given direction. This relaxes
-- cornering, and does the heavy lifting of keeping the result "on the rails".
-- @number x Current x-coordinate...
-- @number y ...and y-coordinate.
-- @number px Tile x-coordinate...
-- @number py ...and y-coordinate.
-- @uint flags Tile flags.
-- @number dist Amount of distance we may move.
-- @string dir Direction we want to go.
-- @treturn number Result x-coordinate.
-- @treturn number Result y-coordinate.
function M.MoveFrom (x, y, px, py, flags, dist, dir)
	-- The algorithm is the same aside from the variables, so all movement is treated as
	-- vertical. We swap coordinates in the horizontal case to maintain this pretense.
	if dir == "left" or dir == "right" then
		x, y, px, py = y, x, py, px
	end

	-- The algorithm also has symmetry going up or down, so we just choose an increment
	-- operator and check whether we can exit the tile in the direction we want.
	local inc = (dir == "up" or dir == "left") and Sub or Add

	if _CanGo_(flags, dir) then
		local adx = abs(x - px)

		-- If we can't make it to the corner / junction yet, close some of the distance.
		-- Prepare, at least, by making sure we're lined up vertically.
		if adx > dist then
			x, y = x > px and x - dist or x + dist, py

		-- Otherwise, close the remaining distance, and spend whatever remains moving in the
		-- direction we want to go.
		else
			if adx > 0 then
				dist, y = dist - adx, py
			end

			x, y = px, inc(y, dist)
		end

	-- We can't exit the tile, but we can at least approach the center.
	else
		y = inc(y, dist, py)
	end

	-- Return the result, reinterpreted horizontally if we switched earlier.
	if dir == "left" or dir == "right" then
		return y, x
	else
		return x, y
	end
end

--- Determine next direction, given the direction you're facing and which way you're headed.
-- @string facing One of **"left"**, **"right"**, **"up"**, **"down"**.
-- @string headed One of **"to_left"**, **"to_right"**, **"backward"**, **"forward"**.
function M.NextDirection (facing, headed)
	assert(headed ~= "flags", "Invalid headed option")

	local choice = assert(Directions[facing], "Facing in invalid direction")

	if headed ~= "forward" then
		facing = choice[headed]
	end

	return facing
end

local Horz = { left = -1, right = 1 }
local Vert = { up = -1, down = 1 }

--- Variant of @{NextDirection} that also supplies unit deltas.
-- @string facing One of **"left"**, **"right"**, **"up"**, **"down"**.
-- @string headed One of **"to_left"**, **"to_right"**, **"backward"**, **"forward"**.
-- @treturn string Absolute direction.
-- @treturn uint Column delta to the next tile...
-- @treturn uint ...and row delta.
function M.NextDirection_UnitDeltas (facing, headed)
	facing = _NextDirection_(facing, headed)

	return facing, Horz[facing] or 0, Vert[facing] or 0
end

--- Convenience function to give turn directions.
-- @bool swap Swap the return values?
-- @treturn string Normally, **"to_left"**.
-- @treturn string Normally, **"to_right"**.
function M.Turns (swap)
	if swap then
		return "to_right", "to_left"
	else
		return "to_left", "to_right"
	end
end

--- Choose which direction to follow at a tile, given some preferences.
-- @uint flags Tile flags.
-- @string dir1 Preferred direction.
-- @string dir2 First runner-up.
-- @string dir3 Second runner-up.
-- @string facing If provided, the _dir*_ are interpreted as `NextDirection(facing, dir*)`.
-- @treturn string If any of the _dir*_ was open, the most preferred one is returned, without
-- modification; otherwise, returns **"backward"**.
-- @see CanGo, NextDirection
function M.WayToGo (flags, dir1, dir2, dir3, facing)
	local was1, was2, was3

	if facing ~= nil then
		dir1, was1 = _NextDirection_(dir1, facing), dir1
		dir2, was2 = _NextDirection_(dir2, facing), dir2
		dir3, was3 = _NextDirection_(dir3, facing), dir3
	end

	if _CanGo_(flags, dir1) then
		return was1 or dir1
	elseif _CanGo_(flags, dir2) then
		return was2 or dir2
	elseif _CanGo_(flags, dir3) then
		return was3 or dir3
	end

	return "backward"
end

_CanGo_ = M.CanGo
_GetDirectionFlag_ = M.GetDirectionFlag
_NextDirection_ = M.NextDirection

return M