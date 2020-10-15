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
local abs = math.abs
local assert = assert
local ceil = math.ceil
local ipairs = ipairs
local remove = table.remove
local setmetatable = setmetatable
local type = type

-- Solar2D globals --
local display = display
local easing = easing
local native = native
local transition = transition

-- Exports --
local M = {}

--
--
--

local ActionGroup

-- Lazily add images to the action sequence --
local ImagesMT = {
	__index = function(t, name)
		local action, ai = ActionGroup[1]

		if type(name) == "string" then
			ai = display.newImage(ActionGroup, name, action.x, action.y)
		else
			ai = name

			ActionGroup:insert(ai)

			ai.x, ai.y = action.x, action.y
		end

		ai.width, ai.height, ai.alpha = 96, 96, 0

		t[name], ai.name = ai, name

		return ai
	end
}

local function Touch (event)
	local button, phase = event.target, event.phase

	if phase == "began" then
		display.getCurrentStage():setFocus(button, event.id)

		button.m_touched = true

	elseif button.m_touched and (phase == "ended" or phase == "cancelled") then
		display.getCurrentStage():setFocus(button, nil)

		local cx, cy = button:localToContent(0, 0)

		if (event.x - cx)^2 + (event.y - cy)^2 < button.path.radius^2 then
			button.m_func()
		end
		-- ^^ TODO: is the underlying logic robust enough or do we need to guard this too?
		-- say for instance the player walks off and then lets go

		button.m_touched = false
	end

	return true
end

local Images, Sequence

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

	-- Create a fresh action sequence.
	Images = setmetatable({}, ImagesMT)
	Sequence = {}
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

local Current, Scaling

Runtime:addEventListener("leave_level", function()
	transition.cancel("action_fading")

	Cancel(Scaling)

	ActionGroup, Current, Images, Scaling, Sequence = nil
end)

--
--
--

local function IndexOf (name)
	for i, v in ipairs(Sequence) do
		if v.name == name then
			return i, v
		end
	end
end

local FadeIconParams = { tag = "action_fading" }

local function FadeIcon (icon, alpha, delay)
	Current = icon

	FadeIconParams.alpha = alpha
	FadeIconParams.delay = delay or 0
	FadeIconParams.time = ceil(150 * abs(alpha - icon.alpha))

	if icon.is_fading then
		transition.cancel(icon)
	else
		icon.alpha = 1 - alpha
	end

	transition.to(icon, FadeIconParams)

	icon.is_fading = true
end

function FadeIconParams.onComplete (icon)
	local n = #Sequence

	-- No items left: kill the sequence.
	if n == 0 or not display.isValid(icon) then
		Current = nil

	-- On fade out: Try to fade in the next icon (which might be the icon itself). Ignore
	-- the icon if it is no longer in the sequence.
	elseif icon.alpha < .5 then
		local index = IndexOf(icon.prev or icon.name)

		if index then
			if index < n then
				index = index + 1
			else
				index = 1
			end

			FadeIcon(Sequence[index].icon, 1)
		end

	-- On fade in: Tell this icon to fade out shortly if other icons are in the queue.
	elseif n > 1 then
		FadeIcon(icon, 0, 400)
	end

	-- The previous name was either of no use or has served its purpose.
	icon.is_fading, icon.prev = nil
end

local function AddIconToSequence (item, name, is_text)
	--  Do any instances of the icon exist?
	if not item then
		-- Append a fresh shared icon state.
		local n, key = #Sequence, name

		if is_text then
			key = display.newText(name, 0, 0, native.systemFontBold, 16) -- TODO: font, size
		end

		item = { count = 0, icon = Images[key], name = name }

		Sequence[n + 1] = item

		-- If only one other type of icon was in the queue, it just became multi-icon, so
		-- kick off the fade sequence. If the queue was empty, fade the first icon in.
		if n <= 1 then
			FadeIcon(Sequence[1].icon, n == 1 and 0 or 1)
		end
	end

	item.count = item.count + 1
end

local function RemoveIconFromSequence (index, item)
	assert(item, "No icon for dot being untouched")

	item.count = item.count - 1

	-- Remove the state from the queue if it has no more references.
	if item.count == 0 then
		-- Is this the icon being shown?
		if item.icon == Current then
			-- Fade the icon out, but spare the effort if it's doing so already.
			if not item.is_fading or FadeIconParams.alpha > .5 then
				FadeIcon(item.icon, 0)
			end

			-- Since indices are trouble to maintain, get the name of the previous item in
			-- the sequence: this will be the reference point for the "go to next" logic,
			-- after the fade out.
			local prev = index > 1 and index - 1 or #Sequence

			item.icon.prev = index ~= prev and Sequence[prev].name

		-- Otherwise, if there were only two items, it follows that the other is being
		-- shown. If it was fading out, fade it back in instead.
		elseif #Sequence == 2 and item.is_fading and FadeIconParams.alpha < .5 then
			FadeIcon(Sequence[3 - index].icon, 1)
		end

		-- The above was easier with the sequence intact, but now the item can be removed.
		remove(Sequence, index)
	end
end

local function MergeDotIntoSequence (dot, touch)
	local name = dot.touch_image_P
	local is_text = not name

	if is_text then
		name = dot.touch_text_P or "Use"
	end

	local index, item = IndexOf(name)

	if touch then
		AddIconToSequence(item, name, is_text)
	else
		RemoveIconFromSequence(index, item)
	end
end

local ScaleInOut = { time = 250, transition = easing.outQuad }

local function ScaleActionButton (button, delta)
	Cancel(Scaling)

	ScaleInOut.xScale = 1 + delta
	ScaleInOut.yScale = 1 + delta

	button.m_scale_delta = delta

	Scaling = transition.to(button, ScaleInOut)
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
		Scaling = transition.to(object, ScaleToNormal)
	end
end

local FadeParams = {
	tag = "action_fading", time = 200,

	onComplete = function(agroup)
		if (agroup.alpha or 0) < .5 then
			agroup.isVisible = false
		end

		agroup.is_fading = nil
	end
}

local function ShowAction (show)
	local from, to = .2, 1

	if show then
		ActionGroup.isVisible = true
	else
		from, to = to, from
	end

	-- If it was already fading, stop that and use whatever its current alpha happens to
	-- be. Otherwise, begin from some defined alpha. Kick off a fade-in or fade-out.
	if ActionGroup.is_fading then
		transition.cancel(ActionGroup)
	else
		ActionGroup.alpha = from
	end

	FadeParams.alpha, ActionGroup.is_fading = to, true

	transition.to(ActionGroup, FadeParams)
end

Runtime:addEventListener("touching_dot", function(event)
	local action = ActionGroup[1]
	local ntouch = action.m_touches

	if event.is_touching and ntouch == 0 then -- no others also being touched?
		ScaleActionButton(action, .1)
		ShowAction(true)
	end

	MergeDotIntoSequence(event.dot, event.is_touching)

	ntouch = ntouch + (event.is_touching and 1 or -1)

	if ntouch == 0 then
		ShowAction(false)
	end

	action.m_touches = ntouch
end)

--
--
--

return M