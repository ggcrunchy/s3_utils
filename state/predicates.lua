--- Objects that represent predicates.

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
local expression = require("s3_utils.state.expression")

-- Exports --
local M = {}

-- Predicate type lookup table --
local PredicateList

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
function M.AddPredicate (info)
	local predicate

	--
	if info.expression then
		local logic = expression.Parse(info.expression)

		function predicate (comp, arg)
			if rawequal(arg, PredicateList) then
				logic(comp) -- TODO: check order guarantees...
			else
				return logic()
			end
		end

		bind.Subscribe("loading_level", info.conds, predicate, PredicateList)

	--
	elseif info.connective then
		local connective, pred1, pred2 = Connectives[info.connective]

		function predicate (comp, arg)
			if rawequal(arg, PredicateList) then
				if pred1 then -- TODO: check order guarantees
					pred2 = comp
				else
					pred1 = comp
				end
			else
				return connective(pred1(), pred2())
			end
		end

		bind.Subscribe("loading_level", info.cond1, predicate, PredicateList)
		bind.Subscribe("loading_level", info.cond2, predicate, PredicateList)

	--
	else
		predicate = assert(PredicateList[info.type], "Invalid predicate")(info)
	end

	bind.Publish("loading_level", predicate, info.uid, "test")

	return predicate
end

--- Handler for predicate-related events sent by the editor.
-- @string type Predicate type, as listed by @{GetTypes}.
-- @string what Name of event.
-- @param arg1 Argument #1.
-- @param arg2 Argument #2.
-- @param arg3 Argument #3.
-- @return Result(s) of the event, if any.
function M.EditorEvent (type, what, arg1, arg2, arg3)
	local cons = PredicateList[type]

	if cons then
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
			arg1.test = "Query this predicate"

		-- Get Tag --
		elseif what == "get_tag" then
			return "predicate"

		-- New Tag --
		elseif what == "new_tag" then
			return "properties", { boolean = "test" }

		-- Prep Link --
		elseif what == "prep_link" then
			-- ANYTHING?
		
		-- Verify --
		elseif what == "verify" then
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

--
local function LinkBinaryPredicate (predicate, other, sub, other_sub)
	if sub == "pred1" or sub == "pred2" then
		predicate[sub] = other.uid
	end
end

--- Handler for binary predicate-related events sent by the editor.
-- @string what Name of event.
-- @param arg1 Argument #1.
-- @param arg2 Argument #2.
-- @param arg3 Argument #3.
-- @return Result(s) of the event, if any.
function M.EditorEvent_Binary (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Action to build
	if what == "build" then
		-- could use this to filter out stuff not germane to type?
		-- or maybe to build the name -> ID maps?

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		-- link to predicate object (more likely, that should extend this)
		-- rest will be in extensions (Binary, Complex)

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:StockElements()
		arg1:AddSeparator()

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.test = "Query this predicate"
		arg1.pred1 = "Binary predicate's first reference"
		arg1.pred2 = "Binary predicate's second reference"

	-- Get Tag --
	elseif what == "get_tag" then
		return "binary_predicate"

	-- New Tag --
	elseif what == "new_tag" then
		return "properties", {
			boolean = "test"
		}, {
			boolean = { pred1 = true, pred2 = true }
		}

	-- Prep Link --
	elseif what == "prep_link" then
		return LinkBinaryPredicate
	
	-- Verify --
	elseif what == "verify" then
		-- Has both set?
	end
end

--
local function LinkComplexPredicate (predicate, other, sub, other_sub)
	if sub == "preds" then
		bind.AddId(predicate, "preds", other.uid, other_sub)
	end
end

--- Handler for complex predicate-related events sent by the editor.
-- @string what Name of event.
-- @param arg1 Argument #1.
-- @param arg2 Argument #2.
-- @param arg3 Argument #3.
-- @return Result(s) of the event, if any.
function M.EditorEvent_Complex (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Action to build
	if what == "build" then
		-- build the name -> ID maps?

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.expression = ""

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:StockElements()
		arg1:AddSeparator()

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.test = "Query this predicate"
		arg1.preds = "Subpredicates to query"

	-- Get Tag --
	elseif what == "get_tag" then
		return "complex_predicate"

	-- New Tag --
	elseif what == "new_tag" then
		return "properties", {
			boolean = "test"
		}, {
			-- preds/Multi
		}

	-- Prep Link --
	elseif what == "prep_link" then
		return LinkComplexPredicate
	
	-- Verify --
	elseif what == "verify" then
		-- Legal expression?
	end
end

--- Getter.
-- @treturn {string,...} Unordered list of predicate type names.
function M.GetTypes ()
	local types = {}

	for k in pairs(PredicateList) do
		types[#types + 1] = k
	end

	return types
end

-- Predicate links
	-- Single
	-- Binary
	-- Multi (todo: glue DSL... keep? and if so, try LPEG?)
-- Predicate nodes, base
-- Monitor

-- Install various types of actions.
PredicateList = require_ex.DoList("config.Predicates")

-- Export the module.
return M