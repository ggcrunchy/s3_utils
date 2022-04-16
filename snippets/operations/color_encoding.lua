--- Utilities for numbers encoded in color data, cf. [Encoding floats to RGBA - the Final?](http://aras-p.info/blog/2009/07/30/encoding-floats-to-rgba-the-final/).

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

-- Modules --
local includer = require("solar2d_utils.includer")
local qualifiers = require("s3_utils.snippets.utils.qualifiers")

-- Globals --
local system = system

-- Exports --
local M = {}

--
--
--

local Precision = qualifiers.DefaultPrecisionOr("P_POSITION")

-- TODO: can also use "has vertex textures", when available

local HasSinglePrecisionFloats = false -- TODO: what is appropriate check? not GLES2 ?

if HasSinglePrecisionFloats then -- are the larger numbers representable? (TODO: in highp our integer range ends at 2^16 but floats at 2^62, so we get an approximation...)
	--- DOCME
	M.DECODE_FLOAT_RGBA = includer.AddSnippet(([[

	_PRECISION_ float DecodeFloatRGBA (_PRECISION_ vec4 rgba)
	{
		return dot(rgba, vec4(1., 1. / 255., 1. / 65025., 1. / 16581375.)); // powers of 255, 0-3
	}

]]):gsub("_PRECISION_", Precision))

	--- DOCME
	M.ENCODE_FLOAT_RGBA = includer.AddSnippet(([[

	_PRECISION_ vec4 EncodeFloatRGBA (_PRECISION_ float v)
	{
		_PRECISION_ vec4 enc = vec4(1., 255., 65025., 16581375.) * v; // powers of 255, 0-3

		enc = fract(enc);

		return enc - enc.yzww * vec4(1. / 255., 1. / 255., 1. / 255., 0.);
	}

]]):gsub("_PRECISION_", Precision))

else -- lossy alternative
	M.DECODE_FLOAT_RGBA = includer.AddSnippet(([[

	_PRECISION_ float DecodeFloatRGBA (_PRECISION_ vec4 rgba)
	{
		return dot(rgba.xy, vec4(1., 1. / 255.));
	}

]]):gsub("_PRECISION_", Precision))

	M.ENCODE_FLOAT_RGBA = includer.AddSnippet(([[

	_PRECISION_ vec4 EncodeFloatRGBA (_PRECISION_ float v)
	{
		_PRECISION_ vec2 enc = vec4(1., 255.) * v;

		enc = fract(enc);

		return enc - enc.yy * vec4(1. / 255., 0.);
	}

]]):gsub("_PRECISION_", Precision))

end

--- DOCME
M.DECODE_TWO_FLOATS_RGBA = includer.AddSnippet(([[

	_PRECISION_ vec2 DecodeTwoFloatsRGBA (_PRECISION_ vec4 rgba)
	{
		return vec2(dot(rgba.xy, vec2(1., 1. / 255.)), dot(rgba.zw, vec2(1., 1. / 255.)));
	}
]]):gsub("_PRECISION_", Precision))


--- DOCME
M.ENCODE_TWO_FLOATS_RGBA = includer.AddSnippet(([[

	_PRECISION_ vec4 EncodeTwoFloatsRGBA (_PRECISION_ vec2 v)
	{
		_PRECISION_ vec4 enc = vec4(1., 255., 1., 255.) * v.xxyy;

		enc = fract(enc);

		return enc - enc.yyww * vec4(1. / 255., 0., 1. / 255., 0.);
	}
]]):gsub("_PRECISION_", Precision))

-- TODO: add Lua-side stuff
	-- color assigner, should clamp to [0, 1), e.g. for "info" pixels or memory bitmaps
	-- 1- could be 1 - 2^-16 or 1 - 2^-32
	-- then follow lead of encode functions
	-- this is in something... proof of concept for meshes, probably

return M