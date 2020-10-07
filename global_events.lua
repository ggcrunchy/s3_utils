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

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local bind = require("solar2d_utils.bind")
local call = require("solar2d_utils.call")
local config = require("config.GlobalEvents")
local object_vars = require("config.ObjectVariables")

-- Solar2D globals --
local Runtime = Runtime
local timer = timer

-- Exports --
local M = {}

--
--
--

-- --
local Actions = {}

-- --
local OutProperties = config.out_properties

local EventNonce

-- Deferred global event <-> event bindings
local GetEvent = {}

for _, v in ipairs(config.events) do
	GetEvent[v] = call.NewDispatcher()--bind.BroadcastBuilder_Helper()

	Runtime:addEventListener(v, function()
		GetEvent[v]:DispatchForObject(EventNonce)
	end)
end

--- DOCME
function M.make--[[AddEvents]] (--[[events]]info, params)
	local psl = params:GetPubSubList()

	for k, v in pairs(GetEvent) do
		-- could lazily add nonce?
	--	v.Subscribe(EventNonce, events and events[k], pubsub)
		psl:Subscribe(--[[events and events]]info[k], v:GetAdder(), EventNonce)
	end

	for k in adaptive.IterSet(--[[events and events]]info.actions) do
		if k == "win" then
			params.win = "custom" -- TODO! this is a lazy hack :P
		end
		--[[bind.]]psl:Publish(--[[pubsub, ]]Actions[k], --[[events]]info.uid, k)
	end

	object_vars.PublishProperties(psl, --[[events and events]]info.props, OutProperties, --[[events and events]]info.uid)
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
function M.editor (_, what, arg1)
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


for _, v in ipairs(config.actions) do
	Actions[v] = function()
		-- TODO?
	end
end

local function EnterFrame ()
	GetEvent.enter_frame:DispatchForObject(EventNonce)
end

for k, v in pairs{
	enter_level = function()
		EventNonce = {}
	end,

	leave_level = function()
		Runtime:removeEventListener("enterFrame", EnterFrame)

		timer.performWithDelay(0, function()
			EventNonce = nil -- timer probably overkill
		end)
	end,

	ready_to_go = function()
		for _ in GetEvent.enter_frame:IterateFunctionsForObject--[[.Iter]](EventNonce) do
			Runtime:addEventListener("enterFrame", EnterFrame)

			break
		end
	end
} do
	Runtime:addEventListener(k, v)
end

return M