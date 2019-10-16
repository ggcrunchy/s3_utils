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
local extend = require("s3_utils.state.extend")

-- Exports --
local M = {}

--
--
--

-- Value type lookup table --
local ValueList, Categories

-- --
local Before = bind.BroadcastBuilder_Helper(nil)

--- DOCME
function M.AddValue (info, params)
	local pubsub = params.pubsub
	local value, how = assert(ValueList[info.type], "Invalid value").make(info, pubsub)

	if how ~= "no_before" and info.before then -- some values want it but must handle it specially
		local body = value

		function value ()
			Before(value)

			return body()
		end

		Before.Subscribe(value, info.before, pubsub)
	end

	bind.Publish(pubsub, value, info.uid, "get")

	return value
end

-- --
local PrepValue = extend.PrepLinkHelper(function(value, other, vsub, other_sub)
	if vsub == "before" then
		bind.AddId(value, vsub, other.uid, other_sub)
	end
end, "prep_link:value")

--
local function NewTag (vtype, result, ...)
	if result and result ~= "extend" and result ~= "extend_properties" then
		return result, ...
	else
		return "sources_and_targets", extend.NewTag(result, "before", nil, { [vtype] = "get" }, nil, "no_before", ...)
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
	local cons = ValueList[type].editor

	if cons then
		local event, vtype = cons--[[("editor_event")]] or NoEvent, assert(ValueList[type].value_type--[[cons("value_type")]], "No value type specified")
-- ^^^ URGH
		-- Enumerate Properties --
		-- arg1: Dialog
		if what == "enum_props" then
			arg1:StockElements()
			arg1:AddSeparator()

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.before = "On(before)"
	-- TODO: replace this with a "DoThenGet" object...
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
			return PrepValue(arg2.type, event, arg1, arg2)
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

	return types, Categories
end

-- Install various types of values.
ValueList, Categories = require_ex.DoList("config.Values")

return M