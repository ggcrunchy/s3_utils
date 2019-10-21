--- Utilities for numbers that fall in the range [0, 1].

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
local abs = math.abs
local assert = assert
local floor = math.floor
local log = math.log
local rawget = rawget
local rawequal = rawequal
local setmetatable = setmetatable
local type = type

-- Modules --
local args = require("s3_utils.snippets.miscellany.args")
local includer = require("corona_utils.includer")
local qualifiers = require("s3_utils.snippets.utils.qualifiers")

-- Cached module references --
local _Decode_
local _Encode_

-- Exports --
local M = {}

--
--
--

local Decode = [[

		P_DEFAULT _VAR_TYPE_ axy = abs(xy);
]] ..

-- Select a 2^16-wide floating point range, comprising elements (1 + s / 65536) * 2^bin,
-- where significand s is an integer in [0, 65535]. The range's ulp will be 2^bin / 2^16,
-- i.e. 2^(bin - 16), and can be used to extract s.
[[
		P_DEFAULT _VAR_TYPE_ bin = floor(log2(axy));
]] ..

-- N.B. Floating point and real numbers are not the same thing; this is especially
-- important when working closely with the representation. Some care must be taken
-- regarding which of several "equivalent" formulae is chosen to find s, in order to
-- avoid corner cases that show up on certain architectures.
[[
		P_DEFAULT _VAR_TYPE_ num = exp2(16. - bin) * axy - 65536.;
]] ..

-- The lower 10 bits of the offset make up the y-value. The upper 6 bits, along with
-- the bin index, are used to compute the x-value. The bin index can exceed 15, so x
-- can assume the value 1024 without incident. It seems at first that y cannot, since
-- 10 bits fall just short. If the original input was signed, however, this is taken
-- to mean "y = 1024". Rather than conditionally setting it directly, though, 1023 is
-- found in the standard way and then incremented.
[[
		P_DEFAULT _VAR_TYPE_ rest = floor(num / 1024.);
		P_DEFAULT _VAR_TYPE_ y = num - rest * 1024.;
		P_DEFAULT _VAR_TYPE_ y_bias = step(0., -xy);
]]

local Error = [[

		#error "High fragment precision needed to decode number"
]]

local TenBitsPairCode, TenBitsPairParams = [[

	P_DEFAULT vec2 TenBitsPair (P_DEFAULT float xy)
	{
		]] .. Decode:gsub("_VAR_TYPE_", "float") .. [[

		return vec2(bin * 64. + rest, y + y_bias);
	}
]], {}

for _, branch in qualifiers.IterPrecision() do
	if branch ~= "fragment" then
		TenBitsPairParams[branch] = TenBitsPairCode
	else
		TenBitsPairParams[branch] = Error
	end
end

local TenBitsPairSnippet = includer.AddSnippet(TenBitsPairParams)
-- TODO: although we error anyway, still have P_DEFAULT in what could be fragment...

local TenBitsPair4Code, TenBitsPair4Params = [[

	void TenBitsPair4_OutH (P_DEFAULT vec4 xy, OUT_PARAM(P_DEFAULT) vec4 xo, OUT_PARAM(P_DEFAULT) vec4 yo)
	{
		]] .. Decode:gsub("_VAR_TYPE_", "vec4") .. [[

		xo = bin * 64. + rest;
		yo = y + y_bias;
	}

	void TenBitsPair4_OutM (P_DEFAULT vec4 xy, OUT_PARAM(P_UV) vec4 xo, OUT_PARAM(P_UV) vec4 yo)
	{
		P_DEFAULT vec4 xhp, yhp;

		TenBitsPair4_OutH(xy, xhp, yhp);

		xo = xhp;
		yo = yhp;
	}
]], { requires = { args.OUT } }

for _, branch in qualifiers.IterPrecision() do
	if branch ~= "fragment" then
		TenBitsPair4Params[branch] = TenBitsPair4Code
	else
		TenBitsPair4Params[branch] = Error
	end
end

local TenBitsPair4Snippet = includer.AddSnippet(TenBitsPair4Params)

--- DOCME
M.UNIT_PAIR = includer.AddSnippet{
	requires = { TenBitsPairSnippet },

	any = [[

	P_DEFAULT vec2 UnitPair (P_DEFAULT float xy)
	{
		return TenBitsPair(xy) / 1024.;
	}
]]

}

--- DOCME
M.UNIT_PAIR4 = includer.AddSnippet{
	requires = { TenBitsPair4Snippet },

	any = [[

	void UnitPair4_OutH (P_DEFAULT vec4 xy, OUT_PARAM(P_DEFAULT) vec4 xo, OUT_PARAM(P_DEFAULT) vec4 yo)
	{
		TenBitsPair4_OutH(xy, xo, yo);

		xo /= 1024.;
		yo /= 1024.;
	}

	void UnitPair4_OutM (P_DEFAULT vec4 xy, OUT_PARAM(P_UV) vec4 xo, OUT_PARAM(P_UV) vec4 yo)
	{
		P_DEFAULT vec4 xhp, yhp;

		UnitPair4_OutH(xy, xhp, yhp);

		xo = xhp;
		yo = yhp;
	}
]]

}

