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

-- Modules --
local array_index = require("tektite_core.array.index")
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local display = display
local easing = easing
local transition = transition

-- Exports --
local M = {}

--
--
--

-- Group for action button and related icons --
local ActionGroup

-- Action icon images --
local Images

-- Sequence of actions, in touch order --
local Sequence

-- Fading icon transition --
local FadeIconParams = { tag = "action_fading" }

-- Helper to cancel a (possible) transition
local function Cancel (trans)
	if trans then
		transition.cancel(trans)

		return true
	end
end

-- Helper to extract action from the sequence
local function IndexOf (name)
	for i, v in ipairs(Sequence) do
		if v.name == name then
			return i, v
		end
	end
end

-- Current opaque icon --
local Current

-- Helper to fade icon in or out
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

-- On complete, try to advance the sequence
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
			local index = array_index.RotateIndex(index, n)

			FadeIcon(Sequence[index].icon, 1)
		end

	-- On fade in: Tell this icon to fade out shortly if other icons are in the queue.
	elseif n > 1 then
		FadeIcon(icon, 0, 400)
	end

	-- The previous name was either of no use or has served its purpose.
	icon.is_fading, icon.prev = nil
end

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

-- Adds an icon reference to the sequence
local function AddIcon (item, name)
	--  Do any instances of the icon exist?
	if not item then
		-- Append a fresh shared icon state.
		local n = #Sequence

		item = { count = 0, icon = Images[name], name = name }

		Sequence[n + 1] = item

		-- If only one other type of icon was in the queue, it just became multi-icon, so
		-- kick off the fade sequence. If the queue was empty, fade the first icon in.
		if n <= 1 then
			FadeIcon(Sequence[1].icon, n == 1 and 0 or 1)
		end
	end

	item.count = item.count + 1
end

-- Removes an icon reference from the sequence
local function RemoveIcon (index, item)
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
			local prev = array_index.RotateIndex(index, #Sequence, true)

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

-- Helper to enqueue a dot image
local function MergeDotIntoSequence (dot, touch)
	local name = dot.touch_image_P or "s3_utils/assets/hud/Kick.png"
	local index, item = IndexOf(name)

	if touch then
		AddIcon(item, name)
	else
		RemoveIcon(index, item)
	end
end

-- Pulsing button transition; button scaling in or out --
local ScaleInOut, Scaling = { time = 250, transition = easing.outQuad }

-- Kick off a scale (either in or out) in the button pulse
local function ScaleActionButton (button, delta)
	Cancel(Scaling)

	ScaleInOut.xScale = 1 + delta
	ScaleInOut.yScale = 1 + delta

	button.m_scale_delta = delta

	Scaling = transition.to(button, ScaleInOut)
end

-- De-pulsing transition --
local ScaleToNormal = {
	time = 250, xScale = 1, yScale = 1,

	onComplete = function(button)
		if button.parent and button.m_touches > 0 then
			ScaleActionButton(button, -button.m_scale_delta)
		end
	end
} 

-- Completes the pulse sequence: normal -> out -> normal -> in -> normal -> out...
function ScaleInOut.onComplete (object)
	if display.isValid(object) then
		Scaling = transition.to(object, ScaleToNormal)
	end
end

-- Fading button transition --
local FadeParams = {
	tag = "action_fading", time = 200,

	onComplete = function(agroup)
		if (agroup.alpha or 0) < .5 then
			agroup.isVisible = false
		end

		agroup.is_fading = nil
	end
}

-- Show or hide the action button
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

	action.m_touches = 0

	action:setFillColor(0, 1, 0)
	action:addEventListener("touch", touch.TouchHelperFunc(do_actions))

	ActionGroup.isVisible = false

	-- Create a fresh action sequence.
	Images = setmetatable({}, ImagesMT)
	Sequence = {}
end

for k, v in pairs{
	-- Leave Level --
	leave_level = function()
		transition.cancel("action_fading")

		ActionGroup, Current, Images, Sequence = nil
	end,

	-- Touching Dot --
	touching_dot = function(event)
		local action = ActionGroup[1]
		local ntouch = action.m_touches

		-- If this is the first dot being touched (the player might be overlapping several),
		-- bring the action button into view.
		if event.is_touching and ntouch == 0 then
			ScaleActionButton(action, .1)
			ShowAction(true)
		end

		-- Add or remove the dot from the action sequence.
		MergeDotIntoSequence(event.dot, event.is_touching)

		-- Update the touched dot tally. If this was the last one being touched, hide the
		-- action button.
		ntouch = ntouch + (event.is_touching and 1 or -1)

		if ntouch == 0 then
			ShowAction(false)
		end

		action.m_touches = ntouch
	end
} do
	Runtime:addEventListener(k, v)
end

return M