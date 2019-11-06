--- A shader used to render a shimmering object.

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
local distort = require("s3_utils.snippets.operations.distort")
local includer = require("corona_utils.includer")
local iq = require("s3_utils.snippets.noise.iq")

--
--
--

local kernel = { language = "glsl", category = "filter", group = "screen", name = "shimmer" }

kernel.vertexData = {
	{ name = "influence", index = 0, min = .5, max = 1024., default = 15. },
	{ name = "alpha", index = 1, default = 1, min = 0, max = 1 }
}

includer.Augment({
	requires = { distort.GET_DISTORT_INFLUENCE, distort.GET_DISTORTED_RGB, iq.OCTAVES },

	vertex = [[

	P_POSITION vec2 VertexKernel (P_POSITION vec2 pos)
	{
		InitDistortion(pos);

		return pos;
	}
]],

	fragment = [[

	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		P_UV vec2 uvn = 2. * uv - 1.;
		P_UV vec2 offset = IQ_Octaves(uv * 14.1, uv * 12.3) * GetDistortInfluence(uvn, .75, CoronaVertexUserData.x);
		P_COLOR vec3 background = GetDistortedRGB(CoronaSampler0, offset) * CoronaVertexUserData.y;

		return CoronaColorScale(vec4(background, 1.));
	}
]]

}, kernel)

graphics.defineEffect(kernel)

return "filter.screen.shimmer"