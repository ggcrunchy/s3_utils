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
local bind = require("corona_utils.bind")
local collision = require("corona_utils.collision")
local operators = require("bitwise_ops.operators")
local tile_maps = require("s3_utils.tile_maps")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- --
local Triggers

-- --
local Events = {}

for _, v in ipairs{ "on_enter", "on_leave" } do
	Events[v] = bind.BroadcastBuilder_Helper("loading_level")
end

--
local function Enter (trigger)
	if not trigger.off then
		trigger.off = trigger.deactivate

		Events.on_enter(trigger)
	end
end

--
local function Leave (trigger)
	if not trigger.off then
		Events.on_leave(trigger)
	end
end

-- --
local Actions = {
	-- Play --
	do_enter = function(trigger)
		return function()
			return Enter(trigger)
		end
	end,

	-- Pause --
	do_leave = function(trigger)
		return function()
			return Leave(trigger)
		end
	end,

	-- Resume --
	do_impulse = function(trigger)
		return function()
			Enter(trigger)

			return Leave(trigger)
		end
	end
}

-- --
local FlagGroups = { "player", "enemy", "projectile" }

--- DOCME
function M.AddTrigger (group, info)
	--
	local trigger, detect = { deactivate = info.deactivate, restore = info.restore }, info.detect_when

	if detect > 0 then
		local flags, handles = 0, {}

		for _, name in ipairs(FlagGroups) do
			local bits = operators.band(detect, 0x3)

			if bits ~= 0 then
				flags = flags + collision.FilterBits(name)

				if bits == 0x3 then
					handles[name] = "both"
				else
					handles[name] = bits == 0x1 and "began" or "ended"
				end
			end

			detect = .25 * (detect - bits)
		end

		-- 
		local w, h = tile_maps.GetSizes()
		local rect = display.newRect(group, (info.col - .5) * w, (info.row - .5) * h, w, h)

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

	--
	for k, event in pairs(Events) do
		event.Subscribe(trigger, info[k])
	end

	--
	for k in adaptive.IterSet(info.actions) do
		bind.Publish("loading_level", Actions[k](trigger), info.uid, k)
	end

	--
	Triggers[#Triggers + 1] = trigger
end

--
local function LinkTrigger (trigger, other, tsub, osub)
	local helper = bind.PrepLink(trigger, other, tsub, osub)

	helper("try_actions", Actions)
	helper("try_events", Events)
	helper("commit")
end

--- DOCME
function M.EditorEvent (_, what, arg1, arg2)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Item to build
	if what == "build" then
		-- TODO: Versioning to keep the bitfield in sync?

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.deactivate = false
		arg1.detect_when = 0x3
		arg1.restore = true

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:StockElements()
		arg1:AddSeparator()
		arg1:AddBitfield{
			text = "Detect when?", strs = {
				"player enter", "player leave", "enemy enter", "enemy leave", "projectile enter", "projectile leave"
			}, value_name = "detect_when"
		}
		arg1:AddCheckbox{ text = "Deactivate on enter?", value_name = "deactivate" }

		local restore_section = arg1:BeginSection()

		arg1:AddCheckbox{ text = "Restore on reset?", value_name = "restore" }
		arg1:EndSection()

		--
		arg1:SetStateFromValue_Watch(restore_section, "deactivate")
	-- Get Link Grouping --
	elseif what == "get_link_grouping" then
		return {
			{ text = "ACTIONS", font = "bold", color = "actions" }, "do_enter", "do_leave", "do_impulse",
			{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "on_enter", "on_leave"
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.on_enter = "On(enter)"
		arg1.on_leave = "On(leave)"
		arg1.do_enter = "Enter"
		arg1.do_leave = "Leave"
		arg1.do_impulse = "Impulse"

	-- Get Tag --
	elseif what == "get_tag" then
		return "trigger"

	-- New Tag --
	elseif what == "new_tag" then
		return "sources_and_targets", Events, Actions

	-- Prep Link --
	elseif what == "prep_link" then
		return LinkTrigger
	end
end

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function()
		Triggers = {}
	end,

	--
	leave_level = function()
		Triggers = nil
	end,

	-- Reset Level --
	reset_level = function()
		for _, trigger in ipairs(Triggers) do
			if trigger.restore then
				trigger.off = false
			end
		end
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M