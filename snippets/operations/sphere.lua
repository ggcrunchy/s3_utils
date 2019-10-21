--- Sphere mixins.

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
local includer = require("corona_utils.includer")
local pi = require("s3_utils.snippets.constants.pi")

-- Exports --
local M = {}

--
--
--

local RequiresPi = { pi.PI }

--- DOCME
M.GET_UV_FROM_DIFF = includer.AddSnippet{
    requires = RequiresPi,

    any = [[

	P_POSITION vec2 GetUV (P_POSITION vec2 diff)
	{
        P_POSITION float dist_sq = dot(diff, diff);

    #ifndef SPHERE_NO_DISCARD
        if (dist_sq > 1.) return vec2(-1.);
    #endif

        P_POSITION float z = sqrt(1. - dist_sq);

		return vec2(.5 + atan(z, diff.x) * ONE_OVER_TWO_PI, .5 + asin(diff.y) * ONE_OVER_PI);
	}
]]

}

--- DOCME
M.GET_UV_FROM_DIR = includer.AddSnippet{
    requires = RequiresPi,

    any = [[

	P_POSITION vec2 GetUV (P_POSITION vec3 dir)
	{
		return vec2(.5 + atan(dir.z, dir.x) * ONE_OVER_TWO_PI, .5 + asin(dir.y) * ONE_OVER_PI);
	}
]]

}

--- DOCME
M.GET_UV_Z_PHI = includer.AddSnippet{
    requires = RequiresPi,

    any = [[

	P_POSITION vec4 GetUV_ZPhi (P_POSITION vec2 diff)
	{
        P_POSITION float dist_sq = dot(diff, diff);

    #ifndef SPHERE_NO_DISCARD
        if (dist_sq > 1.) return vec4(-1.);
    #endif

        P_POSITION float z = sqrt(1. - dist_sq), phi = atan(z, diff.x);

		return vec4(.5 + phi * ONE_OVER_TWO_PI, .5 + asin(diff.y) * ONE_OVER_PI, z, phi);
	}
]]

}

local PhiToU = [[
    P_POSITION float u = .5 + phi * ONE_OVER_TWO_PI;

    #ifdef SPHERE_PINGPONG_ANGLE
        u = mod(u + dphi, 2.);
        u = mix(u, 2. - u, step(1., u));
    #else
        u = fract(u + dphi);
    #endif
]]

--- DOCME
M.GET_UV_PHI_DELTA = includer.AddSnippet{
    requires = RequiresPi,

    any = [[

	P_POSITION vec2 GetUV_PhiDelta (P_POSITION vec2 diff, P_POSITION float dphi)
	{
        P_POSITION float dist_sq = dot(diff, diff);

    #ifndef SPHERE_NO_DISCARD
        if (dist_sq > 1.) return vec2(-1.);
    #endif

        P_POSITION float z = sqrt(1. - dist_sq), phi = atan(z, diff.x);
        ]] .. PhiToU .. [[

        P_POSITION vec2 uv = vec2(u, .5 + asin(diff.y) * ONE_OVER_PI);

	#ifdef SPHERE_REPAIR_SEAM_POWER
		uv.x = mix(uv.y * uv.y, uv.x, pow(4. * uv.x * (uv.x - 1.), SPHERE_REPAIR_SEAM_POWER));
	#endif

		return uv;
	}
]]

}

--- DOCME
M.GET_UV_PHI_DELTA_Z_PHI = includer.AddSnippet{
    requires = RequiresPi,

    any = [[

	P_POSITION vec4 GetUV_PhiDelta_ZPhi (P_POSITION vec2 diff, P_POSITION float dphi)
	{
        P_POSITION float dist_sq = dot(diff, diff);

    #ifndef SPHERE_NO_DISCARD
        if (dist_sq > 1.) return vec4(-1.);
    #endif

        P_POSITION float z = sqrt(1. - dist_sq), phi = atan(z, diff.x);
		]] .. PhiToU .. [[

		return vec4(u, .5 + asin(diff.y) * ONE_OVER_PI, z, phi);
	}
]]

}

--- DOCME
M.GET_TANGENT = includer.AddSnippet{
    requires = RequiresPi,

    any = [[

	P_POSITION vec3 GetTangent (P_POSITION vec2 diff, P_POSITION float phi)
	{
		// In unit sphere, diff.y = sin(theta), sqrt(1 - sin(theta)^2) = cos(theta).
		return normalize(vec3(diff.yy * sin(vec2(phi + PI_OVER_TWO, -phi)), sqrt(1. - diff.y * diff.y)));
	}
]]

}

return M