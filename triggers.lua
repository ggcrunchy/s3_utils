--- Functionality common to triggers, which help to couple events to character movements.

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
local pairs = pairs
local ipairs = ipairs

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local collision = require("solar2d_utils.collision")
local multicall = require("solar2d_utils.multicall")
local tile_layout = require("s3_utils.tile_layout")

-- Plugins --
local bit = require("plugin.bit")

-- Solar2D globals --
local display = display

-- Exports --
local M = {}

--
--
--

local Actions, Events = {}, {}

--
--
--

local function Enter (trigger)
	if not trigger.off then
		trigger.off = trigger.deactivate

		Events.on_enter:DispatchForObject(trigger)
	end
end

function Actions:do_enter ()
	return function()
		return Enter(self)
	end
end

--
--
--

local function Leave (trigger)
	if not trigger.off then
		Events.on_leave:DispatchForObject(trigger)
	end
end

function Actions:do_leave ()
	return function()
		return Leave(self)
	end
end

--
--
--

function Actions:do_impulse ()
	return function()
		Enter(self)

		return Leave(self)
	end
end

--
--
--

for _, v in ipairs{ "on_enter", "on_leave" } do
	Events[v] = multicall.NewDispatcher()
end

--
--
--

local BitBegan, BitEnded = 0x1, 0x2
local BitBoth = BitBegan + BitEnded

--- DOCME
function M.editor ()
	return {
		inputs = {
			bitmask = { detect_when = BitBoth },
			boolean = { deactivate = false, restore = true }
		},
		actions = Actions, events = Events
	}
end

--
--
--

local FlagGroups = { "player", "enemy", "projectile" }

local Triggers

--- DOCME
function M.make (info, params)
	local trigger, detect = { deactivate = info.deactivate, restore = info.restore }, info.detect_when

	if detect > 0 then
		local flags, handles = 0, {}

		for _, name in ipairs(FlagGroups) do
			local bits = bit.band(detect, BitBoth)

			if bits ~= 0 then
				flags = flags + collision.GetBitmask(name)

				if bits == 0x3 then
					handles[name] = "both"
				else
					handles[name] = bits == BitBegan and "began" or "ended"
				end
			end

			detect = .25 * (detect - bits)
		end

		-- 
		local w, h = tile_layout.GetSizes()
		local rect = display.newRect(params:GetLayer("things"), (info.col - .5) * w, (info.row - .5) * h, w, h)

		rect:addEventListener("collision", function(event)
			local phase, which = event.phase, handles[collision.GetType(event.other)]

			if which == "both" or which == phase then
				if phase == "began" then
					Enter(trigger)
				else
					Leave(trigger)
				end
			end
		end)

		rect.isVisible = false

		collision.MakeSensor(rect, "static", { filter = { categoryBits = flags, maskBits = 0xFFFF } })
	end

	local psl = params:GetPubSubList()

	for k, event in pairs(Events) do
		psl:Subscribe(info[k], event:GetAdder(), trigger)
	end

	for k in adaptive.IterSet(info.actions) do
		psl:Publish(Actions[k](trigger), info.uid, k)
	end

	Triggers = Triggers or {}
	Triggers[#Triggers + 1] = trigger
end

--
--
--

Runtime:addEventListener("leave_level", function()
	Triggers = nil
end)

--
--
--

Runtime:addEventListener("reset_level", function()
	for i = 1, #(Triggers or "") do
		local trigger = Triggers[i]

		if trigger.restore then
			trigger.off = false
		end
	end
end)

--
--
--

return M