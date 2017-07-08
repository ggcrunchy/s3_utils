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
local fx = require("s3_utils.fx")
local loader = require("corona_shader.loader")
local screen_fx = require("corona_shader.screen_fx")

-- Kernel --
local kernel = { language = "glsl", category = "filter", group = "screen", name = "shimmer" }

local vertex_data = fx.DistortionKernelParams()

vertex_data[4] = { name = "influence", index = 3, min = .5, max = 1024., default = 15. }

kernel.vertexData = vertex_data
kernel.vertex = screen_fx.GetPassThroughVertexKernelSource()

kernel.fragment = loader.FragmentShader[[
	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		P_UV vec2 uvn = 2. * uv - 1.;
		P_UV vec2 offset = IQ_Octaves(uv * 14.1, uv * 12.3) * GetDistortInfluence(uvn, .75, CoronaVertexUserData.w);
		P_COLOR vec3 background = GetDistortedRGB(CoronaSampler0, offset, CoronaVertexUserData);

		return CoronaColorScale(vec4(background, 1.));
	}
]]

graphics.defineEffect(kernel)