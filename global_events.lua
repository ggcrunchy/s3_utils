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
local bind = require("tektite_core.bind")
local config = require("config.GlobalEvents")
local state_vars = require("config.StateVariables")

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
local Defaults, Events

-- Deferred global event <-> event bindings
local GetEvent = {}

for _, v in ipairs(config.events) do
	GetEvent[v] = bind.BroadcastBuilder(v)

	Runtime:addEventListener(v, function()
		--
		for _, event in bind.IterEvents(Events[v]) do
			event("fire", false)
		end

		--
		local def = Defaults and Defaults[v]

		if def then
			Actions[def]("fire", false)
		end
	end)
end

--- DOCME
function M.AddEvents (events)
	--
	for k, v in pairs(GetEvent) do
		bind.Subscribe("loading_level", events and events[k], v, Events)
	end
	
	--
	local actions = events and events.actions

	for k in adaptive.IterSet(actions) do
		bind.Publish("loading_level", Actions[k], events.uid, k)
	end

	state_vars.PublishProperties(events.props, OutProperties, events.uid)

	--
	if not adaptive.InSet(actions, "win") then
		Defaults = { all_dots_removed = "win" }
	end
end

--
local function LinkGlobal (global, other, gsub, osub)
	bind.LinkActionsEventsAndProperties(global, other, gsub, osub, GetEvent, Actions, "actions", OutProperties, "props")
end

--- DOCME
function M.EditorEvent (_, what)
	-- Get Tag --
	if what == "get_tag" then
		return "global"

	-- New Tag --
	elseif what == "new_tag" then
		return "sources_and_targets", GetEvent, Actions, state_vars.UnfoldPropertyFunctionsAsTagReadyList(OutProperties)

	-- Prep Link --
	elseif what == "prep_link" then
		return LinkGlobal
	end
end

--
for _, v in ipairs(config.actions) do
	local list = {}

	Actions[v] = function(what, func)
		-- Extend Action --
		if rawequal(what, Actions) then
			list[#list + 1] = func

		-- Fire --
		elseif what == "fire" then
			for _, action in ipairs(list) do
				action()
			end

		-- Is Done? --
		elseif what == "is_done" then
			return true
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
	for _, event in bind.IterEvents(GetEvent.enter_frame) do
		event("fire", false)
	end
end

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function()
		Events = {}

		if GetEvent.enter_frame and GetEvent.enter_frame("n") > 0 then
			Runtime:addEventListener("enterFrame", EnterFrame)
		end
	end,

	-- Leave Level --
	leave_level = function()
		Runtime:removeEventListener("enterFrame", EnterFrame)

		timer.performWithDelay(0, function()
			Events, Defaults = nil
		end)
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M