--- Common functionality for various global game events.
--
-- TODO: Compare, contrast other event stuff?

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
local ipairs = ipairs
local pairs = pairs
local rawequal = rawequal

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local bind = require("corona_utils.bind")
local call = require("corona_utils.call")
local config = require("config.GlobalEvents")
local object_vars = require("config.ObjectVariables")

-- Corona globals --
local Runtime = Runtime
local timer = timer

-- Exports --
local M = {}

-- --
local Actions = {}

-- --
local OutProperties = config.out_properties

-- --
local Defaults, EventNonce

-- Deferred global event <-> event bindings
local GetEvent = {}

for _, v in ipairs(config.events) do
	GetEvent[v] = call.NewDispatcher()--bind.BroadcastBuilder_Helper()

	Runtime:addEventListener(v, function()
		GetEvent[v]:DispatchForObject(EventNonce)

		local def = Defaults and Defaults[v]

		if def then
			Actions[def]()
		end
	end)
end

--- DOCME
function M.AddEvents (events, params)
	local ps_list = params.ps_list

	--
	for k, v in pairs(GetEvent) do
	--	v.Subscribe(EventNonce, events and events[k], pubsub)
		ps_list:Subscribe(events and events[k], v:GetAdder(), EventNonce)
	end
	
	--
	for k in adaptive.IterSet(events and events.actions) do
		--[[bind.]]ps_list:Publish(--[[pubsub, ]]Actions[k], events.uid, k)
	end

	object_vars.PublishProperties(ps_list, events and events.props, OutProperties, events and events.uid)

	--
	if not adaptive.InSet(events and events.actions, "win") then
		Defaults = { all_dots_removed = "win" }
	end
end

--
local function LinkGlobal (global, other, gsub, osub)
	local helper = bind.PrepLink(global, other, gsub, osub)

	helper("try_actions", Actions)
	helper("try_events", GetEvent)
	helper("try_out_properties", OutProperties)
	helper("commit")
end

--- DOCME
function M.EditorEvent (_, what, arg1)
	-- Get Link Grouping --
	if what == "get_link_grouping" then
		return {
			{ text = "ACTIONS", font = "bold", color = "actions" }, -- filled in automatically
			{ text = "OUT-PROPERTIES", font = "bold", color = "props", is_source = true }, "random", "time", -- TODO: configurable...
			{ text = "EVENTS", font = "bold", color = "events", is_source = true } -- filled in automatically
		}

	-- Get Tag --
	elseif what == "get_tag" then
		return "global"

	-- New Tag --
	elseif what == "new_tag" then
		return "sources_and_targets", GetEvent, Actions, object_vars.UnfoldPropertyFunctionsAsTagReadyList(OutProperties)

	-- Prep Link --
	elseif what == "prep_link" then
		return LinkGlobal
	end
end

--
for _, v in ipairs(config.actions) do
	local list = {}

	Actions[v] = function(what, func)
		if rawequal(what, Actions) then -- extend action
			list[#list + 1] = func
		else
			for _, action in ipairs(list) do
				action()
			end
		end
	end
end

--- DOCME
function M.ExtendAction (name, func)
	local actions = Actions[name]

	if actions then
		actions(Actions, func)
	end
end

local function EnterFrame ()
	GetEvent.enter_frame(EventNonce)
end

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function()
		EventNonce = {}
	end,

	-- Leave Level --
	leave_level = function()
		Runtime:removeEventListener("enterFrame", EnterFrame)

		timer.performWithDelay(0, function()
			EventNonce, Defaults = nil
		end)
	end,

	-- Ready To Go --
	ready_to_go = function()
		for _ in GetEvent.enter_frame:IterateFunctionsForObject--[[.Iter]](EventNonce) do
			Runtime:addEventListener("enterFrame", EnterFrame)

			break
		end
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M