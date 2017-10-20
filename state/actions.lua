--- Objects that represent actions.

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
local pairs = pairs
local rawequal = rawequal

-- Modules --
local require_ex = require("tektite_core.require_ex")
local adaptive = require("tektite_core.table.adaptive")
local bind = require("tektite_core.bind")

-- Exports --
local M = {}

-- Action type lookup table --
local ActionList

-- --
local Events = {}

for _, v in ipairs{ "instead", "next" } do
	Events[v] = bind.BroadcastBuilder_Helper("loading_level")
end

--- DOCME
function M.AddAction (info, wname)
	local wlist, can_fire, instead, next = wname or "loading_level"
	local body, proxy = assert(ActionList[info.type], "Invalid action")(info), {}

	local function action (what, arg)
		-- Resolve the action itself.
		if what == "fire" then
			if can_fire and not can_fire() then
				return Events.instead(proxy, "fire", false)
			else
				body()

				return Events.next(proxy, "fire", false)
			end
		elseif what == "is_done" then
			return true

		-- Otherwise, bind any control flow state.
		elseif rawequal(arg, proxy) then
			can_fire = what
		end
	end

	--
	for k, event in pairs(Events) do
		event.Subscribe(proxy, info[k], wlist)
	end

	bind.Subscribe(wlist, info.can_fire, action, proxy)

	--
	bind.Publish(wlist, action, info.uid, "fire")

	return action
end

--
local function LinkAction (action, other, sub, other_sub)
	if sub == "instead" or sub == "next" then
		bind.AddId(action, sub, other.uid, other_sub)
	end

	-- TODO: anything necessary for "fire"?
	-- 
	--[[
	if sub == "to" or (sub == "from" and not warp.to) then
		if sub == "to" and other.type ~= "warp" then
			bind.AddId(warp, "to", other.uid, other_sub)
		else
			warp.to = other.uid
		end
	end]]
end

--
local function NewTag (result, ...)
	if result and result ~= "extend" then
		return result, ...
	else
		local events, actions, sources, targets = Events, "fire", nil, { boolean = "can_fire" }

		if result == "extend" then
			local w1, w2, w3, w4 = ...

			if w1 then
				local events = {}

				for k, v in pairs(Events) do
					events[k] = v
				end

				for k in adaptive.IterSet(w1) do
					events[k] = true
				end
			end

			for k in adaptive.IterSet(w2) do
				w2 = adaptive.AddToSet(w2, k)
			end

			if w3 then
				sources = {}

				for vtype, list in pairs(w3) do
					for k in adaptive.IterSet(list) do
						sources[vtype] = adaptive.AddToSet(sources[vtype], k)
					end
				end
			end

			if w4 then
				for vtype, list in pairs(w4) do
					for k in adaptive.IterSet(list) do
						targets[vtype] = adaptive.AddToSet(targets[vtype], k)
					end
				end
			end
		end

		return "sources_and_targets", events, actions, sources, targets
	end
end

--
local function NoEvent () end

--- Handler for action-related events sent by the editor.
-- @string type Action type, as listed by @{GetTypes}.
-- @string what Name of event.
-- @param arg1 Argument #1.
-- @param arg2 Argument #2.
-- @param arg3 Argument #3.
-- @return Result(s) of the event, if any.
function M.EditorEvent (type, what, arg1, arg2, arg3)
	local cons = ActionList[type]

	if cons then
		local event = cons("editor_event") or NoEvent

		-- Build --
		-- arg1: Level
		-- arg2: Original entry
		-- arg3: Action to build
		if what == "build" then
			-- 

		-- Enumerate Defaults --
		-- arg1: Defaults
		elseif what == "enum_defs" then
			-- link to action object (more likely, that should extend this)
			-- then / else links
			-- "then" condition

		-- Enumerate Properties --
		-- arg1: Dialog
		elseif what == "enum_props" then
			arg1:StockElements()
			arg1:AddSeparator()

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.fire = "Kick off this action and anything that follows"
			arg1.can_fire = "Can this action fire? (default true)"
			arg1.next = "Follow-up actions or events, after firing"
			arg1.instead = "Actions or events to do instead of firing"

		-- Get Tag --
		elseif what == "get_tag" then
			return event("get_tag") or "action"

		-- New Tag --
		elseif what == "new_tag" then
			return NewTag(event("new_tag"))
			-- TODO: property getter narratives could have something to kick off action before reading

		-- Prep Link --
		elseif what == "prep_link" then
			return event("prep_link", LinkAction) or LinkAction
		
		-- Verify --
		elseif what == "verify" then
			-- COMMON STUFF...
			-- if first in chain, follow it and see if we loop
				-- if so, fail if no custom conditions exist along the way
		end

		return event(what, arg1, arg2, arg3)
	end
end

--- Getter.
-- @treturn {string,...} Unordered list of action type names.
function M.GetTypes ()
	local types = {}

	for k in pairs(ActionList) do
		types[#types + 1] = k
	end

	return types
end

-- Install various types of actions.
ActionList = require_ex.DoList("config.Actions")

-- Export module.
return M