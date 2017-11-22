--- This module allows simple custom DSLs and their instantiation through expressions.

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
local concat = table.concat
local huge = math.huge
local loadstring = loadstring
local next = next
local pairs = pairs
local remove = table.remove
local tonumber = tonumber
local type = type
local unpack = unpack

-- Exports --
local M = {}

--
--
--

local IdentifierPatt = "[_%a][_%w]*"

local function IsIdentifier (str)
	return str:find(IdentifierPatt)
end

local SymbolPatt = "[^_%w%s]+"

local function IsSymbolic (str)
	return str:find(SymbolPatt)
end

local function Check (name, pred)
	local i1, i2 = pred(name)

	return i1 == 1 and i2 == #name
end

local function ValidateName (grammar, name)
	assert(type(name) == "string", "Non-string name")
	assert(#name > 0, "Empty name")
	assert((name:find(",") or name:find("(", 1, true) or name:find(")", 1, true)) == nil, "Commas and parentheses are reserved")

	local is_valid = Check(name, IsIdentifier) or Check(name, IsSymbolic)

	assert(is_valid, "Names must either be identifiers or consist purely of non-space symbols")

	if grammar.constants then
		assert(not grammar.constants[name], "Name already belongs to a constant")
	end

	if grammar.funcs then
		assert(not grammar.funcs[name], "Name already belongs to a function")
	end

	if grammar.binary_ops then
		assert(not grammar.binary_ops[name], "Name already belongs to a binary op")
	end

	if grammar.unary_ops then
		assert(not grammar.unary_ops[name], "Name already belongs to a unary op")
	end
end

local function ValidateOperator (name, info)
	local op, prec = info.op, tonumber(info.prec)

	assert(type(op) == "function", "Non-function op")
	assert(prec and prec >= 0 and prec % 1 == 0, "Precedence must be a positive integer")

	return { op, prec }
end

local Int = "%d+"
local Float = "%d+%.?%d*[Ee]?[%+%-]?%d*"

local NumberPatts = {
	number = "[%+%-]?" .. Float,
	negative_number = "%-" .. Float,
	positive_number = "%+?" .. Float,
	integer = "[%+%-]?" .. Int,
	negative_integer = "%-" .. Int,
	positive_integer = "%+?" .. Int
}

local function AddOps (grammar, params, what)
	if params[what] then
		local ops = {}

		for name, info in pairs(params[what]) do
			ValidateName(grammar, name)

			ops[name] = ValidateOperator(name, info)
		end

		return ops
	end
end

--- Defines a grammar for later consumption by @{Process}.
-- @ptable params Grammar parameters:
--
--   * **binary\_ops**: Optional name-info list, with _info_ in the form `{ op = X, prec = Y }`,
--                  where `X` is a binary operator and `Y` is an integer &gt; 0&mdash that
--                  indicates its precedence. Operators (of any sort) with lower-valued
--                  precedence are chosen over higher-valued ones.
--
--                  The operator is called as `result = X(left, right, params)`, where the
--                  operands are meant to be invoked lazily within the body, say as
--                  `value1 = left(params)` and `value2 = right(params)`. Generally speaking,
--                  `params` is meant for any eventual variable resolution and should not be
--                  touched directly.
--   * **constants**: Optional name-value list, whose values will be used directly.
--   * **default**: Required. Value used when a step produces no result.
--   * **funcs**: Optional name-info list, with _info_ in the form `{ func = X, arity = N }` or
--            `{ func = X, identity = I }`, where `X` is either a function taking `N` arguments
--            or a function taking `I` plus a variable number of arguments, and in either
--            case returning a single value.
--   * **names**: Optional array of names. During processing, discovering a variable whose
--            name is absent from this list results in an error.
--   * **numbers**: If present, one of **"number"**, **"negative\_number"**, **"positive\_number"**,
--              **"integer"**, **"negative\_integer"**, or **"positive\_number"**, indicating
--              what sort of numeric constants to allow, with **"number"** being the most
--              general. (Infinities and NaNs are unsupported, as are hexademical et al.)
--   * **unary\_ops**: As per **binary\_ops**, but with unary functions called as
--                 `value = unary(oper, params)`.
--
-- Names must be strings and may either be identifers or symbolic, cf. @{Process}.
--
-- A name may appear in both **binary\_ops** and **unary\_ops**, but cannot appear in more
-- than one of **constants**, **funcs**, or said operator tables.
--
-- Functions and operator bodies are assumed to return values (never **nil**) compatible with
-- **default**, with the same being true of any values (including fold identities) passed to
-- functions. For instance, all could share a type.
-- @treturn Grammar Grammar definition.
function M.DefineGrammar (params)
	local grammar = { def = params.default }

	assert(grammar.def ~= nil, "Non-nil default return value required")

	if params.names then
		grammar.names = {}

		for i = 1, #params.names do
			grammar.names[params.names[i]] = true
		end
	end

	if params.numbers then
		grammar.numbers = assert(NumberPatts[params.numbers], "Invalid number kind")
	end

	if params.constants then
		local constants = {}

		for name, k in pairs(params.constants) do
			ValidateName(grammar, name)

			constants[name] = function()
				return k
			end
		end

		grammar.constants = constants
	end

	if params.funcs then
		local funcs = {}

		for name, info in pairs(params.funcs) do
			ValidateName(grammar, name)

			local func, arity, identity = info.func, tonumber(info.arity), info.identity

			assert(type(func) == "function", "Non-callable function")

			if identity ~= nil then
				assert(not arity, "Ambiguous: arity and identity both present")
			else
				assert(arity and arity >= 0 and arity % 1 == 0, "Arity must be a non-negative integer")
			end

			funcs[name] = { func, arity ~= nil and arity, identity } -- arity = false when identity is present
		end

		grammar.funcs = funcs
	end

	-- Add binary and unary ops to the grammar only once both are done, since otherwise names
	-- present in both lists would trigger errors...
	grammar.binary_ops, grammar.unary_ops = AddOps(grammar, params, "binary_ops"), AddOps(grammar, params, "unary_ops")

	-- ...now rig up any such binary-to-unary fallbacks. (We can traverse either list; doing
	-- both would be redunant, since only shared keys matter.)
	if grammar.binary_ops and grammar.unary_ops then
		local uops = grammar.unary_ops

		for k, info in pairs(grammar.binary_ops) do
			info[3] = uops[k] -- point to unary op if present
		end
	end

	return grammar
end

local function AreParensBalanced (expr)
	local depth = 0

	for paren in expr:gmatch("([%(%)])") do
		if paren == "(" then
			depth = depth + 1
		else
			depth = depth - 1
		end

		if depth < 0 then
			break
		end
	end

	return depth == 0 
end

local function EatSpace (expr, pos, n)
	return expr:find("%S", pos) or n + 1
end

local SearchList = {
	"number", false, -- n.b. pattern filled in (or not) ahead of time
	"identifier", IdentifierPatt,
	"symbol", SymbolPatt -- n.b. follows numbers to avoid ambiguities with symbols beginning with `+` and `-`
}

local EmitInfo = {
	"constants", "resolved",
	"funcs", "function",
	"binary_ops", "binary_op", -- n.b. do binary_ops first owing to fallback policy for shared names
	"unary_ops", "unary_op"
}

local function EmitNamedItem (grammar, item)
	for i = 1, #EmitInfo, 2 do
		local tname = EmitInfo[i]
		local t = grammar[tname]

		if t and t[item] then
			return EmitInfo[i + 1], t[item]
		end
	end
end

local Lookup

local function LookupVar (grammar, item, next_pos)
	if grammar.names and not grammar.names[item] then
		return nil, item .. "is not a valid name"
	end

	Lookup = Lookup or {}
	Lookup[item] = Lookup[item] or function(params)
		return params[item]
	end

	return next_pos, "resolved", Lookup[item]
end

local function GetNextToken (grammar, expr, pos)
	for i = 1, #SearchList, 2 do
		local ttype, patt = SearchList[i], SearchList[i + 1]

		if patt then
			local i1, i2 = expr:find(patt, pos)

			if i1 == pos then
				local item, next_pos = expr:sub(i1, i2), i2 + 1

				if ttype == "identifier" or ttype == "symbol" then
					local tname, resolved = EmitNamedItem(grammar, item)

					if tname then
						return next_pos, tname, resolved
					else
						return LookupVar(grammar, item, next_pos)
					end
				elseif ttype == "number" then
					local value = tonumber(item)

					return next_pos, "resolved", function()
						return value
					end
				end
			end
		end
	end

	return nil, "Unable to lex further: " .. expr:sub(pos)
end

local Lex

local function LexFunc (grammar, expr, pos, n, info)
	local func, arity, identity = info[1], info[2], info[3] -- if identity is present, arity = false

	if identity ~= nil or arity > 0 then
		local params, resolves, args, what = {}, {}, {} -- see error-related notes in Lex

		pos = EatSpace(expr, pos, n)

		if expr:sub(pos, pos) == "(" then
			pos = pos + 1
		elseif pos > n then
			return nil, "No more characters after function identifier"
		else
			return nil, "Expected '(' after function identifier"
		end

		local index, close_fold = 0

		if identity ~= nil then
			params[#params + 1] = "id"
			resolves[#resolves + 1] = "id"
			args[#args + 1] = identity

			function close_fold (term)
				if term == ")" then
					arity = index -- terminate loop
				end

				return term == "," or term == ")"
			end
		end

		while index ~= arity do
			index = index + 1
			pos, what = Lex(grammar, expr, pos, n, close_fold or (index < arity and "," or ")"))

			if not pos then
				return nil, what
			elseif not what then -- empty argument
				if not (close_fold and index == 1 and index == arity) then -- okay on closed fold, if first argument
					return nil, "Empty argument"
				end
			else
				params[#params + 1] = "p" .. index
				resolves[#resolves + 1] = "p" .. index .. "(params)"
				args[#args + 1] = what
			end
		end

		local code = [[
			local func, ]] .. concat(params, ", ") .. [[ = ...

			return function(params)
				return func(]] .. concat(resolves, ", ") .. [[)
			end
		]]

		return pos, "resolved", loadstring(code)(func, unpack(args))
	else
		return pos, "resolved", function()
			return func() -- n.b. suppress params in case function is not in fact nullary
		end
	end
end

local function Accumulate (a, b, what, item)
	if a == nil then -- empty -> pair
		a, b = what, item
	elseif b == nil then -- list
		a[#a + 1] = what
		a[#a + 1] = item
	else -- pair -> list
		a, b = { a, b, what, item }
	end

	return a, b
end

local function FindBestOperator (list)
	local best, index, alt_index = huge

	for i = 1, #list - 2, 2 do -- no operators in last spot
		local what = list[i]

-- TODO: where do ternary operators fit?
-- Idea: require three distinct (unused) operator fragments, emitting them as say "fragment", then
-- on finding the last one, check that list[pos - 4] and list[pos - 2] agree and error otherwise
-- ^^^ Not quite enough, e.g. if we have nesting, say "X ? Y ? A : B : Z"
-- Here would simply be matter of looking for "ternary_op" (and skipping say "ternary_part")?
-- Implications for UpdateList()?
-- Actually, > 3 operands possible, but expecting distinct fragments not very scalable
-- ^^^ On that note, probably only last one needs to be distinct from other "middle" ones
-- ^^^ Otherwise, we have to also do lookahead or backtrack to see that the operator ends?
-- ^^^ C-style ternary could be roughly: ternary_choice = { begin_op = "?", end_op = ":" }, with no middle_op
-- ^^^ To make other operators useful probably need a type system, e.g. to allow integer indices...
-- ^^^ ...or boolean wherever, to use said ternary choice more widely
-- ^^^ Example of that, something like: "choose INDEX alt A alt B or_alt C"
-- ^^^ Would of course un-complicate some other stuff, e.g. mixing numbers and vectors
-- ^^^ Becomes question of how well-typed variables can be, if multiple possibilities allowed

		if what == "binary_op" or what == "unary_op" then
			local info, trying_alt = list[i + 1]

			if what == "binary_op" and list[i - 2] ~= "resolved" then
				local alt_uop = info[3] -- unary op available instead?

				if alt_uop then -- TODO: can unary op's precedence lead to errors?
					info, trying_alt = alt_uop, true
				else
					return nil, "Binary operator expects value as left operand"
				end
			end

			local prec = info[2]

			if prec < best then
				best, index = prec, i

				if trying_alt then
					alt_index = index
				end
			end
		elseif what ~= "resolved" then
			return nil, "Something went wrong!"
		end
	end

	if list[index + 2] == "resolved" then
		if index == alt_index then -- if alternate should be used, overwrite entry
			list[index], list[index + 1] = "unary_op", list[index + 1][3]
		end

		return index
	else
		return nil, "Operator expects value as right operand"
	end
end

local function UpdateList (list, pos, func, n)
	local ri = pos + 2 -- an operator always has a right operand, so relocate there

	list[ri], list[ri + 1] = "resolved", func

	for i = 1, 2 * n do -- remove the earlier entries: the operator itself, plus any left operand
		remove(list, ri - i)
	end
end

local function Resolve (a, b, next_pos)
	if a == nil then -- empty
		return next_pos
	elseif b ~= nil then -- pair (b = value)
		return next_pos, b
	else -- list = { a1, b1, a2, b2, ... }
		repeat
			if a[#a - 1] ~= "resolved" then
				return nil, "Operator at end"
			end
			-- ^^^ TODO: is it enough to check this just once before the loop?

			local index, op = FindBestOperator(a) -- follows error policy of Lex et al.

			if index then
				op = a[index + 1][1]
			else
				return nil, op or "No operators remaining"
			end

			if a[index] == "binary_op" then
				local oper1, oper2 = a[index - 1], a[index + 3] -- ..., "resolved", oper1, "binary_op", op, "resolved", oper2, ...

				UpdateList(a, index, function(params)
					return op(oper1, oper2, params)
				end, 2)
			else
				local oper = a[index + 3] -- ..., "unary_op", op, "resolved, oper, ...

				UpdateList(a, index, function(params)
					return op(oper, params)
				end, 1)
			end
		until a[3] == nil -- consume down to one ("resolved", item) pair...

		return next_pos, a[2] -- ...and extract that item
	end
end

function Lex (grammar, expr, pos, n, term)
	pos = EatSpace(expr, pos, n)

	local ok, lexa, lexb = term == nil

	while pos <= n do
		local first = expr:sub(pos, pos)

		if first == "(" then
			local item -- if pos ~= nil, object or nothing; else error message

			pos, item = Lex(grammar, expr, pos + 1, n, ")")

			if pos then
				if item then
					lexa, lexb = Accumulate(lexa, lexb, "resolved", item)
				end
			else
				return nil, item
			end
		elseif first == term or (type(term) == "function" and term(first)) then -- term = function if lexing a fold argument
			pos, ok = EatSpace(expr, pos + 1, n), true

			break
		else
			local what, item -- see note above re. pos and what

			pos, what, item = GetNextToken(grammar, expr, pos)

			if not pos then
				return nil, what
			end

			if what == "function" then
				pos, what, item = LexFunc(grammar, expr, pos, n, item)

				if not pos then
					return nil, what
				end
			end

			lexa, lexb = Accumulate(lexa, lexb, what, item)
			pos = EatSpace(expr, pos, n)
		end
	end

	if ok then
		return Resolve(lexa, lexb, pos)
	else
		return nil, "Reached end of stream without finding '" .. term .. "'"
	end
end

local function BindArgs (vars, args, def)
	if args then
		for k in pairs(vars) do
			local v = args[k]

			if type(v) == "function" then
				v = v()
			end

			if v ~= nil then
				vars[k] = v
			else
				vars[k] = def
			end
		end
	else
		for k in pairs(vars) do
			vars[k] = def
		end
	end
end

local function ArgsMatchVars (args, vars)
	if args and vars then
		local ak = next(args, nil) -- walk args in parallel with vars to make sure sizes match

		for k in pairs(vars) do
			if ak == nil or args[k] == nil then -- no shortfall in arg keys, and key from vars present?
				return false
			end

			ak = next(args, ak)
		end

		return ak == nil -- no excess arg keys?
	end

	return args == vars -- both nil?
end

--- Given a grammar, convert an expression into callable form.
-- @tparam Grammar grammar_def The grammar underlying the expression, as returned by @{DefineGrammar}.
-- @string expr TODO! identifiers, symbols, parens, whitespace, constants, funcs, binary and unary operators)
-- @treturn[1] function Called as `result = func(args)` or `ok = func(args, "check_match")`,
-- with _args_ a table of variable name &rarr; value pairs.
--
-- The first version will run the expression function and return its result. Any variable
-- belonging to the expression whose name is found in _args_ will first be given the value
-- accompanying it, unless said value happens to be a function, in which case it is
-- called without arguments and the result used instead (unless **nil**); unassigned variables
-- are initialized to the grammar-provided default.
--
-- The **"check\_match"** version, meanwhile, compares _args_ and the expression's list of
-- variables, returning **true** when all their keys match, or if both are **nil**.
-- @return[2] **nil**, indicating an error.
-- @treturn[2] string Error message.
function M.Process (grammar_def, expr)
	if not AreParensBalanced(expr) then
		return nil, "Unbalanced parentheses"
	end

	SearchList[2] = grammar_def.numbers ~= nil and grammar_def.numbers -- q.v. GetNextToken()

	local ok, entry_point = Lex(grammar_def, expr, 1, #expr)
	local def, lookup = grammar_def.def, Lookup

	Lookup = nil

	if not ok then
		return nil, entry_point -- see Lex on errors
	elseif entry_point then
		local vars = lookup and {}

		if vars then
			for k in pairs(lookup) do
				vars[k] = def -- register the names
			end
		end

		return function(args, how)
			if how == "check_match" then
				return ArgsMatchVars(args, vars)
			elseif vars then
				BindArgs(vars, args, def)
			end

			return entry_point(vars)
		end
	else -- empty expression
		return function(args, how)
			if how == "check_match" then
				return args == nil
			else
				return def
			end
		end
	end
end

-- Export the module.
return M