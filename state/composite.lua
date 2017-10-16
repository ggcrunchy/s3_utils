--- Objects that combine arbitrarily many getters of a given type.

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
local rawequal = rawequal

-- Modules --
local bind = require("tektite_core.bind")
local expression = require("s3_utils.state.expression")

-- Exports --
local M = {}

-- --
local AddComponent = {}

--- DOCME
function M.MakeAdder (ckey, grammar)
	return function(info, wname)
		local wlist = wname or "loading_level"
		local logic = expression.Parse(info.expression, grammar)

		local function getter (comp, arg)
			if rawequal(arg, AddComponent) then
				logic(comp) -- TODO: check order guarantees...
			else
				return logic()
			end
		end

		--
		bind.Subscribe(wlist, info[ckey], getter, AddComponent)

		--
		bind.Publish(wlist, getter, info.uid, "get")

		return getter
	end
end

--- DOCME
function M.MakeEditorEvent (type, ckey, event, grammar, tag)
	return function(what, arg1, arg2, arg3)
		-- Enumerate Defaults --
		-- arg1: Defaults
		if what == "enum_defs" then
			-- TODO: reduction ops as alternative to expression... (would suggest a section, then)
			arg1.expression = ""

		-- Enumerate Properties --
		-- arg1: Dialog
		elseif what == "enum_props" then
			arg1:StockElements()
			arg1:AddSeparator()
			-- TODO: need something, e.g. a list + button -> text field, to associate names

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.get = "Query final value"
			arg1[ckey] = "Source values"

		-- Get Tag --
		elseif what == "get_tag" then
			return tag

		-- New Tag --
		elseif what == "new_tag" then
			return "properties", {
				[type] = "get"
			}, {
				-- preds/Multi
			}

		-- Prep Link --
		elseif what == "prep_link" then
			return function(cvalue, other, sub, other_sub)
				if sub == ckey then
					bind.AddId(cvalue, ckey, other.uid, other_sub)
				end
			end
		
		-- Verify --
		elseif what == "verify" then
			-- Legal expression?
			-- All names registered?
			-- Use grammar
		end

		event(what, arg1, arg2, arg3)
	end
end

-- Export the module.
return M