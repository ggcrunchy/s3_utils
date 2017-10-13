--- Objects that represent conditions.

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
local bind = require("tektite_core.bind")

-- Exports --
local M = {}

-- Condition type lookup table --
local ConditionList

-- --
local Connectives = {
	And = function(a, b) return a and b end,
	Or = function(a, b) return a or b end,
	NAnd = function(a, b) return not a or not b end,
	NOr = function(a, b) return not a and not b end,
	Xor = function(a, b) return not a ~= not b end,
	Iff = function(a, b) return not a == not b end,
	Implies = function(a, b) return not a or b end,
	NImplies = function(a, b) return a and not b end,
	ConverseImplies = function(a, b) return a or not b end,
	NConverseImplies = function(a, b) return not a and b end
}

--- DOCME
function M.AddCondition (info)
	local condition

	--
	if info.expression then
		local logic--Parse(info.expression)

		function condition (comp, arg)
			if rawequal(arg, ConditionList) then
				logic(comp) -- TODO: check order guarantees...
			else
				return logic()
			end
		end

		bind.Subscribe("loading_level", info.conds, condition, ConditionList)

	--
	elseif info.connective then
		local connective, cond1, cond2 = Connectives[info.connective]

		function condition (comp, arg)
			if rawequal(arg, ConditionList) then
				if cond1 then -- TODO: check order guarantees
					cond2 = comp
				else
					cond1 = comp
				end
			else
				return connective(cond1(), cond2())
			end
		end

		bind.Subscribe("loading_level", info.cond1, condition, ConditionList)
		bind.Subscribe("loading_level", info.cond2, condition, ConditionList)

	--
	else
		condition = assert(ConditionList[info.type], "Invalid condition")(info)
	end

	bind.Publish("loading_level", condition, info.uid, "test")

	return condition
end

--
local function LinkCondition (condition, other, sub, other_sub)
	if sub == "cond1" or sub == "cond2" then
		condition[sub] = other.uid
	elseif sub == "conds" then
		bind.AddId(condition, "conds", other.uid, other_sub)
	end

	-- TODO: anything necessary for "test", i.e. to hook this up as boolean property?
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

--- Handler for condition-related events sent by the editor.
-- @string type Condition type, as listed by @{GetTypes}.
-- @string what Name of event.
-- @param arg1 Argument #1.
-- @param arg2 Argument #2.
-- @param arg3 Argument #3.
-- @return Result(s) of the event, if any.
function M.EditorEvent (type, what, arg1, arg2, arg3)
	local cons = ConditionList[type]

	if cons then
		-- Build --
		-- arg1: Level
		-- arg2: Original entry
		-- arg3: Action to build
		if what == "build" then
			-- 

		-- Enumerate Defaults --
		-- arg1: Defaults
		elseif what == "enum_defs" then
			-- link to condition object (more likely, that should extend this)
			-- rest will be in extensions (Binary, Complex)

		-- Enumerate Properties --
		-- arg1: Dialog
		elseif what == "enum_props" then
			arg1:StockElements("Condition", type)
			arg1:AddSeparator()

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.test = "Query this condition"
			arg1.cond1 = "Binary condition's first reference" -- TODO: move these to own stuff?
			arg1.cond2 = "Binary condition's second reference"
			arg1.conds = "Components of complex condition"

		-- Get Tag --
		elseif what == "get_tag" then
			return "condition" -- TODO: maybe simple condition, then derive from that?

		-- New Tag --
		elseif what == "new_tag" then
			-- TODO!

		-- Prep Link --
		elseif what == "prep_link" then
			return LinkCondition
		
		-- Verify --
		elseif what == "verify" then
			-- COMMON STUFF...
			-- chase down loops?
		end

		local event, result, r2, r3 = cons("editor_event")

		if event then
			result, r2, r3 = event(what, arg1, arg2, arg3)
		end

		return result, r2, r3
		-- ^^^ TODO: need to see what this requires in practice
	end
end

--- Getter.
-- @treturn {string,...} Unordered list of condition type names.
function M.GetTypes ()
	local types = {}

	for k in pairs(ConditionList) do
		types[#types + 1] = k
	end

	return types
end

-- Condition links
	-- Single
	-- Binary
	-- Multi (todo: glue DSL... keep? and if so, try LPEG?)
-- Condition nodes, base
-- Monitor

-- Install various types of actions.
ConditionList = require_ex.DoList("config.Conditions")

-- Export the module.
return M