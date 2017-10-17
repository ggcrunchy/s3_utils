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
local bind = require("tektite_core.bind")

-- Exports --
local M = {}

-- Value type lookup table --
local ValueList

--- DOCME
function M.AddValue (info, wname)
	local value = assert(ValueList[info.type], "Invalid value")(info)

	bind.Publish(wname or "loading_level", value, info.uid, "get")

	return value
end

--
local function NewTag (vtype, result, ...)
	if result then
		return result, ...
	else
		return "properties", { [vtype] = "get" }
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

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.get = "Query this value"

		-- Get Tag --
		elseif what == "get_tag" then
			return event("get_tag") or vtype

		-- New Tag --
		elseif what == "new_tag" then
			return NewTag(event("new_tag"))

		-- Prep Link --
		elseif what == "prep_link" then
			-- ANYTHING?
		
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