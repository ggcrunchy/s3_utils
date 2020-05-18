--- Texel mixins.

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

-- Modules --
local includer = require("solar2d_utils.includer")

-- Exports --
local M = {}

--
--
--

--- DOCME
M.GET_ABOVE_TEXEL = includer.AddSnippet[[

	P_UV vec4 GetAboveTexel (sampler2D s, P_UV vec2 uv)
	{
		return texture2D(s, uv + vec2(0., CoronaTexelSize.y));
	}
]]

--- DOCME
M.GET_RIGHT_TEXEL = includer.AddSnippet[[
	P_UV vec4 GetRightTexel (sampler2D s, P_UV vec2 uv)
	{
		return texture2D(s, uv + vec2(CoronaTexelSize.x, 0.));
	}
]]

--- DOCME
M.LAPLACIAN = includer.AddSnippet[[

	P_UV float Laplacian (sampler2D s, P_UV vec2 uv, P_UV float a0, P_UV float thickness)
	{
		a0 *= 4.;
		a0 -= texture2D(s, uv + vec2(thickness * CoronaTexelSize.x, 0.)).a;
		a0 -= texture2D(s, uv - vec2(thickness * CoronaTexelSize.x, 0.)).a;
		a0 -= texture2D(s, uv + vec2(0., thickness * CoronaTexelSize.y)).a;
		a0 -= texture2D(s, uv - vec2(0., thickness * CoronaTexelSize.y)).a;

		return a0;
	}
]]

--- DOCME
M.NORMALIZED_CORNER = includer.AddSnippet[[

	P_UV vec2 NormalizedCorner (P_UV float v)
	{
		P_UV float y = step(.5, v);

		return vec2(step(.25, v - y * .5), y);
	}
]]

--- DOCME
M.SEAMLESS_COMBINE = includer.AddSnippet[[

	// swapped image and circular masks per http://paulbourke.net/geometry/tiling/
    P_UV vec4 PrepareSeamlessCombine (P_UV vec2 uv1)
    {
        P_UV vec2 t1 = uv1 - .5, uv2 = uv1 + .5; // defer the fract() that would introduce sampling discontinuities, e.g. with noise
        P_UV vec2 t2 = fract(uv2) - .5;
        P_UV vec2 dots = vec2(dot(t1, t1), dot(t2, t2));

        return vec4(uv2, 1. - 2. * sqrt(dots));
    }

    #define SEAMLESS_EVALUATE_COORDS(op, coords) op(coords.xy)
    #define SEAMLESS_COMBINE_RESULTS(res1, res2, coords) ((res1) * coords.z + (res2) * coords.w) / max(coords.z + coords.w, .0125)
    #define SEAMLESS_EVALUATE_AND_COMBINE(op, uv, coords) SEAMLESS_COMBINE_RESULTS(SEAMLESS_EVALUATE_COORDS(op, uv), SEAMLESS_EVALUATE_COORDS(op, coords), coords)
]]

--- DOCME
M.SET_TEXCOORD = includer.AddSnippet{
	vertex = [[

	#define SET_TEXCOORD(coord) v_TexCoord = coord
]]
}

--- DOCME
M.SOFT_MIN2 = includer.AddSnippet[[

	// https://math.stackexchange.com/a/601130, after some previous experiments with
	// http://iquilezles.org/www/articles/smin/smin.htm
	P_COLOR vec4 SoftMin (P_COLOR vec4 a, P_COLOR vec4 b, P_COLOR float k)
	{
		P_COLOR vec4 ea = exp(a * k), eb = exp(b * k);

		return (a * ea + b * eb) / (ea + eb);
	}
]]

--- DOCME
M.SOFT_MIN3 = includer.AddSnippet[[

	// https://math.stackexchange.com/a/601130, after some previous experiments with
	// http://iquilezles.org/www/articles/smin/smin.htm
	P_COLOR vec4 SoftMin (P_COLOR vec4 a, P_COLOR vec4 b, P_COLOR vec4 c, P_COLOR float k)
	{
		P_COLOR vec4 ea = exp(a * k), eb = exp(b * k), ec = exp(c * k);

		return (a * ea + b * eb + c * ec) / (ea + eb + ec);
	}
]]

--- DOCME
M.SOFT_MIN4 = includer.AddSnippet[[

	// https://math.stackexchange.com/a/601130, after some previous experiments with
	// http://iquilezles.org/www/articles/smin/smin.htm
	P_COLOR vec4 SoftMin (P_COLOR vec4 a, P_COLOR vec4 b, P_COLOR vec4 c, P_COLOR vec4 d, P_COLOR float k)
	{
		P_COLOR vec4 ea = exp(a * k), eb = exp(b * k), ec = exp(c * k), ed = exp(d * k);

		return (a * ea + b * eb + c * ec + d * ed) / (ea + eb + ec + ed);
	}
]]

--- DOCME
M.SOFT_MAX2 = includer.AddSnippet{
    requires = { M.SOFT_MIN2 },

	any = [[

    P_UV vec4 SoftMax (P_UV vec4 a, P_UV vec4 b, P_UV float k)
	{
		return -SoftMin(-a, -b, k);
	}
]]

}

--- DOCME
M.SOFT_MAX3 = includer.AddSnippet{
    requires = { M.SOFT_MIN3 },

	any = [[

	P_UV vec4 SoftMax (P_UV vec4 a, P_UV vec4 b, P_UV vec4 c, P_UV float k)
	{
		return -SoftMin(-a, -b, -c, k);
	}
]]

}

--- DOCME
M.SOFT_MAX4 = includer.AddSnippet{
    requires = { M.SOFT_MIN4 },

	any = [[


	P_UV vec4 SoftMax (P_UV vec4 a, P_UV vec4 b, P_UV vec4 c, P_UV vec4 d, P_UV float k)
	{
		return -SoftMin(-a, -b, -c, -d, k);
	}
]]

}

-- TODO: barycentric / FEM stuff

local Corners = { upper_left = 0, upper_right = .25, lower_left = .5, lower_right = .75 }

--- DOCME
function M.NormalizedCornerValue (what)
	return assert(Corners[what], "Invalid corner name")
end

--- DOCME


return M