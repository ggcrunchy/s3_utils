--- Action elements of the HUD.

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
local insert = table.insert
local remove = table.remove

-- Extension imports --
local indexOf = table.indexOf

-- Solar2D globals --
local display = display
local easing = easing
local native = native
local Runtime = Runtime
local transition = transition

-- Exports --
local M = {}

--
--
--

local ActionGroup

local function Touch (event)
	local button, phase = event.target, event.phase

	if phase == "began" then
		display.getCurrentStage():setFocus(button, event.id)

		button.m_touched = true

	elseif button.m_touched and (phase == "ended" or phase == "cancelled") then
		display.getCurrentStage():setFocus(button, nil)

		local cx, cy = button:localToContent(0, 0)
    local dx, dy, radius = event.x - cx, event.y - cy, button.path.radius

		if dx * dy + dy * dy < radius * radius then
			button.m_func()
		end
		-- ^^ TODO: is the underlying logic robust enough or do we need to guard this too?
		-- say for instance the player walks off and then lets go

		button.m_touched = false
	end

	return true
end

--local Current, Previous

--- DOCME
-- @pgroup group
-- @callable do_actions
function M.AddActionButton (group, do_actions)
	local w, h = display.contentWidth, display.contentHeight

	-- Add a "do actions" button.
	ActionGroup = display.newGroup()

	group:insert(ActionGroup)

	local bradius = .06 * (w + h)
	local action = display.newCircle(ActionGroup, w * .95 - bradius, h * .85 - bradius, bradius)

	action.alpha = .6
	action.strokeWidth = 3

	action.m_func, action.m_touches = do_actions, 0

	action:setFillColor(0, 1, 0)
	action:addEventListener("touch", Touch)

	ActionGroup.isVisible = false

  ActionGroup.m_list = {}
end

--
--
--

function M.GetCurrent ()
  return ActionGroup.m_list[1]
end

--
--
--

local function Cancel (trans)
	if trans then
		transition.cancel(trans)

		return true
	end
end

Runtime:addEventListener("leave_level", function()
	transition.cancel("action_fading")

	Cancel(ActionGroup and ActionGroup.m_scaling)

	ActionGroup = nil
end)

--
--
--

local function CreateIcon (name, is_text)
  local action, icon = ActionGroup[1]

  if is_text then
    icon = display.newText(name, 0, 0, native.systemFontBold, 16) -- TODO: font, size
  elseif display.isValid(name) then
    icon, name = name
  else
    icon = display.newImage(name)
  end
  
  ActionGroup:insert(icon)

  icon.x, icon.y = action.x, action.y
  icon.width, icon.height = 96, 96

  icon.name = name -- nil if name was an object, see above
  icon.ref_count = 0

  return icon
end

--
--
--

local function IsTextObject (object)
  return object._type == "TextObject"
end

local function FindIcon (name, is_text)
  for i = 2, ActionGroup.numChildren do -- ignore action button
    local object = ActionGroup[i]

    if (object.name or object) == name and IsTextObject(object) == is_text then -- cf. CreateIcon w.r.t. nil name
      return object
    end
  end
end

local function GetIconFromDot (dot)
	local name = dot.touch_image_P
	local is_text = not name

	if is_text then
		name = dot.touch_text_P or "Use"
	end

  return FindIcon(name, is_text), name, is_text
end

--
--
--

local function MergeDotIntoList (dot, touch)
	local icon, name, is_text = GetIconFromDot(dot)

  local list = ActionGroup.m_list
  local index = indexOf(list, dot)

	if touch then
    icon = icon or CreateIcon(name, is_text)

    if #list > 0 then -- do first, since...
      GetIconFromDot(list[1]).isVisible = false -- ...this...
    end

    insert(list, 1, dot)

    icon.isVisible = true -- ...and this might be the same
	else
    assert(index, "Stopped touching untracked dot")

    icon.isVisible = false -- likewise here...

    remove(list, index)

    if #list > 0 then
      GetIconFromDot(list[1]).isVisible = true -- ...with this
    end
	end
end

--
--
--

local ScaleInOut = { time = 250, transition = easing.outQuad }

local function ScaleActionButton (button, delta)
	Cancel(ActionGroup.m_scaling)

	ScaleInOut.xScale = 1 + delta
	ScaleInOut.yScale = 1 + delta

	button.m_scale_delta = delta

  ActionGroup.m_scaling = transition.to(button, ScaleInOut)
end

local ScaleToNormal = {
	time = 250, xScale = 1, yScale = 1,

	onComplete = function(button)
		if button.parent and button.m_touches > 0 then
			ScaleActionButton(button, -button.m_scale_delta)
		end
	end
} 

function ScaleInOut.onComplete (object)
	if display.isValid(object) then
    ActionGroup.m_scaling = transition.to(object, ScaleToNormal)
	end
end

local FadeParams = {
	tag = "action_fading", time = 200,

	onComplete = function(agroup)
		if agroup.alpha < .5 then
			agroup.isVisible = false
		end

		agroup.m_button_fading = nil
	end
}

local function ShowAction (show)
	local from, to = .2, 1

	if show then
		ActionGroup.isVisible = true
	else
		from, to = to, from
	end

	-- If the button was already fading, stop and keep the current alpha; otherwise, begin from
  -- some defined value. Kick off a fade (in or out) from there.
	if ActionGroup.m_button_fading then
		transition.cancel(ActionGroup)
	else
		ActionGroup.alpha = from
	end

	FadeParams.alpha, ActionGroup.m_button_fading = to, true

	transition.to(ActionGroup, FadeParams)
end

Runtime:addEventListener("touching_dot", function(event)
	local action = ActionGroup[1]
	local ntouch = action.m_touches

	if event.is_touching and ntouch == 0 then -- no others also being touched?
		ScaleActionButton(action, .1)
		ShowAction(true)
	end

	MergeDotIntoList(event.dot, event.is_touching)

	ntouch = ntouch + (event.is_touching and 1 or -1)

  assert(ntouch <= 2, "Unable to handle more than two touched dots")

	if ntouch == 0 then
		ShowAction(false)
	end

	action.m_touches = ntouch
end)

--
--
--

return M