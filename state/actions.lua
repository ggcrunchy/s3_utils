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

-- Modules --
local require_ex = require("tektite_core.require_ex")
local adaptive = require("tektite_core.table.adaptive")
local bind = require("tektite_core.bind")
local table_funcs = require("tektite_core.table.funcs")

-- Exports --
local M = {}

-- Action type lookup table --
local ActionList

-- --
local Next = bind.BroadcastBuilder_Helper(nil)

-- --
local NamedSources = table_funcs.Weak("v") 

--- DOCME
function M.AddAction (info, wname)
	local wlist, action = wname or "loading_level"
	local body, how = assert(ActionList[info.type], "Invalid action")(info, wlist)

	if not body then
		function action ()
			return Next(action)
		end
	elseif how == "no_next" then
		action = body
	else
		function action ()
			body()

			return Next(action)
		end
	end

	if how == "named" then
		NamedSources[info.name] = action
	end

	Next.Subscribe(action, info.next, wlist)

	bind.Publish(wlist, action, info.uid, "fire")

	return action
end

--- DOCME
function M.CallNamedSource (name, what)
	local action = NamedSources[name]

	return action and action(what)
end

--
local function LinkAction (action, other, asub, other_sub)
	if asub == "next" then
		bind.AddId(action, asub, other.uid, other_sub)
	end
end

local PrepLinkFuncs = {}

local function LinkActionEx (action, other, asub, other_sub, links)
	if not PrepLinkFuncs[action.type](action, other, asub, other_sub, links) then
		LinkAction(action, other, asub, other_sub)
	end
end

--
local function PopulateProperties (from)
	if from then
		local props = {}

		for vtype, list in pairs(from) do
			for k in adaptive.IterSet(list) do
				props[vtype] = adaptive.AddToSet(props[vtype], k)
			end
		end

		return props
	end
end

--
local function NewTag (result, ...)
	if result and result ~= "extend" and result ~= "extend_properties" then
		return result, ...
	else
		local events, actions, sources, targets = "next", "fire"

		if result then
			local w1, w2, w3, w4

			if result == "extend" then
				w1, w2, w3, w4 = ...
			else
				w3, w4 = ...
			end

			if w1 then
				if adaptive.InSet(w1, "no_next") then
					events = nil
				end

				for k in adaptive.IterSet(w1) do
					if k ~= "no_next" then
						events = adaptive.AddToSet(events, k)
					end
				end
			end

			for k in adaptive.IterSet(w2) do
				actions = adaptive.AddToSet(actions, k)
			end

			sources, targets = PopulateProperties(w3), PopulateProperties(w4)
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

		-- Enumerate Properties --
		-- arg1: Dialog
		if what == "enum_props" then
			arg1:StockElements()
			arg1:AddSeparator()

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.fire = "Do action"
			arg1.next = "Follow-up"

		-- Get Tag --
		elseif what == "get_tag" then
			return event("get_tag") or "action"

		-- New Tag --
		elseif what == "new_tag" then
			return NewTag(event("new_tag"))

		-- Prep Link --
		-- arg1: Level
		-- arg2: Built
		elseif what == "prep_link" then
			if not PrepLinkFuncs[arg2.type] then
				local func, how = event("prep_link:action", LinkAction, arg1, arg2)

				if how == "complete" then
					return func
				elseif func then
					PrepLinkFuncs[arg2.type] = func

					return LinkActionEx
				else
					return LinkAction
				end
			end
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