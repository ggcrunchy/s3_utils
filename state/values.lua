--- Objects that represent value getters.

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
local bind = require("corona_utils.bind")

-- Exports --
local M = {}

-- Value type lookup table --
local ValueList

local Before = bind.BroadcastBuilder_Helper("loading_level")

--- DOCME
function M.AddValue (info, wname)
	local wlist = wname or "loading_level"
	local value, how = assert(ValueList[info.type], "Invalid value")(info, wlist)

	if how ~= "no_before" and info.before then -- some values want it but must handle it specially
		local body = value

		function value ()
			Before(value)

			return body()
		end

		Before.Subscribe(value, info.before, wlist)
	end

	bind.Publish(wlist, value, info.uid, "get")

	return value
end

--
local function LinkValue (value, other, vsub, other_sub)
	if vsub == "before" then
		bind.AddId(value, vsub, other.uid, other_sub)
	end
end

local PrepLinkFuncs = {}

local function LinkValueEx (value, other, vsub, other_sub, links)
	if not PrepLinkFuncs[value.type](value, other, vsub, other_sub, links) then
		LinkValue(value, other, vsub, other_sub)
	end
end

--
local function PopulateProperties (from, to)
	if from then
		to = to or {}

		for vtype, list in pairs(from) do
			for k in adaptive.IterSet(list) do
				to[vtype] = adaptive.AddToSet(to[vtype], k)
			end
		end
	end

	return to
end

--
local function NewTag (vtype, result, ...)
	if result and result ~= "extend" and result ~= "extend_properties" then
		return result, ...
	else
		local events, actions, sources, targets = "before", nil, { [vtype] = "get" }

		if result then
			local w1, w2, w3, w4

			if result == "extend" then
				w1, w2, w3, w4 = ...
			else
				w3, w4 = ...
			end

			if w1 then
				if adaptive.InSet(w1, "no_before") then
					events = nil
				end

				for k in adaptive.IterSet(w1) do
					if k ~= "no_before" then
						events = adaptive.AddToSet(events, k)
					end
				end
			end

			for k in adaptive.IterSet(w2) do
				actions = adaptive.AddToSet(actions, k)
			end

			sources, targets = PopulateProperties(w3, sources), PopulateProperties(w4, nil)
		end

		return "sources_and_targets", events, actions, sources, targets
	end
end

--
local function NoEvent () end

--- Handler for value-related events sent by the editor.
-- @string type Value type, as listed by @{GetTypes}.
-- @string what Name of event.
-- @param arg1 Argument #1.
-- @param arg2 Argument #2.
-- @param arg3 Argument #3.
-- @return Result(s) of the event, if any.
function M.EditorEvent (type, what, arg1, arg2, arg3)
	local cons = ValueList[type]

	if cons then
		local event, vtype = cons("editor_event") or NoEvent, assert(cons("value_type"), "No value type specified")

		-- Enumerate Properties --
		-- arg1: Dialog
		if what == "enum_props" then
			arg1:StockElements()
			arg1:AddSeparator()

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.before = "On(before)"
	
		-- Get Tag --
		elseif what == "get_tag" then
			return event("get_tag") or vtype

		-- New Tag --
		elseif what == "new_tag" then
			return NewTag(vtype, event("new_tag"))

		-- Prep Link --
		-- arg1: Level
		-- arg2: Built
		elseif what == "prep_link" then
			if not PrepLinkFuncs[arg2.type] then
				local func, how = event("prep_link:value", LinkValue, arg1, arg2)

				if how == "complete" then
					return func
				elseif func then
					PrepLinkFuncs[arg2.type] = func

					return LinkValueEx
				else
					return LinkValue
				end
			end

		-- Verify --
		elseif what == "verify" then
			-- chase down loops?
		end

		return event(what, arg1, arg2, arg3)
	end
end

--- Getter.
-- @treturn {string,...} Unordered list of value type names.
function M.GetTypes ()
	local types = {}

	for k in pairs(ValueList) do
		types[#types + 1] = k
	end

	return types
end

-- Install various types of values.
ValueList = require_ex.DoList("config.Values")

-- Export the module.
return M