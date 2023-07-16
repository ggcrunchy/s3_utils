--- Functionality used to scroll around the map.

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
local assert = assert
local max = math.max
local min = math.min
local next = next
local pairs = pairs

-- Modules --
local tile_layout = require("s3_utils.tile_layout")

-- Solar2D globals --
local display = display
local Runtime = Runtime

-- Cached module references --
local _Follow_
local _GetMinScale_
local _GetState_

-- Exports --
local M = {}

--
--
--

--[[
local now
timer.performWithDelay(25, function(event)
	now = now or event.time

	local dt = (event.time - now) / 1000
	local k = .5 * math.cos(dt / 3.5) + .5

	M.SetScale(M.GetMinScale() + k * .8)
end, 0)
--]]

local Groups = {}

local function RemoveTarget (event)
	Groups[event.target] = nil
end

--- DOCME
function M.AddTarget (group)
	if group.addEventListener then
		group:addEventListener("finalize", RemoveTarget)

		Groups[group] = true
	end
end

--
--
--

local Object

local Width, Height

local function EnsureSizes ()
	if not Width then
		Width, Height = tile_layout.GetFullSizes()
	end
end

local function FollowObject ()
	if display.isValid(Object) then
		local x, y = Object.x, Object.y

    EnsureSizes()

		for group in pairs(Groups) do
			local gx, gy, scale = _GetState_(group, x, y, Width, Height)

			group.x, group.xScale = gx, scale
			group.y, group.yScale = gy, scale
		end
	else
		_Follow_()
	end
end

--- Follow an object, whose motion will cause parts of the scene to be scrolled.
-- @pobject object Object to follow, or **nil** to disable scrolling (in which case,
-- _group_ is ignored).
-- @param group Given a value of **"keep"**, no change is made. Otherwise, display
-- group to be scrolled; if **nil**, uses _object_'s parent.
-- @param ... Additional groups.
-- @treturn DisplayObject Object that was being followed, or **nil** if absent.
-- TODO: revise!
function M.Follow (object)
	local old_object = Object

	Object, Width = object -- n.b. invalidate dimensions

	-- Add or remove the follow listener if we changed between following some object and
	-- following no object (or vice versa).
	if (old_object == nil) ~= (object == nil) then
		EnsureSizes()

		if old_object then
			Runtime:removeEventListener("enterFrame", FollowObject)
		else
			Runtime:addEventListener("enterFrame", FollowObject)
		end
	end

	return old_object
end

--
--
--

local CW, CH = display.contentWidth, display.contentHeight

--- DOCME
-- when does one smaller scaled dimension fill the view?
function M.GetMinScale (w, h)
	EnsureSizes()

	return min(max(CW / (w or Width), 1), min(CH / (h or Height)), 1)
end

--
--
--

--- DOCME
function M.GetNextTarget (prev)
	return next(Groups, prev)
end

--
--
--

--- DOCME
function M.GetObject ()
	return Object
end

--
--
--

local Scale = 1

--- DOCME
function M.GetScale ()
	return Scale
end

--
--
--

local function AuxGetScale (w, h)
  return max(Scale, _GetMinScale_(w, h))
end

--- DOCME
function M.GetScreenPosition (group, x, y, w, h)
	local scale = AuxGetScale(w, h)

	return (x - group.x) / scale, (y - group.y) / scale
end

--
--
--

local Left, Right, Top, Bottom

local XOffset, YOffset = 0, 0

--- DOCME
function M.GetState (group, x, y, w, h)
	assert(w, "Expected width")
	assert(h, "Expected height")

	local gx, gy, scale = group.x, group.y, AuxGetScale(w, h)
	local px, py = gx + x * scale, gy + y * scale

	if px < Left then
		gx = min(gx + (Left + XOffset - px) / scale, XOffset) -- TODO the XOffset logic predates scaling...
	elseif px > Right then
		gx = gx - (px - Right) / scale
	end

	gx = max(gx, min(0, CW - w * scale)) -- zooming might also require a clamp, so outside the px > Right check

	if py < Top then
		gy = min(gy + (Top + YOffset - py) / scale, YOffset) -- TODO: ditto
	elseif py > Bottom then
		gy = gy - (py - Bottom) / scale
	end

	gy = max(gy, min(0, CH - h * scale)) -- as with x

	return gx, gy, scale
end

--
--
--

--- Define the left and right screen extents; while the followed object is between these,
-- no horizontal scrolling will occur. If the object moves outside of them, the associated
-- group will be scrolled in an attempt to put it back inside.
--
-- Both values should be &isin; (0, 1), as fractions of screen width.
-- @number left Left extent = _left_ * Screen Width.
-- @number right Right extent = _right_ * Screen Width.
-- @see Follow
function M.SetRangeX (left, right)
	Left, Right = CW * left, CW * right
end

--
--
--

--- Define the top and bottom screen extents; while the followed object is between these,
-- no vertical scrolling will occur. If the object moves outside of them, the associated
-- group will be scrolled in an attempt to put it back inside.
--
-- Both values should be &isin; (0, 1), as fractions of screen height.
-- @number top Top extent = _top_ * Screen Height.
-- @number bottom Bottom extent = _bottom_ * Screen Height.
-- @see Follow
function M.SetRangeY (top, bottom)
	Top, Bottom = CH * top, CH * bottom
end

--
--
--

-- Set some decent defaults.
M.SetRangeX(.3, .7)
M.SetRangeY(.3, .7)

--
--
--

--- DOCME
function M.SetScale (scale)
	Scale = scale
end

--
--
--

---
-- @number offset Horizontal screen offset of the world; if **nil**, 0.
function M.SetXOffset (offset)
	XOffset = offset or 0
end

--
--
--

---
-- @number offset Vertical screen offset of the world; if **nil**, 0.
function M.SetYOffset (offset)
	YOffset = offset or 0
end

--
--
--

_Follow_ = M.Follow
_GetMinScale_ = M.GetMinScale
_GetState_ = M.GetState

return M