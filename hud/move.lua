--- Move elements of the HUD.
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
local min = math.min
local sqrt = math.sqrt

-- Extension imports --
local round = math.round

-- Modules --
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local display = display
local Runtime = Runtime
local timer = timer

-- Exports --
local M = {}

--
--
--

-- Partially adapted from ponywolf's vjoy
local AxisEvent = { name = "axis", axis = {}, device = { type = "joystick" } } -- cf. corona_utils.device.AxisToKey()

local InnerRadius, OuterRadius = 65, 96
local StickRange = OuterRadius - InnerRadius

local function AuxSendEvent (num, value)
	AxisEvent.axis.number, AxisEvent.normalizedValue = num, value / StickRange

	Runtime:dispatchEvent(AxisEvent)
end

local function StickTimer (stick)
	return function(event)
		if not display.isValid(stick) then
			timer.cancel(event.source)
		elseif not stick.m_x then
			local base = stick.m_base
			local dx, dy = stick.x - base.x, stick.y - base.y
			local dist_sq = dx^2 + dy^2

			if dist_sq > 4 then
				local scale = min(15 / sqrt(dist_sq), 1)

				stick.x, stick.y = stick.x - scale * dx, stick.y - scale * dy
			else
				stick.x, stick.y = base.x, base.y
			end
		end
	end
end

local JoystickTouch = touch.TouchHelperFunc(function(event, stick)
	stick.m_x, stick.m_y = event.x - stick.x, event.y - stick.y
	stick.m_update = stick.m_update or timer.performWithDelay(50, StickTimer(stick), 0)
end, function(event, stick)
	local base, x, y = stick.m_base, event.x - stick.m_x, event.y - stick.m_y
	local bx, by = base.x, base.y
	local dx, dy = x - bx, y - by
	local dist_sq = dx^2 + dy^2

	if dist_sq > StickRange^2 then
		local scale = StickRange / sqrt(dist_sq)

		dx, dy = dx * scale, dy * scale
	end

	stick.x, stick.y = bx + dx, by + dy

	if abs(dx) > abs(dy) then
		dy = 0
	else
		dx = 0
	end

	AuxSendEvent(1, dx)
	AuxSendEvent(2, dy)
end, function(_, stick)
	stick.m_x, stick.m_y = nil

	AuxSendEvent(1, 0)
	AuxSendEvent(2, 0)
end)

--- DOCME
-- @pgroup group
function M.AddJoystick (group)
	local w, h = display.contentWidth, display.contentHeight
	local dw, dh = w * .13, h * .125

	local y1 = round(h * .7)
	local y2 = round(y1 + dh + h * .03)
	local x = round(w * .17)
	local jgroup = display.newGroup()

	group:insert(jgroup)

	local base = display.newCircle(jgroup, x, y2, OuterRadius)

	base:setFillColor(.2)
	base:setStrokeColor(.7, .7)

	local stick = display.newCircle(jgroup, x, y2, InnerRadius)

	stick:addEventListener("touch", JoystickTouch)
	stick:setFillColor(.4)
	stick:setStrokeColor(0)

	base.strokeWidth, stick.strokeWidth = 2, 2

	stick.m_base = base
end

return M