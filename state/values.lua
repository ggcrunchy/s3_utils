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
local bind = require("tektite_core.bind")

-- Exports --
local M = {}

-- Value type lookup table --
local ValueList


local Before = bind.BroadcastBuilder_Helper("loading_level")

--- DOCME
function M.AddValue (info, wname)
	local wlist = wname or "loading_level"
	local value = assert(ValueList[info.type], "Invalid value")(info, wlist)

	if info.before then
		local body = value

		function value ()
			Before(value, "fire", false)

			return body()
		end

		Before.Subscribe(value, info.before, wlist)
	end

	bind.Publish(wlist, value, info.uid, "get")

	return value
end

--
local function NewTag (vtype, result, ...)
	if result and result ~= "extend" then
		return result, ...
	else
		local events, actions, sources, targets = { before = Before }, nil, { [vtype] = "get" }

		if result == "extend" then
			local w1, w2, w3, w4 = ...

			if w1 then
				for k in adaptive.IterSet(w1) do
					events[k] = true
				end
			end

			for k in adaptive.IterSet(w2) do
				w2 = adaptive.AddToSet(w2, k)
			end

			if w3 then
				for vtype, list in pairs(w3) do
					for k in adaptive.IterSet(list) do
						sources[vtype] = adaptive.AddToSet(sources[vtype], k)
					end
				end
			end

			if w4 then
				targets = {}

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

		-- Build --
		-- arg1: Level
		-- arg2: Original entry
		-- arg3: Action to build
		if what == "build" then
			-- ANYTHING?

		-- Enumerate Defaults --
		-- arg1: Defaults
		elseif what == "enum_defs" then
			-- extended by derived types

		-- Enumerate Properties --
		-- arg1: Dialog
		elseif what == "enum_props" then
			arg1:StockElements()
			arg1:AddSeparator()

		-- Get Tag --
		elseif what == "get_tag" then
			return event("get_tag") or vtype

		-- New Tag --
		elseif what == "new_tag" then
			return NewTag(vtype, event("new_tag"))

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