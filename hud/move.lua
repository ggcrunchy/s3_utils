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
local min = math.min
local sqrt = math.sqrt

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

local AxisEvent = { name = "axis", axis = {}, device = { type = "joystick" } } -- cf. corona_utils.device.AxisToKey()

local StickRange = 75

local function AuxSendEvent (num, value)
	AxisEvent.axis.number, AxisEvent.normalizedValue = num, value

	Runtime:dispatchEvent(AxisEvent)
end

local function SendAxisEvents (dx, dy)
	AuxSendEvent(1, dx / StickRange)
	AuxSendEvent(2, dy / StickRange)
end

local function StickTimer (stick)
	return function(event)
		if not display.isValid(stick) then
			timer.cancel(event.source)
		else
			local base = stick.m_base
			local dx, dy = stick.x - base.x, stick.y - base.y

			if stick.m_x then
				SendAxisEvents(dx, dy)
			else
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
end
--[[

function M.newStick(startAxis, innerRadius, outerRadius)

  startAxis = startAxis or 1
  innerRadius, outerRadius = innerRadius or 48, outerRadius or 96
  local instance = display.newGroup()

  local outerArea 
  if type(outerRadius) == "number" then
    outerArea = display.newCircle( instance, 0,0, outerRadius )
    outerArea.strokeWidth = 8
    outerArea:setFillColor( 0.2, 0.2, 0.2, 0.9 )
    outerArea:setStrokeColor( 1, 1, 1, 1 )
  else
    outerArea = display.newImage( instance, outerRadius, 0,0 )
    outerRadius = (outerArea.contentWidth + outerArea.contentHeight) * 0.25
  end

  local joystick 
  if type(innerRadius) == "number" then
    joystick = display.newCircle( instance, 0,0, innerRadius )
    joystick:setFillColor( 0.4, 0.4, 0.4, 0.9 )
    joystick.strokeWidth = 6
    joystick:setStrokeColor( 1, 1, 1, 1 )
  else
    joystick = display.newImage( instance, innerRadius, 0,0 )
    innerRadius = (joystick.contentWidth + joystick.contentHeight) * 0.25
  end  

  -- where should joystick motion be stopped?
  local stopRadius = outerRadius - innerRadius

  function joystick:touch(event)
    local phase = event.phase
    if phase=="began" or (phase=="moved" and self.isFocus) then
      if phase == "began" then
        stage:setFocus(event.target, event.id)
        self.eventID = event.id
        self.isFocus = true
      end
      local parent = self.parent
      local posX, posY = parent:contentToLocal(event.x, event.y)
      local angle = -math.atan2(posY, posX)
      local distance = math.sqrt((posX*posX)+(posY*posY))

      if( distance >= stopRadius ) then
        distance = stopRadius
        self.x = distance*math.cos(angle)
        self.y = -distance*math.sin(angle)
      else
        self.x = posX
        self.y = posY
      end
    else
      self.x = 0
      self.y = 0
      stage:setFocus(nil, event.id)
      self.isFocus = false
    end
    instance.axisX = self.x / stopRadius
    instance.axisY = self.y / stopRadius
    local axisEvent
    if not (self.y == (self._y or 0)) then
      axisEvent = {name = "axis", axis = { number = startAxis }, normalizedValue = instance.axisX }
      Runtime:dispatchEvent(axisEvent)
    end
    if not (self.x == (self._x or 0))  then 
      axisEvent = {name = "axis", axis = { number = startAxis+1 }, normalizedValue = instance.axisY }
      Runtime:dispatchEvent(axisEvent)
    end
    self._x, self._y = self.x, self.y
    return true
  end

  function instance:activate()
    self:addEventListener("touch", joystick )
    self.axisX = 0
    self.axisY = 0
  end

  function instance:deactivate()
    stage:setFocus(nil, joystick.eventID)
    joystick.x, joystick.y = outerArea.x, outerArea.y
    self:removeEventListener("touch", self.joystick )
    self.axisX = 0
    self.axisY = 0
  end

  instance:activate()
  return instance
end


]]
-- Partially adapted from ponywolf's vjoy
local InnerRadius, OuterRadius = 48, 96

local JoystickTouch = touch.TouchHelperFunc(function(event, stick)
	stick.m_x, stick.m_y = event.x - stick.x, event.y - stick.y
	stick.m_update = stick.m_update or timer.performWithDelay(50, StickTimer(stick), 0)
end, function(event, stick)
	local base, x, y = stick.m_base, event.x - stick.m_x, event.y - stick.m_y
	local bx, by = base.x, base.y
	local dx, dy = x - bx, y - by
	local dist_sq = dx^2 + dy^2

	if dist_sq > StickRange * StickRange then
		local scale = StickRange / sqrt(dist_sq)

		x, y = bx + dx * scale, by + dy * scale
	end

	stick.x, stick.y = x, y
end, function(_, stick)
	stick.m_x, stick.m_y = nil

	SendAxisEvents(0, 0)
end)

--- DOCME
-- @pgroup group
-- @callable on_touch
function M.AddMoveButtons (group, on_touch)
	local w, h = display.contentWidth, display.contentHeight
	local dw, dh = w * .13, h * .125

	local y1 = h * .7
	local y2 = y1 + dh + h * .03
	local x = w * .17
	local jgroup = display.newGroup()

	group:insert(jgroup)

	local base = display.newCircle(jgroup, x, y2, StickRange)

	base:setFillColor(.2)
	base:setStrokeColor(.7, .7)

	local stick = display.newCircle(jgroup, x, y2, 50)

	stick:addEventListener("touch", JoystickTouch)
	stick:setFillColor(.4)
	stick:setStrokeColor(0)

	base.strokeWidth, stick.strokeWidth = 2, 2

	stick.m_base = base
end

-- Export the module.
return M