local Max -- maximum unsigned value

local function DecodeTenBitsPair (xy)
	local axy = abs(xy)

	assert(axy > 0 and axy <= Max, "Invalid code")

	-- Select the 2^16-wide floating point range. The first element in this range is 1 *
	-- 2^bin, while the ulp will be 2^bin / 2^16 or, equivalently, 2^(bin - 16). Then the
	-- index of axy is found by dividing its offset into the range by the ulp.
	local bin = floor(log(axy) / log(2))
	local num = (axy - 2^bin) * 2^(16 - bin)

	-- The lower 10 bits of the offset make up the y-value. The upper 6 bits, along with
	-- the bin index, are used to compute the x-value. The bin index can exceed 15, so x
	-- can assume the value 1024 without incident. It seems at first that y cannot, since
	-- 10 bits fall just short. If the original input was signed, however, this is taken
	-- to mean "y = 1024". Rather than conditionally setting it directly, though, 1023 is
	-- found in the standard way and then incremented.
	local rest = floor(num / 1024)
	local y = num - rest * 1024
	local y_bias = xy < 0 and 1 or 0

	return bin * 64 + rest, y + y_bias
end

--- Decodes a **highp**-range float, assumed to be encoded as per @{Encode}.
-- @number pair Encoded pair.
-- @treturn number Number #1...
-- @treturn number ...and #2.
function M.Decode (pair)
	local x, y = DecodeTenBitsPair(pair)

	return x / 1024, y / 1024
end

local function EncodeTenBitsPair (x, y)
	assert(x >= 0 and x <= 1024, "Invalid x")
	assert(y >= 0 and y <= 1024, "Invalid y")

	x, y = floor(x + .5), floor(y + .5)

	local signed = y == 1024

	if signed then
		y = 1023
	end

	local xhi = floor(x / 64)
	local xlo = x - xhi * 64
	local xy = (1 + (xlo * 1024 + y) * 2^-16) * 2^xhi

	return signed and -xy or xy
end

--- Encodes two numbers &isin; [0, 1] into a **highp**-range float for retrieval in GLSL.
-- @number x Number #1...
-- @number y ...and #2.
-- @treturn number Encoded pair.
function M.Encode (x, y)
	return EncodeTenBitsPair(x * 1024, y * 1024)
end

local CombinedProperties = {}

CombinedProperties.__index = CombinedProperties

--- DOCME
function CombinedProperties:AddPair (combined_name, prop1, prop2)
	assert(prop1 ~= prop2, "Properties must differ")
	assert(not self[prop1], "Property #1 already in use")
	assert(not self[prop2], "Property #2 already in use")

	local function func (t, k, v)
		local is_prop1 = rawequal(k, prop1)

		if is_prop1 or rawequal(k, prop2) then
			local u1, u2 = _Decode_(t[combined_name])

			if not v then
				return is_prop1 and u1 or u2
			else
				if is_prop1 then
					u1 = v
				else
					u2 = v
				end

				t[combined_name] = _Encode_(u1, u2)
			end
		end
	end

	self[prop1], self[prop2] = func, func
end

--- DOCME
function CombinedProperties:GetProperty (object, name)
	local func = rawget(self, name)

	if func then
		return func(object, name)
	else
		return object[name]
	end
end

--- DOCME
function CombinedProperties:SetProperty (object, name, value)
	assert(type(value) == "number", "Non-number value")

	local func = rawget(self, name)

	if func then
		return func(object, name, value)
	else
		object[name] = value
	end
end

--- DOCME
function CombinedProperties:WrapForTransitions (object)
	local wrapper = {
		__index = function(_, k)
			return self:GetProperty(object, k)
		end,

		__newindex = function(_, k, v)
			self:SetProperty(object, k, v)
		end
	}

	return setmetatable(wrapper, wrapper)
end

--- DOCME
function M.NewCombinedProperties ()
	return setmetatable({}, CombinedProperties)
end

Max = EncodeTenBitsPair(1024, 1023)

--- Prepares a unit pair-style parameter for addition to a kernel.
--
-- This parameter should be assigned values encoded as per @{Encode}.
-- @string name Friendly name of shader parameter.
-- @uint index Vertex userdata component index.
-- @number defx Default number #1, cf. @{Encode}...
-- @number defy ...and number #2.
-- @treturn table Vertex userdata component.
function M.VertexDatum (name, index, defx, defy)
	return { name = name, index = index, default = _Encode_(defx, defy), min = -Max, max = Max }
end

_Decode_ = M.Decode
_Encode_ = M.Encode

return M